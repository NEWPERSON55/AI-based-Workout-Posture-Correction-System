import 'package:flutter_bloc/flutter_bloc.dart';
import 'exercises_state.dart';

class ExercisesCubit extends Cubit<ExercisesState> {
  ExercisesCubit()
      : super(const ExercisesLoaded(
          exercises: [
            Exercise(
              name: 'Push-up',
              level: 'All Levels',
              calories: '~0.36 kcal/rep',
              duration: 'Real-time',
              iconType: IconType.exercise,
              isActive: true,
            ),
            Exercise(
              name: 'Squat',
              level: 'All Levels',
              calories: '~0.32 kcal/rep',
              duration: 'Real-time',
              iconType: IconType.fitnessCenter,
              isActive: true,
            ),
            Exercise(
              name: 'Bicep Curl',
              level: 'Coming Soon',
              calories: '—',
              duration: '—',
              iconType: IconType.reorder,
              isActive: false,
            ),
            Exercise(
              name: 'Lunges',
              level: 'Coming Soon',
              calories: '—',
              duration: '—',
              iconType: IconType.directionsRun,
              isActive: false,
            ),
          ],
        ));

  void search(String query) {
    final current = state as ExercisesLoaded;
    emit(ExercisesLoaded(
      exercises: current.exercises,
      searchQuery: query,
      aiPrediction: current.aiPrediction,
    ));
  }

  /// Update estimated calories based on user weight.
  void updateCalorieEstimates(double weightKg) {
    final ratio = weightKg / 70.0;
    final pushupCal = (0.36 * ratio).toStringAsFixed(2);
    final squatCal = (0.32 * ratio).toStringAsFixed(2);

    final current = state as ExercisesLoaded;
    final updated = current.exercises.map((e) {
      if (e.name == 'Push-up') {
        return Exercise(
          name: e.name,
          level: e.level,
          calories: '~$pushupCal kcal/rep',
          duration: e.duration,
          iconType: e.iconType,
          isActive: e.isActive,
        );
      } else if (e.name == 'Squat') {
        return Exercise(
          name: e.name,
          level: e.level,
          calories: '~$squatCal kcal/rep',
          duration: e.duration,
          iconType: e.iconType,
          isActive: e.isActive,
        );
      }
      return e;
    }).toList();

    emit(ExercisesLoaded(
      exercises: updated,
      searchQuery: current.searchQuery,
      aiPrediction: current.aiPrediction,
    ));
  }
}
