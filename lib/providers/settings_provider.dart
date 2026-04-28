import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final bool autoplayTts;
  final bool showNotesOnFront;

  SettingsState({
    this.autoplayTts = false,
    this.showNotesOnFront = true,
  });

  SettingsState copyWith({
    bool? autoplayTts,
    bool? showNotesOnFront,
  }) {
    return SettingsState(
      autoplayTts: autoplayTts ?? this.autoplayTts,
      showNotesOnFront: showNotesOnFront ?? this.showNotesOnFront,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  static const _keyAutoplayTts = 'settings_autoplay_tts';
  static const _keyShowNotesOnFront = 'settings_show_notes_on_front';
  final SharedPreferences prefs;

  SettingsNotifier(this.prefs) : super(SettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    state = SettingsState(
      autoplayTts: prefs.getBool(_keyAutoplayTts) ?? false,
      showNotesOnFront: prefs.getBool(_keyShowNotesOnFront) ?? true,
    );
  }

  Future<void> setAutoplayTts(bool value) async {
    await prefs.setBool(_keyAutoplayTts, value);
    state = state.copyWith(autoplayTts: value);
  }

  Future<void> setShowNotesOnFront(bool value) async {
    await prefs.setBool(_keyShowNotesOnFront, value);
    state = state.copyWith(showNotesOnFront: value);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});
