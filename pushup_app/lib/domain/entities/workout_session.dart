import 'package:equatable/equatable.dart';

/// A completed workout session stored per-user in Firestore.
class WorkoutSession extends Equatable {
  final String id;
  final String exerciseType; // 'pushup' | 'squat'
  final int repCount;
  final String prediction; // last prediction: 'Correct' | 'Wrong'
  final double avgConfidence;
  final int durationSeconds;
  final double caloriesBurned;
  final List<String> feedback;
  final DateTime timestamp;

  const WorkoutSession({
    required this.id,
    required this.exerciseType,
    required this.repCount,
    required this.prediction,
    required this.avgConfidence,
    required this.durationSeconds,
    required this.caloriesBurned,
    required this.feedback,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'exerciseType': exerciseType,
        'repCount': repCount,
        'prediction': prediction,
        'avgConfidence': avgConfidence,
        'durationSeconds': durationSeconds,
        'caloriesBurned': caloriesBurned,
        'feedback': feedback,
        'timestamp': timestamp.toIso8601String(),
      };

  factory WorkoutSession.fromMap(String id, Map<String, dynamic> map) {
    return WorkoutSession(
      id: id,
      exerciseType: map['exerciseType'] as String? ?? 'pushup',
      repCount: map['repCount'] as int? ?? 0,
      prediction: map['prediction'] as String? ?? '',
      avgConfidence: (map['avgConfidence'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: map['durationSeconds'] as int? ?? 0,
      caloriesBurned: (map['caloriesBurned'] as num?)?.toDouble() ?? 0.0,
      feedback: (map['feedback'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : DateTime.now(),
    );
  }

  /// Human-readable duration string.
  String get durationFormatted {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  /// Exercise name capitalised for display.
  String get exerciseName {
    switch (exerciseType) {
      case 'pushup':
        return 'Push-up';
      case 'squat':
        return 'Squat';
      default:
        return exerciseType;
    }
  }

  @override
  List<Object?> get props => [
        id,
        exerciseType,
        repCount,
        prediction,
        avgConfidence,
        durationSeconds,
        caloriesBurned,
        feedback,
        timestamp,
      ];
}
