import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../domain/usecases/connect_usecase.dart';
import '../../domain/usecases/send_frame_usecase.dart';
import '../../domain/usecases/send_video_usecase.dart';
import '../../domain/usecases/disconnect_usecase.dart';
import '../../domain/usecases/calculate_calories.dart';
import '../../domain/entities/pushup_result.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/repositories/workout_repository.dart';
import 'squat_state.dart';

class SquatCubit extends Cubit<SquatState> {
  final ConnectUseCase connectUseCase;
  final SendFrameUseCase sendFrameUseCase;
  final SendVideoUseCase sendVideoUseCase;
  final DisconnectUseCase disconnectUseCase;
  final WorkoutRepository workoutRepo;
  final CalculateCalories calculateCalories;

  CameraController? cameraController;
  StreamSubscription? _resultSubscription;

  // ── TTS Logic ──
  final FlutterTts _flutterTts = FlutterTts();
  bool _isMuted = false;
  int _lastSpokenRep = -1;
  String _lastSpokenFeedback = '';

  // ── Windows-only: Timer-based capture ──
  Timer? _frameTimer;
  bool _isSendingFrame = false;

  // ── Android-only: FPS throttle ──
  static const int _targetFps = 15;
  final int _frameIntervalMs = 1000 ~/ _targetFps;
  DateTime _lastFrameTime = DateTime.now();
  static const int _downscaleFactor = 2;

  // ── Session tracking for KCAL ──
  DateTime? _sessionStartTime;
  String? _uid;
  double _userWeightKg = 70.0;
  int _lastRepCount = 0;
  double _totalConfidence = 0;
  int _confidenceCount = 0;

  SquatCubit({
    required this.connectUseCase,
    required this.sendFrameUseCase,
    required this.sendVideoUseCase,
    required this.disconnectUseCase,
    required this.workoutRepo,
    this.calculateCalories = const CalculateCalories(),
  }) : super(const SquatInitial()) {
    _initTts();
  }

  /// Set user context for saving workouts.
  void setUser(String uid, {double weightKg = 70.0}) {
    _uid = uid;
    _userWeightKg = weightKg;
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    if (state is SquatStreaming) {
      emit(
        SquatStreaming((state as SquatStreaming).result, isMuted: _isMuted),
      );
    } else if (state is SquatVideoProcessing) {
      final s = state as SquatVideoProcessing;
      emit(
        SquatVideoProcessing(
          result: s.result,
          videoPath: s.videoPath,
          isDone: s.isDone,
          frameIndex: s.frameIndex,
          totalFrames: s.totalFrames,
          isMuted: _isMuted,
        ),
      );
    }
  }

  void _speakFeedback(PushupResult result) {
    if (_isMuted) return;

    if (result.repCount > _lastSpokenRep) {
      _lastSpokenRep = result.repCount;
      if (_lastSpokenRep > 0) {
        _flutterTts.speak(_lastSpokenRep.toString());
      }
    }

    if (result.feedback.isNotEmpty) {
      final latestMsg = result.feedback.first;
      if (latestMsg != _lastSpokenFeedback &&
          latestMsg != "Wait for person..." &&
          latestMsg != "Get ready...") {
        _lastSpokenFeedback = latestMsg;
        _flutterTts.speak(latestMsg);
      }
    }
  }

  void _trackConfidence(PushupResult result) {
    _lastRepCount = result.repCount;
    if (result.confidence > 0) {
      _totalConfidence += result.confidence;
      _confidenceCount++;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  CAMERA SESSION — connects to /ws/squat endpoints
  // ═══════════════════════════════════════════════════════════════

  Future<void> startSession(String wsUrl) async {
    emit(const SquatConnecting());
    _lastSpokenRep = -1;
    _lastSpokenFeedback = '';
    _sessionStartTime = DateTime.now();
    _lastRepCount = 0;
    _totalConfidence = 0;
    _confidenceCount = 0;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        emit(const SquatError('No camera found on this device'));
        return;
      }

      final resolution = Platform.isAndroid
          ? ResolutionPreset.low
          : ResolutionPreset.medium;

      cameraController = CameraController(
        cameras.last,
        resolution,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.jpeg,
      );

      await cameraController!.initialize();

      final effectiveUrl = Platform.isAndroid
          ? wsUrl.replaceFirst(RegExp(r'/ws/squat$'), '/ws/squat/android')
          : wsUrl;
      await connectUseCase(effectiveUrl);

      _resultSubscription = connectUseCase.repository.resultStream.listen(
        (result) {
          if (!isClosed) {
            _speakFeedback(result);
            _trackConfidence(result);
            emit(SquatStreaming(result, isMuted: _isMuted));
          }
        },
        onError: (error) {
          if (!isClosed) {
            emit(SquatError(error.toString()));
          }
        },
      );

      if (Platform.isAndroid) {
        _startAndroidImageStream();
      } else {
        _startWindowsTimerCapture();
      }

      emit(
        SquatStreaming(
          const PushupResult(
            personDetected: false,
            repCount: 0,
            prediction: '',
            confidence: 0.0,
            state: 'STARTING',
            isValidPosture: false,
            feedback: ['Waiting for first frame...'],
            gateProgress: 0,
            gateRequired: 10,
            keypoints: [],
          ),
          isMuted: _isMuted,
        ),
      );
    } catch (e) {
      emit(SquatError('Failed to start session: $e'));
    }
  }

  // ─── ANDROID: Raw YUV420 stream with FPS limit ───────────────
  void _startAndroidImageStream() {
    _lastFrameTime = DateTime.now();

    cameraController!.startImageStream((CameraImage image) {
      final now = DateTime.now();
      if (now.difference(_lastFrameTime).inMilliseconds < _frameIntervalMs) {
        return;
      }
      _lastFrameTime = now;
      _sendRawYuvFrame(image);
    });
  }

  void _sendRawYuvFrame(CameraImage cameraImage) {
    try {
      final int origW = cameraImage.width;
      final int origH = cameraImage.height;
      final yPlane = cameraImage.planes[0];
      final uPlane = cameraImage.planes[1];
      final vPlane = cameraImage.planes[2];

      final int yRowStride = yPlane.bytesPerRow;
      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel ?? 1;
      final int sensorOrientation =
          cameraController!.description.sensorOrientation;

      final int newW = origW ~/ _downscaleFactor;
      final int newH = origH ~/ _downscaleFactor;
      final dsResult = _downscaleYuvPlanes(
        yPlane.bytes,
        uPlane.bytes,
        vPlane.bytes,
        origW,
        origH,
        yRowStride,
        uvRowStride,
        uvPixelStride,
      );

      final header = ByteData(24);
      header.setInt32(0, newW, Endian.little);
      header.setInt32(4, newH, Endian.little);
      header.setInt32(8, newW, Endian.little);
      header.setInt32(12, newW ~/ 2, Endian.little);
      header.setInt32(16, 1, Endian.little);
      header.setInt32(20, sensorOrientation, Endian.little);

      final yDs = dsResult[0];
      final uDs = dsResult[1];
      final vDs = dsResult[2];
      final totalSize = 24 + yDs.length + uDs.length + vDs.length;
      final payload = Uint8List(totalSize);
      int offset = 0;

      payload.setRange(offset, offset + 24, header.buffer.asUint8List());
      offset += 24;
      payload.setRange(offset, offset + yDs.length, yDs);
      offset += yDs.length;
      payload.setRange(offset, offset + uDs.length, uDs);
      offset += uDs.length;
      payload.setRange(offset, offset + vDs.length, vDs);

      sendFrameUseCase.sendRawFrame(payload);
    } catch (_) {}
  }

  List<Uint8List> _downscaleYuvPlanes(
    Uint8List yBytes,
    Uint8List uBytes,
    Uint8List vBytes,
    int origW,
    int origH,
    int yRowStride,
    int uvRowStride,
    int uvPixelStride,
  ) {
    final int newW = origW ~/ _downscaleFactor;
    final int newH = origH ~/ _downscaleFactor;
    final int uvNewW = newW ~/ 2;
    final int uvNewH = newH ~/ 2;

    final yOut = Uint8List(newW * newH);
    int yIdx = 0;
    for (int row = 0; row < newH; row++) {
      final srcRow = row * _downscaleFactor;
      final srcRowOffset = srcRow * yRowStride;
      for (int col = 0; col < newW; col++) {
        yOut[yIdx++] = yBytes[srcRowOffset + col * _downscaleFactor];
      }
    }

    final uOut = Uint8List(uvNewW * uvNewH);
    final vOut = Uint8List(uvNewW * uvNewH);
    int uvIdx = 0;
    for (int row = 0; row < uvNewH; row++) {
      final srcRow = row * _downscaleFactor;
      final srcRowOffset = srcRow * uvRowStride;
      for (int col = 0; col < uvNewW; col++) {
        final srcCol = col * _downscaleFactor * uvPixelStride;
        final idx = srcRowOffset + srcCol;
        uOut[uvIdx] = idx < uBytes.length ? uBytes[idx] : 128;
        vOut[uvIdx] = idx < vBytes.length ? vBytes[idx] : 128;
        uvIdx++;
      }
    }

    return [yOut, uOut, vOut];
  }

  // ─── WINDOWS: Timer-based capture ──────────────────
  void _startWindowsTimerCapture() {
    _frameTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _captureAndSend(),
    );
  }

  Future<void> _captureAndSend() async {
    if (_isSendingFrame ||
        cameraController == null ||
        !cameraController!.value.isInitialized) {
      return;
    }
    _isSendingFrame = true;
    try {
      final XFile imageFile = await cameraController!.takePicture();
      final Uint8List jpegBytes = await imageFile.readAsBytes();
      sendFrameUseCase(jpegBytes);
    } catch (_) {
    } finally {
      _isSendingFrame = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  VIDEO SESSION — connects to /ws/squat/video endpoint
  // ═══════════════════════════════════════════════════════════════

  Future<void> startVideoSession(String wsUrl) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.single.path;
    if (filePath == null) return;

    emit(const SquatConnecting());
    _lastSpokenRep = -1;
    _lastSpokenFeedback = '';
    _sessionStartTime = DateTime.now();
    _lastRepCount = 0;
    _totalConfidence = 0;
    _confidenceCount = 0;

    try {
      final videoBytes = await File(filePath).readAsBytes();
      final videoWsUrl = wsUrl.replaceFirst('/ws/squat', '/ws/squat/video');
      await connectUseCase(videoWsUrl);

      const defaultResult = PushupResult(
        personDetected: false,
        repCount: 0,
        prediction: '',
        confidence: 0.0,
        state: 'WAITING',
        isValidPosture: false,
        feedback: ['Processing video...'],
        gateProgress: 0,
        gateRequired: 10,
        keypoints: [],
      );

      emit(
        SquatVideoProcessing(
          result: defaultResult,
          videoPath: filePath,
          isMuted: _isMuted,
        ),
      );

      _resultSubscription = connectUseCase.repository.resultStream.listen(
        (result) {
          if (!isClosed) {
            _speakFeedback(result);
            _trackConfidence(result);

            if (result.isDone) {
              _saveSession(result.repCount, 'Correct',
                  isVideoSession: true);
            }

            emit(
              SquatVideoProcessing(
                result: result,
                videoPath: filePath,
                isDone: result.isDone,
                frameIndex: result.frameIndex,
                totalFrames: result.totalFrames,
                isMuted: _isMuted,
              ),
            );
          }
        },
        onError: (error) {
          if (!isClosed) {
            emit(SquatError(error.toString()));
          }
        },
      );

      sendVideoUseCase(videoBytes);
    } catch (e) {
      emit(SquatError('Failed to start video session: $e'));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  SESSION SAVE (KCAL + Firestore)
  // ═══════════════════════════════════════════════════════════════

  Future<void> _saveSession(int repCount, String prediction,
      {bool isVideoSession = false}) async {
    if (_uid == null || repCount <= 0) return;

    final duration = _sessionStartTime != null
        ? DateTime.now().difference(_sessionStartTime!).inSeconds
        : 0;

    final avgConf =
        _confidenceCount > 0 ? _totalConfidence / _confidenceCount : 0.0;

    final kcal = calculateCalories(
      exerciseType: 'squat',
      repCount: repCount,
      durationSeconds: duration,
      userWeightKg: _userWeightKg,
    );

    final session = WorkoutSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      exerciseType: 'squat',
      repCount: repCount,
      prediction: prediction,
      avgConfidence: avgConf,
      durationSeconds: duration,
      caloriesBurned: kcal,
      feedback: const [],
      timestamp: DateTime.now(),
    );

    try {
      await workoutRepo.saveWorkout(_uid!, session);
    } catch (_) {}

    if (!isVideoSession && !isClosed) {
      emit(SquatSessionComplete(
        repCount: repCount,
        caloriesBurned: kcal,
        durationSeconds: duration,
        prediction: prediction,
        avgConfidence: avgConf,
      ));
    }
  }

  // ─── Lifecycle ─────────────────────────────────────────────────
  void stopSession() {
    if (_lastRepCount > 0 && state is SquatStreaming) {
      final currentResult = (state as SquatStreaming).result;
      _saveSession(_lastRepCount, currentResult.prediction);
    }

    if (Platform.isAndroid) {
      try {
        cameraController?.stopImageStream();
      } catch (_) {}
    }
    _frameTimer?.cancel();
    _frameTimer = null;
    _resultSubscription?.cancel();
    _resultSubscription = null;
    cameraController?.dispose();
    cameraController = null;
    disconnectUseCase();

    if (state is! SquatSessionComplete) {
      emit(const SquatInitial());
    }
  }

  void dismissSummary() => emit(const SquatInitial());

  @override
  Future<void> close() {
    stopSession();
    return super.close();
  }
}
