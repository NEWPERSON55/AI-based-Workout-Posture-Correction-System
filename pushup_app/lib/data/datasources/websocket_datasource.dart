import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/pushup_result_model.dart';

class WebSocketDatasource {
  WebSocketChannel? _channel;
  final StreamController<PushupResultModel> _resultController =
      StreamController<PushupResultModel>.broadcast();

  Stream<PushupResultModel> get resultStream => _resultController.stream;

  Future<void> connect(String url) async {
    _channel = WebSocketChannel.connect(Uri.parse(url));
    await _channel!.ready;

    _channel!.stream.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;

          // Handle video "done" signal
          if (json.containsKey('status') && json['status'] == 'done') {
            _resultController.add(
              PushupResultModel.done(
                totalReps: json['total_reps'] as int? ?? 0,
              ),
            );
            return;
          }

          _resultController.add(PushupResultModel.fromJson(json));
        } catch (e) {
          _resultController.addError('Failed to parse server response: $e');
        }
      },
      onError: (error) {
        _resultController.addError('WebSocket error: $error');
      },
      onDone: () {
        // Connection closed
      },
    );
  }

  void sendFrame(Uint8List jpegBytes) {
    if (_channel == null) return;
    final base64String = base64Encode(jpegBytes);
    final payload = 'data:image/jpeg;base64,$base64String';
    _channel!.sink.add(payload);
  }

  /// Send raw binary frame directly (no base64). For Android YUV420.
  void sendRawFrame(Uint8List rawBytes) {
    if (_channel == null) return;
    _channel!.sink.add(rawBytes);
  }

  void sendVideoBytes(Uint8List videoBytes) {
    if (_channel == null) return;
    _channel!.sink.add(videoBytes);
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _resultController.close();
  }
}
