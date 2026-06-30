import 'dart:typed_data';
import '../entities/pushup_result.dart';

abstract class PushupRepository {
  Future<void> connect(String url);
  void sendFrame(Uint8List jpegBytes);
  void sendRawFrame(Uint8List rawBytes);
  void sendVideoBytes(Uint8List videoBytes);
  Stream<PushupResult> get resultStream;
  void disconnect();
}
