import 'package:equatable/equatable.dart';

class Exercise {
  final String name;
  final String level;
  final String calories;
  final String duration;
  final IconType iconType;
  final bool isActive;

  const Exercise({
    required this.name,
    required this.level,
    required this.calories,
    required this.duration,
    required this.iconType,
    this.isActive = true,
  });
}

enum IconType { fitnessCenter, exercise, reorder, directionsRun }

abstract class ExercisesState extends Equatable {
  const ExercisesState();
  @override
  List<Object?> get props => [];
}

class ExercisesLoaded extends ExercisesState {
  final List<Exercise> exercises;
  final String searchQuery;
  final String aiPrediction;

  const ExercisesLoaded({
    this.exercises = const [],
    this.searchQuery = '',
    this.aiPrediction = 'Push-up',
  });

  @override
  List<Object?> get props => [exercises, searchQuery, aiPrediction];
}
