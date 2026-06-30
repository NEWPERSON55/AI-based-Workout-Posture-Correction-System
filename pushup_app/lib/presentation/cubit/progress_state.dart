import 'package:equatable/equatable.dart';

abstract class ProgressState extends Equatable {
  const ProgressState();
  @override
  List<Object?> get props => [];
}

class ProgressLoading extends ProgressState {
  const ProgressLoading();
}

class ProgressLoaded extends ProgressState {
  final double sessionsPerWeek;
  final double sessionsTrend; // % change vs previous week
  final double avgAccuracy;
  final double goalCompletion;
  final int goalRemaining;
  final double totalCalories;
  final int activeMinutes;
  final int totalReps;
  final int pushupReps;
  final int squatReps;

  const ProgressLoaded({
    this.sessionsPerWeek = 0,
    this.sessionsTrend = 0,
    this.avgAccuracy = 0,
    this.goalCompletion = 0,
    this.goalRemaining = 0,
    this.totalCalories = 0,
    this.activeMinutes = 0,
    this.totalReps = 0,
    this.pushupReps = 0,
    this.squatReps = 0,
  });

  @override
  List<Object?> get props => [
        sessionsPerWeek,
        sessionsTrend,
        avgAccuracy,
        goalCompletion,
        goalRemaining,
        totalCalories,
        activeMinutes,
        totalReps,
        pushupReps,
        squatReps,
      ];
}
