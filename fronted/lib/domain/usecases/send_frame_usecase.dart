import 'dart:typed_data';
import '../repositories/pushup_repository.dart';

class SendFrameUseCase {
  final PushupRepository repository;
  SendFrameUseCase(this.repository);

  void call(Uint8List jpegBytes) => repository.sendFrame(jpegBytes);

  void sendRawFrame(Uint8List rawBytes) => repository.sendRawFrame(rawBytes);
}
