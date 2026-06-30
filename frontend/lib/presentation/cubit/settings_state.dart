import 'package:equatable/equatable.dart';

abstract class SettingsState extends Equatable {
  const SettingsState();
  @override
  List<Object?> get props => [];
}

class SettingsLoaded extends SettingsState {
  final bool darkMode;
  final bool workoutReminders;
  final bool aiTips;
  final String language;

  const SettingsLoaded({
    this.darkMode = true,
    this.workoutReminders = true,
    this.aiTips = false,
    this.language = 'English (US)',
  });

  @override
  List<Object?> get props => [darkMode, workoutReminders, aiTips, language];
}
