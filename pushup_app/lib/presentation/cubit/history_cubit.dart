import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../domain/repositories/workout_repository.dart';
import 'history_state.dart';

class HistoryCubit extends Cubit<HistoryState> {
  final WorkoutRepository _workoutRepo;

  HistoryCubit(this._workoutRepo) : super(const HistoryLoading());

  Future<void> loadHistory(String uid) async {
    emit(const HistoryLoading());
    try {
      final workouts =
          await _workoutRepo.getWorkoutHistory(uid, limit: 50);

      if (workouts.isEmpty) {
        emit(const HistoryLoaded(
          entries: [],
          avgAccuracy: 0,
          activeDays: 0,
          coachInsight:
              'No workouts yet! Start your first session to begin tracking.',
        ));
        return;
      }

      // Map WorkoutSession → HistoryEntry
      final entries = workouts.map((w) {
        final dayFormat = DateFormat('dd');
        final monthFormat = DateFormat('MMM');
        final accuracy = (w.avgConfidence * 100).round();

        return HistoryEntry(
          name: w.exerciseName,
          date: dayFormat.format(w.timestamp),
          month: monthFormat.format(w.timestamp).toUpperCase(),
          sets: '${w.repCount} reps',
          duration: w.durationFormatted,
          precision: '$accuracy%',
          caloriesBurned: w.caloriesBurned,
          exerciseType: w.exerciseType,
          isHighlighted: w.avgConfidence > 0.95,
          badge: w.avgConfidence > 0.95 ? 'Perfect' : null,
        );
      }).toList();

      // Calculate avg accuracy
      double totalConfidence = 0;
      for (final w in workouts) {
        totalConfidence += w.avgConfidence;
      }
      final avgAccuracy =
          (totalConfidence / workouts.length * 100).roundToDouble();

      // Calculate unique active days
      final uniqueDays = <String>{};
      for (final w in workouts) {
        uniqueDays.add(DateFormat('yyyy-MM-dd').format(w.timestamp));
      }

      // Generate coach insight
      String insight;
      if (avgAccuracy > 90) {
        insight =
            'Outstanding form! Your average accuracy of ${avgAccuracy.round()}% shows excellent technique. Consider increasing intensity.';
      } else if (avgAccuracy > 70) {
        insight =
            'Good progress! Your accuracy is ${avgAccuracy.round()}%. Focus on controlled movements to push past 90%.';
      } else {
        insight =
            'Keep practicing! Watch the AI form feedback during your sessions to improve your technique.';
      }

      emit(HistoryLoaded(
        entries: entries,
        avgAccuracy: avgAccuracy,
        activeDays: uniqueDays.length,
        coachInsight: insight,
      ));
    } catch (e) {
      emit(const HistoryLoaded(
        coachInsight: 'Unable to load history. Please try again.',
      ));
    }
  }
}
