import 'package:equatable/equatable.dart';

class HistoryEntry {
  final String name;
  final String date;
  final String month;
  final String sets;
  final String duration;
  final String precision;
  final bool isHighlighted;
  final String? badge;
  final double caloriesBurned;
  final String exerciseType;

  const HistoryEntry({
    required this.name,
    required this.date,
    required this.month,
    required this.sets,
    required this.duration,
    required this.precision,
    this.isHighlighted = false,
    this.badge,
    this.caloriesBurned = 0,
    this.exerciseType = 'pushup',
  });
}

abstract class HistoryState extends Equatable {
  const HistoryState();
  @override
  List<Object?> get props => [];
}

class HistoryLoading extends HistoryState {
  const HistoryLoading();
}

class HistoryLoaded extends HistoryState {
  final List<HistoryEntry> entries;
  final double avgAccuracy;
  final int activeDays;
  final String coachInsight;

  const HistoryLoaded({
    this.entries = const [],
    this.avgAccuracy = 0,
    this.activeDays = 0,
    this.coachInsight = 'Complete your first workout to unlock AI coaching insights.',
  });

  @override
  List<Object?> get props => [entries, avgAccuracy, activeDays, coachInsight];
}
