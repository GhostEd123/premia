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

/// HTTP implementation of [PartiesRepository].
class PartiesRepositoryImpl implements PartiesRepository {
  PartiesRepositoryImpl(this._http);
  final HttpService _http;

  @override
  Future<QuickMessages> getQuickMessages() async {
    final raw = await _http.get('/parties/quick-messages');
    return QuickMessagesDto.fromJson(JsonUtils.asMap(raw)).toEntity();
  }

  @override
  Future<double> getSyncTimestamp(String partyId) async {
    final raw = await _http.get('/parties/${Uri.encodeComponent(partyId)}/sync');
    return JsonUtils.decimal(JsonUtils.asMap(raw), ['timestamp']);
  }
}
