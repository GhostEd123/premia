import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/http_service.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/parties_repository.dart';
import '../domain/quick_messages.dart';

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

/// HTTP + Socket.IO (v4 / Engine.IO v4) implementation of [PartiesRepository].
class PartiesRepositoryImpl implements PartiesRepository {
  PartiesRepositoryImpl(this._http);
  final HttpService _http;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSub;
  String? _activePartyId;
  String? _activeSocketToken;
  bool _isConnectedToNamespace = false;

  final StreamController<String> _quickMessageController =
      StreamController<String>.broadcast();
  final StreamController<String> _reactionController =
      StreamController<String>.broadcast();

  @override
  Stream<String> get incomingQuickMessages => _quickMessageController.stream;

  @override
  Stream<String> get incomingReactions => _reactionController.stream;

  @override
  Future<QuickMessages> getQuickMessages() async {
    final raw = await _http.get('/parties/quick-messages');
    return QuickMessagesDto.fromJson(JsonUtils.asMap(raw)).toEntity();
  }

  @override
  Future<double> getSyncTimestamp(String partyId) async {
    final raw =
        await _http.get('/parties/${Uri.encodeComponent(partyId)}/sync');
    return JsonUtils.decimal(JsonUtils.asMap(raw), ['timestamp']);
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
        _activePartyId == cleanPartyId &&
        _activeSocketToken == cleanToken) {
      return;
    }

    disconnectWatchParty();
    _activePartyId = cleanPartyId;
    _activeSocketToken = cleanToken;

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
    if (event == 'receiveQuickMessage') {
      final text = _extractString(payload, const ['text', 'message']);
      if (text != null && text.isNotEmpty) {
        _quickMessageController.add(text);
      }
    } else if (event == 'receiveReaction') {
      final emoji = _extractString(payload, const ['emoji', 'reaction']);
      if (emoji != null && emoji.isNotEmpty) {
        _reactionController.add(emoji);
      }
    }
  }

  String? _extractString(dynamic payload, List<String> keys) {
    if (payload is String) return payload.trim();
    if (payload is Map) {
      for (final k in keys) {
        final v = payload[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
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

  void _emitEvent(String eventName, Map<String, dynamic> data) {
    if (_socket == null || !_isConnectedToNamespace) return;
    final frame = '42${jsonEncode([eventName, data])}';
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
