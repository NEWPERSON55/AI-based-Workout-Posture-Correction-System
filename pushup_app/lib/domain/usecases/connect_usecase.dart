import '../repositories/pushup_repository.dart';

class ConnectUseCase {
  final PushupRepository repository;
  ConnectUseCase(this.repository);

  Future<void> call(String url) => repository.connect(url);
}
