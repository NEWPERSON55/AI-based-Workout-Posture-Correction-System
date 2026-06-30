import 'dart:typed_data';
import '../../domain/entities/pushup_result.dart';
import '../../domain/repositories/pushup_repository.dart';
import '../datasources/websocket_datasource.dart';

class PushupRepositoryImpl implements PushupRepository {
  final WebSocketDatasource datasource;

  PushupRepositoryImpl(this.datasource);

  @override
  Future<void> connect(String url) => datasource.connect(url);

  @override
  void sendFrame(Uint8List jpegBytes) => datasource.sendFrame(jpegBytes);

  @override
  void sendRawFrame(Uint8List rawBytes) => datasource.sendRawFrame(rawBytes);

  @override
  void sendVideoBytes(Uint8List videoBytes) =>
      datasource.sendVideoBytes(videoBytes);

  @override
  Stream<PushupResult> get resultStream => datasource.resultStream;

  @override
  void disconnect() => datasource.disconnect();
}
