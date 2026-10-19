import 'package:equatable/equatable.dart';

/// Allowed quick-chat strings and emoji reactions for the watch-party UI.
class QuickMessages extends Equatable {
  const QuickMessages({this.messages = const [], this.reactions = const []});

  final List<String> messages;
  final List<String> reactions;

  @override
  List<Object?> get props => [messages, reactions];
}
