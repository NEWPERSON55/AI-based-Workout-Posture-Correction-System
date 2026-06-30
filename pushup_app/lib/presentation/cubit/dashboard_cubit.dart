import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/workout_repository.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final WorkoutRepository _workoutRepo;

  DashboardCubit(this._workoutRepo) : super(const DashboardLoading());

  /// Load real dashboard stats from Firestore.
  Future<void> loadDashboard(String uid) async {
    emit(const DashboardLoading());
    try {
      // Get user profile for name
      final profile = await _workoutRepo.getUserProfile(uid);
      final userName = profile?.name ?? 'User';

      // Get today's start
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));

      // Fetch today's and this week's workouts
      final todayWorkouts = await _workoutRepo.getWorkoutsAfter(uid, todayStart);
      final weekWorkouts = await _workoutRepo.getWorkoutsAfter(uid, weekStart);

      // Calculate stats
      double todayCalories = 0;
      int todayReps = 0;
      for (final w in todayWorkouts) {
        todayCalories += w.caloriesBurned;
        todayReps += w.repCount;
      }

      // Recovery score: 100 if rested yesterday, decreases with consecutive days
      int recoveryScore = 100;
      final yesterdayStart = todayStart.subtract(const Duration(days: 1));
      final yesterdayWorkouts = weekWorkouts.where(
        (w) => w.timestamp.isAfter(yesterdayStart) && w.timestamp.isBefore(todayStart),
      );
      if (yesterdayWorkouts.isNotEmpty) {
        recoveryScore = 88; // worked out yesterday
      }
      if (todayWorkouts.isNotEmpty) {
        recoveryScore = (recoveryScore * 0.95).round(); // worked out today too
      }

      emit(DashboardLoaded(
        userName: userName,
        caloriesBurned: todayCalories,
        caloriesGoal: 700,
        sessionsCompleted: todayWorkouts.length,
        sessionsGoal: 3,
        recoveryScore: recoveryScore,
        weeklyWorkouts: weekWorkouts.length,
        totalRepsToday: todayReps,
      ));
    } catch (e) {
      emit(DashboardError('Failed to load dashboard: $e'));
    }
  }

  void refresh(String uid) => loadDashboard(uid);
}
