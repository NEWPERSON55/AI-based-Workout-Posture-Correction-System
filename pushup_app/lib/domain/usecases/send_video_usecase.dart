import 'dart:typed_data';
import '../repositories/pushup_repository.dart';

class SendVideoUseCase {
  final PushupRepository repository;
  SendVideoUseCase(this.repository);

  void call(Uint8List videoBytes) => repository.sendVideoBytes(videoBytes);
}
