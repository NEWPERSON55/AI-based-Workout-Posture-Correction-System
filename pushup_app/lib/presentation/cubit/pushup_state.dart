import 'package:equatable/equatable.dart';
import '../../domain/entities/pushup_result.dart';

abstract class PushupState extends Equatable {
  const PushupState();

  @override
  List<Object?> get props => [];
}

class PushupInitial extends PushupState {
  const PushupInitial();
}

class PushupConnecting extends PushupState {
  const PushupConnecting();
}

class PushupStreaming extends PushupState {
  final PushupResult result;
  final bool isMuted;

  const PushupStreaming(this.result, {this.isMuted = false});

  @override
  List<Object?> get props => [result, isMuted];
}

class PushupVideoProcessing extends PushupState {
  final PushupResult result;
  final bool isDone;
  final String videoPath;
  final int frameIndex;
  final int totalFrames;
  final bool isMuted;

  const PushupVideoProcessing({
    required this.result,
    required this.videoPath,
    this.isDone = false,
    this.frameIndex = 0,
    this.totalFrames = 0,
    this.isMuted = false,
  });

  @override
  List<Object?> get props =>
      [result, isDone, videoPath, frameIndex, totalFrames, isMuted];
}

/// Emitted when a session ends with a summary of the workout.
class PushupSessionComplete extends PushupState {
  final int repCount;
  final double caloriesBurned;
  final int durationSeconds;
  final String prediction;
  final double avgConfidence;

  const PushupSessionComplete({
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

class PushupError extends PushupState {
  final String message;

  const PushupError(this.message);

  @override
  List<Object?> get props => [message];
}
