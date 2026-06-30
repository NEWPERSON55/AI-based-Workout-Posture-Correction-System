import '../../domain/entities/pushup_result.dart';

class PushupResultModel extends PushupResult {
  const PushupResultModel({
    required super.personDetected,
    required super.repCount,
    required super.prediction,
    required super.confidence,
    required super.state,
    required super.isValidPosture,
    required super.feedback,
    required super.gateProgress,
    required super.gateRequired,
    required super.keypoints,
    super.isDone,
    super.frameIndex,
    super.totalFrames,
    super.image,
  });

  factory PushupResultModel.fromJson(Map<String, dynamic> json) {
    return PushupResultModel(
      personDetected: json['person_detected'] as bool? ?? false,
      repCount: json['rep_count'] as int? ?? 0,
      prediction: json['prediction'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      state: json['state'] as String? ?? 'NOT_DETECTED',
      isValidPosture: json['is_valid_posture'] as bool? ?? false,
      feedback:
          (json['feedback'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      gateProgress: json['gate_progress'] as int? ?? 0,
      gateRequired: json['gate_required'] as int? ?? 10,
      keypoints: json['keypoints'] as List<dynamic>? ?? [],
      frameIndex: json['frame_index'] as int? ?? 0,
      totalFrames: json['total_frames'] as int? ?? 0,
      image: json['image'] as String?,
    );
  }

  /// Factory for the "done" signal from the video endpoint.
  factory PushupResultModel.done({required int totalReps}) {
    return PushupResultModel(
      personDetected: false,
      repCount: totalReps,
      prediction: '',
      confidence: 0.0,
      state: 'DONE',
      isValidPosture: false,
      feedback: const ['Video analysis complete!'],
      gateProgress: 0,
      gateRequired: 0,
      keypoints: const [],
      isDone: true,
    );
  }
}
