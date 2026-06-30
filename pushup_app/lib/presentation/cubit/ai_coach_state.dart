import 'package:equatable/equatable.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final String time;
  const ChatMessage(
      {required this.text, required this.isUser, required this.time});
}

abstract class AiCoachState extends Equatable {
  const AiCoachState();
  @override
  List<Object?> get props => [];
}

class AiCoachLoaded extends AiCoachState {
  final List<ChatMessage> messages;
  final double coreStability;
  final double depthAccuracy;
  final bool isTyping;

  const AiCoachLoaded({
    this.messages = const [],
    this.coreStability = 0,
    this.depthAccuracy = 0,
    this.isTyping = false,
  });

  @override
  List<Object?> get props => [messages, coreStability, depthAccuracy, isTyping];
}
