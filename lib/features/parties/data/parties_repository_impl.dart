import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/http_service.dart';
import '../../../core/utils/json_utils.dart';
import '../../films/data/film_dto.dart';
import '../domain/parties_repository.dart';
import '../domain/party_guest.dart';
import '../domain/quick_messages.dart';
import '../domain/watch_party.dart';

/// Wire shape of the quick-messages response.
class QuickMessagesDto {
  const QuickMessagesDto({required this.messages, required this.reactions});

  factory QuickMessagesDto.fromJson(Map<String, dynamic> json) =>
      QuickMessagesDto(
        messages: _strings(json['messages']),
        reactions: _strings(json['reactions']),
      );

  final List<String> messages;
  final List<String> reactions;

  QuickMessages toEntity() =>
      QuickMessages(messages: messages, reactions: reactions);

  static List<String> _strings(dynamic raw) =>
      raw is List ? raw.map((e) => e.toString()).toList() : const [];
}

/// Wire shape of a watch-party lobby / invite response or `lobbyUpdated` payload.
class WatchPartyDto {
  const WatchPartyDto(this._json);

  factory WatchPartyDto.fromJson(Map<String, dynamic> json) =>
      WatchPartyDto(json);

  final Map<String, dynamic> _json;

  WatchParty toEntity({int fallbackTotalPasses = 2}) {
    final maxGuests = JsonUtils.numberOrNull(_json, ['maxGuests'])?.toInt();
    final totalPasses = maxGuests != null
        ? ((maxGuests == 1 || maxGuests == 3) ? maxGuests + 1 : maxGuests)
        : fallbackTotalPasses;

    final rawGuests = _json['guests'];
    final guests = rawGuests is List
        ? rawGuests.whereType<Map>().map((g) {
            final map = Map<String, dynamic>.from(g);
            return PartyGuest(
              name: JsonUtils.string(map, ['name'], fallback: 'Guest'),
              email: JsonUtils.string(map, ['email']),
              status: PartyGuestStatus.fromApi(
                JsonUtils.stringOrNull(map, ['status']),
              ),
              invitedAt:
                  JsonUtils.dateTime(map, ['invitedAt']) ?? DateTime.now(),
              joinedAt: JsonUtils.dateTime(map, ['joinedAt']),
            );
          }).toList()
        : const <PartyGuest>[];

    final rawFilm = _json['film'];
    final film = rawFilm is Map
        ? FilmDto.fromJson(Map<String, dynamic>.from(rawFilm)).toEntity()
        : null;

    return WatchParty(
      partyId: JsonUtils.string(_json, ['partyId', '_id', 'id']),
      hostName: JsonUtils.string(
        _json,
        ['hostName', 'guestName'],
        fallback: 'Host',
      ),
      filmId: JsonUtils.string(_json, ['filmId'], fallback: film?.id ?? ''),
      status: JsonUtils.string(_json, ['status'], fallback: 'waiting'),
      isHost: _json['isHost'] is bool ? _json['isHost'] as bool : true,
      hostOnline:
          _json['hostOnline'] is bool ? _json['hostOnline'] as bool : true,
      totalPasses: totalPasses,
      remainingSlots: JsonUtils.numberOrNull(_json, ['remainingSlots'])?.toInt(),
      guests: guests,
      socketToken: JsonUtils.stringOrNull(_json, ['socketToken']),
      accessToken: JsonUtils.stringOrNull(_json, ['accessToken']),
      film: film,
    );
  }
}

/// HTTP + Socket.IO (v4 / Engine.IO v4) implementation of [PartiesRepository].
class PartiesRepositoryImpl implements PartiesRepository {
  PartiesRepositoryImpl(this._http);
  final HttpService _http;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSub;
  Future<void>? _connectingFuture;
  String? _activePartyId;
  String? _activeSocketToken;
  bool _isConnectedToNamespace = false;
  final List<String> _pendingSocketFrames = [];

  final StreamController<String> _quickMessageController =
      StreamController<String>.broadcast();
  final StreamController<String> _reactionController =
      StreamController<String>.broadcast();
  final StreamController<WatchParty> _lobbyUpdateController =
      StreamController<WatchParty>.broadcast();
  final StreamController<PartyStartedEvent> _partyStartedController =
      StreamController<PartyStartedEvent>.broadcast();
  final StreamController<PartyPlaybackSync> _playbackSyncController =
      StreamController<PartyPlaybackSync>.broadcast();

  /// Tracks the last known host pause state so `syncTimestamp` heartbeats
  /// preserve whether the host is currently paused or playing.
  bool _lastKnownHostPaused = false;

  @override
  Stream<String> get incomingQuickMessages => _quickMessageController.stream;

  @override
  Stream<String> get incomingReactions => _reactionController.stream;

  @override
  Stream<WatchParty> get lobbyUpdates => _lobbyUpdateController.stream;

  @override
  Stream<PartyStartedEvent> get partyStartedEvents =>
      _partyStartedController.stream;

  @override
  Stream<PartyPlaybackSync> get playbackSyncEvents =>
      _playbackSyncController.stream;

  @override
  Future<QuickMessages> getQuickMessages() async {
    final raw = await _http.get('/parties/quick-messages');
    return QuickMessagesDto.fromJson(JsonUtils.asMap(raw)).toEntity();
  }

  @override
  Future<PartyPlaybackSync> getPartySyncState(String partyId) async {
    final raw =
        await _http.get('/parties/${Uri.encodeComponent(partyId)}/sync');
    final map = JsonUtils.asMap(raw);
    final time = JsonUtils.decimal(
      map,
      ['timestamp', 'currentTime', 'elapsedTime', 'position', 'time'],
      fallback: -1,
    );
    final hasExplicitPause =
        map.containsKey('isPaused') ||
        map.containsKey('paused') ||
        map.containsKey('playing') ||
        map.containsKey('action') ||
        map.containsKey('status');
    final isPaused = hasExplicitPause
        ? (map['isPaused'] is bool
            ? map['isPaused'] as bool
            : (map['paused'] is bool
                ? map['paused'] as bool
                : (map['playing'] is bool
                    ? !(map['playing'] as bool)
                    : (map['action'] == 'pause' || map['status'] == 'paused'))))
        : _lastKnownHostPaused;
    return PartyPlaybackSync(
      currentTimeSeconds: time,
      isPaused: isPaused,
      action: isPaused ? 'pause' : 'sync',
      receivedAt: DateTime.now(),
    );
  }

  @override
  Future<double> getSyncTimestamp(String partyId) async {
    final sync = await getPartySyncState(partyId);
    return sync.currentTimeSeconds >= 0 ? sync.currentTimeSeconds : 0;
  }

  @override
  Future<WatchParty> sendInvites({
    required String ticketId,
    required List<({String name, String email})> guests,
  }) async {
    final raw = await _http.post(
      '/parties/invites',
      body: {
        'ticketId': ticketId,
        'guests': guests
            .map(
              (g) => {
                'name': g.name.trim(),
                'email': g.email.trim().toLowerCase(),
              },
            )
            .toList(),
      },
    );
    return WatchPartyDto.fromJson(JsonUtils.asMap(raw)).toEntity();
  }

  @override
  Future<WatchParty?> removeInvite({
    required String partyId,
    required String email,
  }) async {
    final raw = await _http.delete(
      '/parties/${Uri.encodeComponent(partyId)}/invites',
      body: {'email': email.trim().toLowerCase()},
    );
    if (raw is Map && (raw.containsKey('guests') || raw.containsKey('partyId'))) {
      return WatchPartyDto.fromJson(JsonUtils.asMap(raw)).toEntity();
    }
    return null;
  }

  @override
  Future<void> resendInvite({
    required String partyId,
    required String email,
  }) async {
    await _http.post(
      '/parties/${Uri.encodeComponent(partyId)}/invites/resend',
      body: {'email': email.trim().toLowerCase()},
    );
  }

  @override
  Future<WatchParty> joinLobby({required String inviteToken}) async {
    final raw = await _http.post(
      '/parties/join-lobby',
      body: {'inviteToken': inviteToken.trim()},
    );
    final map = JsonUtils.asMap(raw);
    final party = WatchPartyDto.fromJson(map).toEntity().copyWith(isHost: false);
    if (party.accessToken != null && party.accessToken!.isNotEmpty) {
      _http.setBearerToken(party.accessToken);
    }
    return party;
  }

  @override
  Future<WatchParty> getLobby({String? ticketId, String? partyId}) async {
    final raw = await _http.get(
      '/parties/lobby',
      query: {
        if (ticketId != null && ticketId.trim().isNotEmpty)
          'ticketId': ticketId.trim(),
        if (partyId != null && partyId.trim().isNotEmpty)
          'partyId': partyId.trim(),
      },
    );
    return WatchPartyDto.fromJson(JsonUtils.asMap(raw)).toEntity();
  }

  @override
  Future<void> connectWatchParty({
    required String partyId,
    required String socketToken,
  }) async {
    final cleanPartyId = partyId.trim();
    final cleanToken = socketToken.trim();
    if (cleanPartyId.isEmpty || cleanToken.isEmpty) return;

    if (_socket != null &&
        _socket!.readyState == WebSocket.open &&
        _isConnectedToNamespace &&
        _activePartyId == cleanPartyId &&
        _activeSocketToken == cleanToken) {
      // Re-assert room membership in case a server-side state transition occurred
      _emitEvent('joinParty', {'partyId': cleanPartyId});
      return;
    }

    if (_connectingFuture != null &&
        _activePartyId == cleanPartyId &&
        _activeSocketToken == cleanToken) {
      return _connectingFuture!;
    }

    disconnectWatchParty();
    _activePartyId = cleanPartyId;
    _activeSocketToken = cleanToken;

    final future = _openSocketConnection(cleanPartyId);
    _connectingFuture = future;
    try {
      await future;
    } finally {
      if (_connectingFuture == future) {
        _connectingFuture = null;
      }
    }
  }

  Future<void> _openSocketConnection(String cleanPartyId) async {
    final wsUrl = _buildSocketIoWsUrl(AppConstants.socketBaseUrl);
    try {
      debugPrint('[WatchPartySocket] Connecting to $wsUrl (partyId: $cleanPartyId)');
      final ws = await WebSocket.connect(wsUrl);
      _socket = ws;
      _socketSub = ws.listen(
        _onSocketFrame,
        onError: (Object err) {
          debugPrint('[WatchPartySocket] WebSocket error: $err');
        },
        onDone: () {
          debugPrint('[WatchPartySocket] WebSocket closed');
          _isConnectedToNamespace = false;
        },
      );
    } catch (e) {
      debugPrint('[WatchPartySocket] Failed to connect: $e');
    }
  }

  String _buildSocketIoWsUrl(String baseUrl) {
    final uri = Uri.parse(baseUrl.trim());
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return uri
        .replace(
          scheme: scheme,
          path: '/socket.io/',
          queryParameters: const {
            'EIO': '4',
            'transport': 'websocket',
          },
        )
        .toString();
  }

  void _onSocketFrame(dynamic rawFrame) {
    if (rawFrame is! String || rawFrame.isEmpty) return;

    // Engine.IO v4 packet type is the first char:
    // '0' = OPEN, '2' = PING, '3' = PONG, '4' = MESSAGE (Socket.IO)
    final eioType = rawFrame[0];

    if (eioType == '0') {
      // Engine.IO OPEN received -> Send Socket.IO CONNECT ('40') with auth token
      final token = _activeSocketToken;
      if (token != null) {
        final authPayload = jsonEncode({'token': token});
        _sendRaw('40$authPayload');
      }
      return;
    }

    if (eioType == '2') {
      // Engine.IO PING -> Reply immediately with Engine.IO PONG ('3')
      _sendRaw('3');
      return;
    }

    if (eioType == '4' && rawFrame.length >= 2) {
      final sioType = rawFrame[1];
      if (sioType == '0') {
        // Socket.IO CONNECT ACK ('40{"sid":"..."}') -> Join the watch party room
        _isConnectedToNamespace = true;
        final partyId = _activePartyId;
        if (partyId != null && partyId.isNotEmpty) {
          _emitEvent('joinParty', {'partyId': partyId});
          debugPrint('[WatchPartySocket] Joined party room: $partyId');
        }
        if (_pendingSocketFrames.isNotEmpty) {
          final queued = List<String>.from(_pendingSocketFrames);
          _pendingSocketFrames.clear();
          for (final frame in queued) {
            _sendRaw(frame);
          }
        }
        return;
      }

      if (sioType == '2') {
        // Socket.IO EVENT ('42["eventName", payload]')
        final jsonPart = rawFrame.substring(2);
        try {
          final decoded = jsonDecode(jsonPart);
          if (decoded is List && decoded.isNotEmpty) {
            final eventName = decoded[0]?.toString() ?? '';
            final payload = decoded.length > 1 ? decoded[1] : null;
            _handleSocketEvent(eventName, payload);
          }
        } catch (e) {
          debugPrint('[WatchPartySocket] Failed to parse event frame: $e');
        }
      }
    }
  }

  void _handleSocketEvent(String event, dynamic payload) {
    debugPrint('[WatchPartySocket] Event "$event": $payload');
    if (event == 'receiveQuickMessage') {
      final text = _extractString(
        payload,
        const ['text', 'message', 'content', 'msg', 'quickMessage'],
      );
      if (text != null && text.isNotEmpty) {
        _quickMessageController.add(text);
      }
    } else if (event == 'receiveReaction') {
      final emoji = _extractString(
        payload,
        const ['emoji', 'reaction', 'icon', 'content'],
      );
      if (emoji != null && emoji.isNotEmpty) {
        _reactionController.add(emoji);
      }
    } else if (event == 'lobbyUpdated' && payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      _lobbyUpdateController.add(WatchPartyDto.fromJson(map).toEntity());
    } else if (event == 'partyStarted' && payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      final elapsed = JsonUtils.decimal(
        map,
        ['elapsedTime', 'timestamp', 'currentTime'],
      );
      _lastKnownHostPaused = false;
      _partyStartedController.add(
        PartyStartedEvent(
          partyId: JsonUtils.string(map, ['partyId']),
          filmId: JsonUtils.string(map, ['filmId']),
          elapsedSeconds: elapsed.round(),
        ),
      );
    } else if (event == 'syncVideo') {
      // Server broadcast from host's `videoAction` ({ action: 'pause' | 'play' | 'seek', timestamp })
      final map = payload is Map
          ? Map<String, dynamic>.from(payload)
          : <String, dynamic>{};
      final action = JsonUtils.string(map, ['action'], fallback: 'sync')
          .toLowerCase();
      final ts = JsonUtils.decimal(
        map,
        ['timestamp', 'currentTime', 'elapsedTime'],
        fallback: -1,
      );
      if (action == 'pause' || action == 'paused') {
        _lastKnownHostPaused = true;
      } else if (action == 'play' || action == 'resume' || action == 'playing') {
        _lastKnownHostPaused = false;
      }
      _playbackSyncController.add(
        PartyPlaybackSync(
          currentTimeSeconds: ts,
          isPaused: _lastKnownHostPaused,
          action: action,
          receivedAt: DateTime.now(),
        ),
      );
    } else if (event == 'syncTimestamp') {
      // Server broadcast from host's `timeUpdate` ({ timestamp }) or on `joinParty`
      final ts = payload is num
          ? payload.toDouble()
          : (payload is Map
              ? JsonUtils.decimal(
                  Map<String, dynamic>.from(payload),
                  ['timestamp', 'currentTime', 'elapsedTime'],
                  fallback: -1,
                )
              : (double.tryParse(payload?.toString() ?? '') ?? -1));
      if (ts > 0) {
        _playbackSyncController.add(
          PartyPlaybackSync(
            currentTimeSeconds: ts,
            isPaused: _lastKnownHostPaused,
            action: 'sync',
            receivedAt: DateTime.now(),
          ),
        );
      }
    } else if (event == 'partyEnded' || event == 'hostDisconnected') {
      _lastKnownHostPaused = true;
      _playbackSyncController.add(
        PartyPlaybackSync(
          currentTimeSeconds: -1,
          isPaused: true,
          action: event,
          isEnded: event == 'partyEnded',
          receivedAt: DateTime.now(),
        ),
      );
    }
  }

  String? _extractString(dynamic payload, List<String> keys) {
    if (payload is String) return payload.trim();
    if (payload is List && payload.isNotEmpty) {
      return _extractString(payload.first, keys);
    }
    if (payload is Map) {
      for (final k in keys) {
        final v = payload[k];
        if (v is String && v.trim().isNotEmpty) {
          return v.trim();
        }
      }
      final nested = payload['data'] ?? payload['payload'];
      if (nested is Map || nested is String) {
        final inner = _extractString(nested, keys);
        if (inner != null) return inner;
      }
    }
    return null;
  }

  @override
  void sendQuickMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _emitEvent('sendQuickMessage', {'text': trimmed});
  }

  @override
  void sendReaction(String emoji) {
    final trimmed = emoji.trim();
    if (trimmed.isEmpty) return;
    _emitEvent('sendReaction', {'emoji': trimmed});
  }

  @override
  void emitHostPlaybackState({
    required double currentTimeSeconds,
    required bool isPaused,
    String action = 'sync',
  }) {
    // Backend `videoAction` and `timeUpdate` require `timestamp > 0` (positive finite number).
    final safeTimestamp = currentTimeSeconds <= 0.05 ? 0.1 : currentTimeSeconds;
    _lastKnownHostPaused = isPaused;

    if (action == 'pause') {
      _emitEvent('videoAction', {
        'action': 'pause',
        'timestamp': safeTimestamp,
      });
    } else if (action == 'play' || action == 'resume') {
      _emitEvent('videoAction', {
        'action': 'play',
        'timestamp': safeTimestamp,
      });
    } else if (action == 'seek') {
      _emitEvent('videoAction', {
        'action': 'seek',
        'timestamp': safeTimestamp,
      });
      _emitEvent('timeUpdate', {
        'timestamp': safeTimestamp,
      });
    } else {
      // Periodic heartbeat while playing
      if (!isPaused) {
        _emitEvent('timeUpdate', {
          'timestamp': safeTimestamp,
        });
      }
    }
  }

  void _emitEvent(String eventName, Map<String, dynamic> data) {
    final frame = '42${jsonEncode([eventName.trim(), data])}';
    if (_socket == null ||
        _socket!.readyState != WebSocket.open ||
        !_isConnectedToNamespace) {
      if (_pendingSocketFrames.length < 25) {
        _pendingSocketFrames.add(frame);
      }
      return;
    }
    _sendRaw(frame);
  }

  void _sendRaw(String frame) {
    try {
      _socket?.add(frame);
    } catch (e) {
      debugPrint('[WatchPartySocket] Error sending frame: $e');
    }
  }

  @override
  void disconnectWatchParty() {
    _isConnectedToNamespace = false;
    _connectingFuture = null;
    _pendingSocketFrames.clear();
    _activePartyId = null;
    _activeSocketToken = null;
    _socketSub?.cancel();
    _socketSub = null;
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
  }
}
