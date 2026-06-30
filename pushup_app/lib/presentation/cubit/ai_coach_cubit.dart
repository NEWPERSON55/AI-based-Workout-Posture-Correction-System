import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/workout_repository.dart';
import 'ai_coach_state.dart';

class AiCoachCubit extends Cubit<AiCoachState> {
  final ChatRepository _chatRepo;
  final WorkoutRepository _workoutRepo;

  String? _uid;

  AiCoachCubit(this._chatRepo, this._workoutRepo)
    : super(
        const AiCoachLoaded(
          messages: [
            ChatMessage(
              text:
                  'Hello! I\'m KINETIC AI, your personal fitness coach. Ask me anything about your workouts, form tips, or nutrition!',
              isUser: false,
              time: '',
            ),
          ],
        ),
      );

  /// Set the current user ID for context-aware responses.
  void setUser(String uid) {
    _uid = uid;
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final current = state as AiCoachLoaded;
    final timeStr = DateFormat('h:mm a').format(DateTime.now());

    // Add user message
    final withUserMsg = List<ChatMessage>.from(current.messages)
      ..add(ChatMessage(text: text, isUser: true, time: timeStr));

    emit(
      AiCoachLoaded(
        messages: withUserMsg,
        coreStability: current.coreStability,
        depthAccuracy: current.depthAccuracy,
        isTyping: true,
      ),
    );

    try {
      // Build context from recent workouts
      String? workoutContext;
      String? profileContext;

      if (_uid != null) {
        try {
          final recentWorkouts = await _workoutRepo.getWorkoutHistory(
            _uid!,
            limit: 5,
          );
          if (recentWorkouts.isNotEmpty) {
            final buffer = StringBuffer();
            for (final w in recentWorkouts) {
              buffer.writeln(
                '${w.exerciseName}: ${w.repCount} reps, ${w.caloriesBurned} kcal, '
                'accuracy ${(w.avgConfidence * 100).round()}%, ${w.durationFormatted}',
              );
            }
            workoutContext = buffer.toString();
          }

          final profile = await _workoutRepo.getUserProfile(_uid!);
          if (profile != null) {
            profileContext =
                '${profile.name}, ${profile.age}yo, ${profile.weight}kg, '
                '${profile.height}cm, goal: ${profile.goal}, tier: ${profile.tier}';
          }
        } catch (_) {
          // Context fetch failed — proceed without it
        }
      }

      // Call Gemini
      final response = await _chatRepo.sendMessage(
        text,
        workoutContext: workoutContext,
        userProfileContext: profileContext,
      );

      final replyTime = DateFormat('h:mm a').format(DateTime.now());
      final currentState = state as AiCoachLoaded;
      final withReply = List<ChatMessage>.from(currentState.messages)
        ..add(ChatMessage(text: response, isUser: false, time: replyTime));

      // Update metrics from recent workouts
      double stability = current.coreStability;
      double depth = current.depthAccuracy;
      if (_uid != null) {
        try {
          final recent = await _workoutRepo.getWorkoutHistory(_uid!, limit: 10);
          if (recent.isNotEmpty) {
            double totalConf = 0;
            for (final w in recent) {
              totalConf += w.avgConfidence;
            }
            stability = (totalConf / recent.length * 100).roundToDouble();
            depth = stability * 0.9; // approximation
          }
        } catch (_) {}
      }

      emit(
        AiCoachLoaded(
          messages: withReply,
          coreStability: stability,
          depthAccuracy: depth,
          isTyping: false,
        ),
      );
    } catch (e) {
      print(e.toString());
      final currentState = state as AiCoachLoaded;
      final errorMsgs = List<ChatMessage>.from(currentState.messages)
        ..add(
          ChatMessage(
            text:
                'Sorry, I couldn\'t process your request. Please check your internet connection and try again.',
            isUser: false,
            time: DateFormat('h:mm a').format(DateTime.now()),
          ),
        );

      emit(
        AiCoachLoaded(
          messages: errorMsgs,
          coreStability: current.coreStability,
          depthAccuracy: current.depthAccuracy,
          isTyping: false,
        ),
      );
    }
  }
}
