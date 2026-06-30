import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import '../../core/config/app_config.dart';
import '../cubit/squat_cubit.dart';
import '../cubit/squat_state.dart';
import '../widgets/skeleton_painter.dart';

class SquatPage extends StatelessWidget {
  const SquatPage({super.key});

  static const String _wsUrl = '${AppConfig.wsBaseUrl}/ws/squat';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: BlocBuilder<SquatCubit, SquatState>(
        builder: (context, state) {
          return switch (state) {
            SquatInitial() => _buildStartScreen(context),
            SquatConnecting() => _buildConnecting(),
            SquatStreaming(:final result, :final isMuted) => _buildStreamingUI(
              context,
              result,
              context.read<SquatCubit>().cameraController,
              isMuted,
            ),
            SquatVideoProcessing() => _VideoProcessingView(
              state: state,
              wsUrl: _wsUrl,
            ),
            SquatSessionComplete() => _buildSessionComplete(context, state),
            SquatError(:final message) => _buildError(context, message),
            _ => const SizedBox.shrink(),
          };
        },
      ),
    );
  }

  // ─── START SCREEN ───────────────────────────────────────────────
  Widget _buildStartScreen(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Back button
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 40),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white70,
                  size: 28,
                ),
              ),
            ),
          ),
          const Spacer(),
          // Animated icon — teal/cyan for squat
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF00BFA5), Color(0xFF00796B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00BFA5).withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.accessibility_new_rounded,
              color: Colors.white,
              size: 56,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Squat Detector',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Real-time AI feedback on your squats',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 48),
          _GlowButton(
            label: 'Start Session',
            icon: Icons.play_arrow_rounded,
            color: const Color(0xFF00BFA5),
            onPressed: () => context.read<SquatCubit>().startSession(_wsUrl),
          ),
          const SizedBox(height: 16),
          _GlowButton(
            label: 'Analyze Video',
            icon: Icons.video_library_rounded,
            color: const Color(0xFF00B0FF),
            onPressed: () =>
                context.read<SquatCubit>().startVideoSession(_wsUrl),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ─── CONNECTING ─────────────────────────────────────────────────
  Widget _buildConnecting() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: const Color(0xFF00BFA5),
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Connecting to server…',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ─── STREAMING UI ───────────────────────────────────────────────
  Widget _buildStreamingUI(
    BuildContext context,
    dynamic result,
    CameraController? camera,
    bool isMuted,
  ) {
    final bool isCorrect = result.prediction == 'Correct';
    final Color accentColor = isCorrect
        ? const Color(0xFF00E676)
        : const Color(0xFFFF5252);

    return Column(
      children: [
        // ── Camera + overlay ──
        Expanded(
          flex: 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Camera preview
              if (camera != null && camera.value.isInitialized)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                  child: CameraPreview(camera),
                )
              else
                Container(color: Colors.black),

              // Skeleton overlay
              if (camera != null &&
                  camera.value.isInitialized &&
                  (result.keypoints as List).isNotEmpty)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                    child: CustomPaint(
                      painter: SkeletonPainter(
                        keypoints: result.keypoints,
                        sensorOrientation:
                            defaultTargetPlatform == TargetPlatform.android
                            ? 0
                            : camera.description.sensorOrientation,
                        lensDirection: camera.description.lensDirection,
                      ),
                    ),
                  ),
                ),

              // Gradient overlay at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 120,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF0D0D1A).withValues(alpha: 0.95),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                  ),
                ),
              ),

              // Rep count badge (top-left)
              Positioned(
                top: 16,
                left: 16,
                child: _GlassCard(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.repeat, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${result.repCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Mute/Volume button
              Positioned(
                top: 80,
                right: 16,
                child: IconButton(
                  onPressed: () => context.read<SquatCubit>().toggleMute(),
                  icon: Icon(
                    isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white70,
                    size: 28,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),

              // State badge (top-right)
              Positioned(
                top: 16,
                right: 16,
                child: _GlassCard(
                  child: Text(
                    result.state,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Prediction bar (bottom overlay)
              if (result.prediction.isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _GlassCard(
                    child: Row(
                      children: [
                        Icon(
                          isCorrect
                              ? Icons.check_circle_rounded
                              : Icons.warning_rounded,
                          color: accentColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.prediction,
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: result.confidence,
                                  minHeight: 6,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.1,
                                  ),
                                  valueColor: AlwaysStoppedAnimation(
                                    accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(result.confidence * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Feedback panel ──
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Gate progress bar
                Row(
                  children: [
                    const Text(
                      'Gate',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: result.gateRequired > 0
                              ? result.gateProgress / result.gateRequired
                              : 0,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF00BFA5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${result.gateProgress}/${result.gateRequired}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Feedback chips
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: (result.feedback as List).length,
                    separatorBuilder: (context2, index) =>
                        const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final msg = result.feedback[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          msg,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Stop button
                SizedBox(
                  height: 44,
                  child: _GlowButton(
                    label: 'Stop',
                    icon: Icons.stop_rounded,
                    color: const Color(0xFFFF5252),
                    onPressed: () {
                      context.read<SquatCubit>().stopSession();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── ERROR SCREEN ───────────────────────────────────────────────
  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF5252).withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFFF5252),
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Oops!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            _GlowButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              color: const Color(0xFF00BFA5),
              onPressed: () => context.read<SquatCubit>().startSession(_wsUrl),
            ),
            const SizedBox(height: 16),
            _GlowButton(
              label: 'Go Back',
              icon: Icons.arrow_back_rounded,
              color: const Color(0xFF6C63FF),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SESSION COMPLETE ─────────────────────────────────────────
  Widget _buildSessionComplete(BuildContext context, SquatSessionComplete state) {
    final duration = Duration(seconds: state.durationSeconds);
    final mins = duration.inMinutes;
    final secs = duration.inSeconds % 60;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E676), Color(0xFF00C853)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E676).withValues(alpha: 0.4),
                    blurRadius: 30, spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 56),
            ),
            const SizedBox(height: 24),
            const Text('Squat Workout Complete!',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(label: 'Reps', value: '${state.repCount}', icon: Icons.repeat),
                _StatChip(label: 'Calories', value: state.caloriesBurned.toStringAsFixed(1), icon: Icons.local_fire_department),
                _StatChip(label: 'Duration', value: '${mins}m ${secs}s', icon: Icons.timer),
              ],
            ),
            const SizedBox(height: 16),
            _StatChip(
              label: 'Accuracy',
              value: '${(state.avgConfidence * 100).toStringAsFixed(0)}%',
              icon: Icons.analytics,
            ),
            const SizedBox(height: 32),
            _GlowButton(
              label: 'Done',
              icon: Icons.check_rounded,
              onPressed: () {
                context.read<SquatCubit>().dismissSummary();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoProcessingView extends StatelessWidget {
  final SquatVideoProcessing state;
  final String wsUrl;

  const _VideoProcessingView({required this.state, required this.wsUrl});

  @override
  Widget build(BuildContext context) {
    final result = state.result;
    final isDone = state.isDone;

    final bool isCorrect = result.prediction == 'Correct';
    final Color accentColor = isCorrect
        ? const Color(0xFF00E676)
        : const Color(0xFFFF5252);

    // Decode base64 image if present
    Uint8List? imageBytes;
    if (result.image != null) {
      try {
        final base64String = result.image!.split(',').last;
        imageBytes = base64Decode(base64String);
      } catch (e) {
        if (kDebugMode) {
          print('Error decoding frame: $e');
        }
      }
    }

    return Column(
      children: [
        // ── Video Frame + overlay ──
        Expanded(
          flex: 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Streamed Video Frame
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                child: imageBytes != null
                    ? Image.memory(
                        imageBytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : Container(
                        color: Colors.black,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF00B0FF),
                          ),
                        ),
                      ),
              ),

              // Skeleton overlay on video
              if (result.keypoints.isNotEmpty)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                    child: CustomPaint(
                      painter: SkeletonPainter(
                        keypoints: result.keypoints,
                        sensorOrientation: 0,
                        lensDirection: CameraLensDirection.back,
                      ),
                    ),
                  ),
                ),

              // Gradient overlay at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 120,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF0D0D1A).withValues(alpha: 0.95),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                  ),
                ),
              ),

              // "VIDEO" label (top-center)
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BFA5).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00BFA5).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      isDone ? '✅ Analysis Complete' : '🎬 Analyzing Squat Video…',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              // Rep count badge (top-left)
              Positioned(
                top: 50,
                left: 16,
                child: _GlassCard(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.repeat, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${result.repCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Mute/Volume button
              Positioned(
                top: 100,
                right: 16,
                child: IconButton(
                  onPressed: () => context.read<SquatCubit>().toggleMute(),
                  icon: Icon(
                    state.isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white70,
                    size: 28,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),

              // State badge (top-right)
              Positioned(
                top: 50,
                right: 16,
                child: _GlassCard(
                  child: Text(
                    result.state,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Progress bar (bottom of video area)
              if (state.totalFrames > 0 && !isDone)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 60,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: state.frameIndex / state.totalFrames,
                          minHeight: 4,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF00BFA5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Frame ${state.frameIndex} / ${state.totalFrames}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

              // Prediction bar (bottom overlay)
              if (result.prediction.isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _GlassCard(
                    child: Row(
                      children: [
                        Icon(
                          isCorrect
                              ? Icons.check_circle_rounded
                              : Icons.warning_rounded,
                          color: accentColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.prediction,
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: result.confidence,
                                  minHeight: 6,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.1,
                                  ),
                                  valueColor: AlwaysStoppedAnimation(
                                    accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(result.confidence * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Feedback panel ──
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Feedback chips
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: (result.feedback).length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final msg = result.feedback[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          msg,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Stop / Back button
                SizedBox(
                  height: 44,
                  child: _GlowButton(
                    label: isDone ? 'Back' : 'Stop',
                    icon: isDone
                        ? Icons.arrow_back_rounded
                        : Icons.stop_rounded,
                    color: isDone
                        ? const Color(0xFF00BFA5)
                        : const Color(0xFFFF5252),
                    onPressed: () {
                      context.read<SquatCubit>().stopSession();
                      if (isDone) Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatChip({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF00BFA5), size: 24),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── REUSABLE WIDGETS ────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }
}

class _GlowButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  const _GlowButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = const Color(0xFF00BFA5),
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    );
  }
}
