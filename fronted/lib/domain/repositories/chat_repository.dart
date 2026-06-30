/// Abstract chat repository for AI chatbot.
abstract class ChatRepository {
  /// Send a message and return the AI response.
  Future<String> sendMessage(String userMessage,
      {String? workoutContext, String? userProfileContext});
}
