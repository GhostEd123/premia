import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable state for user preferences on the Settings screen.
class SettingsState {
  const SettingsState({
    this.premierReminders = true,
    this.subtitlesByDefault = true,
  });

  final bool premierReminders;
  final bool subtitlesByDefault;

  SettingsState copyWith({
    bool? premierReminders,
    bool? subtitlesByDefault,
  }) =>
      SettingsState(
        premierReminders: premierReminders ?? this.premierReminders,
        subtitlesByDefault: subtitlesByDefault ?? this.subtitlesByDefault,
      );
}

/// Manages user preferences (`premierReminders`, `subtitlesByDefault`).
class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  void setPremierReminders(bool enabled) {
    state = state.copyWith(premierReminders: enabled);
  }

  void setSubtitlesByDefault(bool enabled) {
    state = state.copyWith(subtitlesByDefault: enabled);
  }
}

final settingsNotifierProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
