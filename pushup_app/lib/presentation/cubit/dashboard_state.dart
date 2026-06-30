import 'package:equatable/equatable.dart';

abstract class DashboardState extends Equatable {
  const DashboardState();
  @override
  List<Object?> get props => [];
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardLoaded extends DashboardState {
  final String userName;
  final double caloriesBurned;
  final int caloriesGoal;
  final int sessionsCompleted;
  final int sessionsGoal;
  final int recoveryScore;
  final int weeklyWorkouts;
  final int totalRepsToday;

  const DashboardLoaded({
    this.userName = '',
    this.caloriesBurned = 0,
    this.caloriesGoal = 700,
    this.sessionsCompleted = 0,
    this.sessionsGoal = 3,
    this.recoveryScore = 100,
    this.weeklyWorkouts = 0,
    this.totalRepsToday = 0,
  });

  @override
  List<Object?> get props => [
        userName,
        caloriesBurned,
        caloriesGoal,
        sessionsCompleted,
        sessionsGoal,
        recoveryScore,
        weeklyWorkouts,
        totalRepsToday,
      ];
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError(this.message);

  @override
  List<Object?> get props => [message];
}
