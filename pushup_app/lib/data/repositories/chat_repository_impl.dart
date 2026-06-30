import '../../domain/repositories/chat_repository.dart';
import '../datasources/gemini_datasource.dart';

class ChatRepositoryImpl implements ChatRepository {
  final GeminiDatasource _datasource;

  ChatRepositoryImpl(this._datasource);

  @override
  Future<String> sendMessage(String userMessage,
      {String? workoutContext, String? userProfileContext}) {
    return _datasource.sendMessage(
      userMessage,
      workoutContext: workoutContext,
      userProfileContext: userProfileContext,
    );
  }
}
