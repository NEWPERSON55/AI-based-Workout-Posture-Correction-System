import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// Draws MoveNet skeleton keypoints and bone connections on top of the
/// camera preview.  The [keypoints] list is the raw data from the Python
/// backend: 17 keypoints, each `[y_norm, x_norm, confidence]` with
/// coordinates normalised to [0, 1].
///
/// Because the camera sensor is typically rotated relative to the device's
/// natural orientation, we need [sensorOrientation] and [lensDirection]
/// to transform keypoints so they line up with what the preview shows.
class SkeletonPainter extends CustomPainter {
  final List<dynamic> keypoints;
  final double confidenceThreshold;
  final int sensorOrientation;
  final CameraLensDirection lensDirection;

  SkeletonPainter({
    required this.keypoints,
    this.confidenceThreshold = 0.3,
    this.sensorOrientation = 90,
    this.lensDirection = CameraLensDirection.back,
  });

  // MoveNet skeleton connections (same as realtime_detection.py)
  static const List<List<int>> _skeleton = [
    [5, 6], // left_shoulder ↔ right_shoulder
    [5, 7], // left_shoulder → left_elbow
    [7, 9], // left_elbow → left_wrist
    [6, 8], // right_shoulder → right_elbow
    [8, 10], // right_elbow → right_wrist
    [5, 11], // left_shoulder → left_hip
    [6, 12], // right_shoulder → right_hip
    [11, 12], // left_hip ↔ right_hip
    [11, 13], // left_hip → left_knee
    [13, 15], // left_knee → left_ankle
    [12, 14], // right_hip → right_knee
    [14, 16], // right_knee → right_ankle
  ];

  /// Map raw MoveNet keypoint coords to screen coords, accounting for
  /// the camera sensor orientation and front-camera mirroring.
  Offset _toScreen(double yNorm, double xNorm, Size size) {
    double dx, dy;

    // The camera sensor is rotated by [sensorOrientation] degrees clockwise.
    // The preview widget counter-rotates automatically so the image looks
    // correct. We must apply the same rotation to the keypoints.
    //
    // cv2.imdecode does NOT apply EXIF rotation, so the backend gets the
    // raw sensor orientation image.  MoveNet returns [y, x] normalised
    // in THAT coordinate system.
    switch (sensorOrientation) {
      case 90:
        // Sensor landscape → device portrait (most Android rear cameras)
        dx = yNorm;
        dy = 1.0 - xNorm;
        break;
      case 270:
        // Sensor landscape flipped → device portrait (most Android front cameras)
        dx = 1.0 - yNorm;
        dy = xNorm;
        break;
      case 180:
        dx = 1.0 - xNorm;
        dy = 1.0 - yNorm;
        break;
      default: // 0
        dx = xNorm;
        dy = yNorm;
    }

    // Front camera preview is mirrored horizontally
    if (lensDirection == CameraLensDirection.front) {
      dx = 1.0 - dx;
    }

    return Offset(dx * size.width, dy * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (keypoints.isEmpty || keypoints.length != 17) return;

    // ── Draw bones ──────────────────────────────────
    final bonePaint = Paint()
      ..color = const Color(0xFF00DC82)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    for (final pair in _skeleton) {
      final a = keypoints[pair[0]];
      final b = keypoints[pair[1]];
      if (a is! List || b is! List) continue;

      final confA = (a[2] as num).toDouble();
      final confB = (b[2] as num).toDouble();
      if (confA < confidenceThreshold || confB < confidenceThreshold) continue;

      final pA = _toScreen(
        (a[0] as num).toDouble(),
        (a[1] as num).toDouble(),
        size,
      );
      final pB = _toScreen(
        (b[0] as num).toDouble(),
        (b[1] as num).toDouble(),
        size,
      );

      canvas.drawLine(pA, pB, bonePaint);
    }

    // ── Draw keypoints ──────────────────────────────
    final highConfPaint = Paint()..color = const Color(0xFF00E676); // green
    final lowConfPaint = Paint()..color = const Color(0xFFFFAB40); // amber
    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 17; i++) {
      final kp = keypoints[i];
      if (kp is! List) continue;

      final conf = (kp[2] as num).toDouble();
      if (conf < confidenceThreshold) continue;

      final center = _toScreen(
        (kp[0] as num).toDouble(),
        (kp[1] as num).toDouble(),
        size,
      );

      canvas.drawCircle(center, 6.0, conf > 0.7 ? highConfPaint : lowConfPaint);
      canvas.drawCircle(center, 6.0, outlinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) {
    return oldDelegate.keypoints != keypoints;
  }
}
