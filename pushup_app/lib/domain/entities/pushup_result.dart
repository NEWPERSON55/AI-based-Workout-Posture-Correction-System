import 'package:equatable/equatable.dart';

class PushupResult extends Equatable {
  final bool personDetected;
  final int repCount;
  final String prediction;
  final double confidence;
  final String state;
  final bool isValidPosture;
  final List<String> feedback;
  final int gateProgress;
  final int gateRequired;
  final List<dynamic> keypoints;
  final bool isDone; // video processing complete flag
  final int frameIndex;
  final int totalFrames;
  final String? image; // base64-encoded JPEG from backend

  const PushupResult({
    required this.personDetected,
    required this.repCount,
    required this.prediction,
    required this.confidence,
    required this.state,
    required this.isValidPosture,
    required this.feedback,
    required this.gateProgress,
    required this.gateRequired,
    required this.keypoints,
    this.isDone = false,
    this.frameIndex = 0,
    this.totalFrames = 0,
    this.image,
  });

  @override
  List<Object?> get props => [
    personDetected,
    repCount,
    prediction,
    confidence,
    state,
    isValidPosture,
    feedback,
    gateProgress,
    gateRequired,
    keypoints,
    isDone,
    frameIndex,
    totalFrames,
    image,
  ];
}
