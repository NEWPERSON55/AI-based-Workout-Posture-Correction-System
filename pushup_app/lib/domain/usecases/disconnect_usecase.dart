import '../repositories/pushup_repository.dart';

class DisconnectUseCase {
  final PushupRepository repository;
  DisconnectUseCase(this.repository);

  void call() => repository.disconnect();
}
