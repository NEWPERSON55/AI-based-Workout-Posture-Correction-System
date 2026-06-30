import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final SharedPreferences _prefs;

  SettingsCubit(this._prefs)
      : super(SettingsLoaded(
          darkMode: true,
          workoutReminders: true,
          aiTips: false,
          language: 'English (US)',
        )) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    emit(SettingsLoaded(
      darkMode: _prefs.getBool('darkMode') ?? true,
      workoutReminders: _prefs.getBool('workoutReminders') ?? true,
      aiTips: _prefs.getBool('aiTips') ?? false,
      language: _prefs.getString('language') ?? 'English (US)',
    ));
  }

  void toggleDarkMode() {
    final s = state as SettingsLoaded;
    final val = !s.darkMode;
    _prefs.setBool('darkMode', val);
    emit(SettingsLoaded(
      darkMode: val,
      workoutReminders: s.workoutReminders,
      aiTips: s.aiTips,
      language: s.language,
    ));
  }

  void toggleWorkoutReminders() {
    final s = state as SettingsLoaded;
    final val = !s.workoutReminders;
    _prefs.setBool('workoutReminders', val);
    emit(SettingsLoaded(
      darkMode: s.darkMode,
      workoutReminders: val,
      aiTips: s.aiTips,
      language: s.language,
    ));
  }

  void toggleAiTips() {
    final s = state as SettingsLoaded;
    final val = !s.aiTips;
    _prefs.setBool('aiTips', val);
    emit(SettingsLoaded(
      darkMode: s.darkMode,
      workoutReminders: s.workoutReminders,
      aiTips: val,
      language: s.language,
    ));
  }
}
