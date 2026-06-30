import 'package:equatable/equatable.dart';
import '../../domain/entities/pushup_result.dart';

abstract class SquatState extends Equatable {
  const SquatState();

  @override
  List<Object?> get props => [];
}

class SquatInitial extends SquatState {
  const SquatInitial();
}

class SquatConnecting extends SquatState {
  const SquatConnecting();
}

class SquatStreaming extends SquatState {
  final PushupResult result;
  final bool isMuted;

  const SquatStreaming(this.result, {this.isMuted = false});

  @override
  List<Object?> get props => [result, isMuted];
}

class SquatVideoProcessing extends SquatState {
  final PushupResult result;
  final bool isDone;
  final String videoPath;
  final int frameIndex;
  final int totalFrames;
  final bool isMuted;

  const SquatVideoProcessing({
    required this.result,
    required this.videoPath,
    this.isDone = false,
    this.frameIndex = 0,
    this.totalFrames = 0,
    this.isMuted = false,
  });

  @override
  List<Object?> get props => [
        result,
        isDone,
        videoPath,
        frameIndex,
        totalFrames,
        isMuted,
      ];
}

/// Emitted when a squat session ends with a summary.
class SquatSessionComplete extends SquatState {
  final int repCount;
  final double caloriesBurned;
  final int durationSeconds;
  final String prediction;
  final double avgConfidence;

  const SquatSessionComplete({
    required this.repCount,
    required this.caloriesBurned,
    required this.durationSeconds,
    required this.prediction,
    required this.avgConfidence,
  });

  @override
  List<Object?> get props =>
      [repCount, caloriesBurned, durationSeconds, prediction, avgConfidence];
}

class SquatError extends SquatState {
  final String message;

  const SquatError(this.message);

  @override
  List<Object?> get props => [message];
}
