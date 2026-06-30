import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/workout_repository.dart';
import 'progress_state.dart';

class ProgressCubit extends Cubit<ProgressState> {
  final WorkoutRepository _workoutRepo;

  ProgressCubit(this._workoutRepo) : super(const ProgressLoading());

  Future<void> loadProgress(String uid) async {
    emit(const ProgressLoading());
    try {
      final now = DateTime.now();
      final fourWeeksAgo = now.subtract(const Duration(days: 28));
      final twoWeeksAgo = now.subtract(const Duration(days: 14));
      final oneWeekAgo = now.subtract(const Duration(days: 7));
      final monthStart = DateTime(now.year, now.month, 1);

      // Fetch all workouts in the last 4 weeks
      final allWorkouts =
          await _workoutRepo.getWorkoutsAfter(uid, fourWeeksAgo);

      if (allWorkouts.isEmpty) {
        emit(const ProgressLoaded());
        return;
      }

      // This week's workouts
      final thisWeek =
          allWorkouts.where((w) => w.timestamp.isAfter(oneWeekAgo)).toList();

      // Last week's workouts (for trend)
      final lastWeek = allWorkouts
          .where((w) =>
              w.timestamp.isAfter(twoWeeksAgo) &&
              w.timestamp.isBefore(oneWeekAgo))
          .toList();

      // Sessions per week (this week)
      final sessionsPerWeek = thisWeek.length.toDouble();

      // Trend: % change from last week
      double sessionsTrend = 0;
      if (lastWeek.isNotEmpty) {
        sessionsTrend =
            ((thisWeek.length - lastWeek.length) / lastWeek.length * 100)
                .roundToDouble();
      } else if (thisWeek.isNotEmpty) {
        sessionsTrend = 100; // went from 0 to something
      }

      // Average accuracy across all workouts
      double totalConfidence = 0;
      for (final w in allWorkouts) {
        totalConfidence += w.avgConfidence;
      }
      final avgAccuracy =
          (totalConfidence / allWorkouts.length * 100).roundToDouble();

      // Goal: weekly sessions goal of 5
      const weeklyGoal = 5;
      final goalCompletion =
          (thisWeek.length / weeklyGoal * 100).clamp(0, 100).roundToDouble();
      final goalRemaining = (weeklyGoal - thisWeek.length).clamp(0, weeklyGoal);

      // This month's totals
      final monthWorkouts =
          allWorkouts.where((w) => w.timestamp.isAfter(monthStart)).toList();

      double totalCal = 0;
      int totalMin = 0;
      int totalReps = 0;
      int pushupReps = 0;
      int squatReps = 0;
      for (final w in monthWorkouts) {
        totalCal += w.caloriesBurned;
        totalMin += (w.durationSeconds / 60).round();
        totalReps += w.repCount;
        if (w.exerciseType == 'pushup') {
          pushupReps += w.repCount;
        } else if (w.exerciseType == 'squat') {
          squatReps += w.repCount;
        }
      }

      emit(ProgressLoaded(
        sessionsPerWeek: sessionsPerWeek,
        sessionsTrend: sessionsTrend,
        avgAccuracy: avgAccuracy,
        goalCompletion: goalCompletion,
        goalRemaining: goalRemaining,
        totalCalories: totalCal,
        activeMinutes: totalMin,
        totalReps: totalReps,
        pushupReps: pushupReps,
        squatReps: squatReps,
      ));
    } catch (e) {
      emit(const ProgressLoaded());
    }
  }
}
