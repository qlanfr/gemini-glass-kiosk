// GlassKiosk Copilot - API 서비스
// 백엔드 통신 (HTTP + WebSocket)

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/kiosk_response.dart';

class ApiService {
  String _baseUrl = 'http://localhost:8000';
  WebSocketChannel? _wsChannel;

  void setBaseUrl(String url) {
    _baseUrl = url;
  }

  // REST API: 이미지 분석 요청
  Future<KioskResponse> processKioskImage(
    List<int> imageBytes, {
    String? userQuery,
    String? languageHint,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/process-kiosk');

    // Base64 인코딩
    final base64Image = base64Encode(imageBytes);

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'image_base64': base64Image,
        'user_query': userQuery,
        'language_hint': languageHint,
      }),
    );

    if (response.statusCode == 200) {
      return KioskResponse.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw ApiException(
        error['message'] ?? 'Unknown error',
        error['audio_response'] ?? 'An error occurred',
      );
    }
  }

  // REST API: 파일 업로드 방식
  Future<KioskResponse> uploadKioskImage(
    Uint8List imageBytes,
    String filename, {
    String? userQuery,
    String? languageHint,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/process-kiosk/upload');

    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: filename,
      ));

    if (userQuery != null) {
      request.fields['user_query'] = userQuery;
    }
    if (languageHint != null) {
      request.fields['language_hint'] = languageHint;
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return KioskResponse.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException('Upload failed', 'Failed to upload image');
    }
  }

  // WebSocket: Live API 연결
  void connectWebSocket({
    required Function(KioskResponse) onResponse,
    required Function(String) onError,
    Function()? onConnected,
    Function()? onDisconnected,
  }) {
    final wsUrl = _baseUrl.replaceFirst('http', 'ws');
    _wsChannel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws/live'));

    _wsChannel!.stream.listen(
      (message) {
        final data = jsonDecode(message);
        final type = data['type'];

        switch (type) {
          case 'connected':
            onConnected?.call();
            break;
          case 'response':
            onResponse(KioskResponse.fromJson(data['data']));
            break;
          case 'error':
            onError(data['message'] ?? 'Unknown error');
            break;
          case 'turn_complete':
            // 턴 완료 처리
            break;
        }
      },
      onError: (error) {
        onError(error.toString());
      },
      onDone: () {
        onDisconnected?.call();
      },
    );
  }

  // WebSocket: 이미지 프레임 전송
  void sendImageFrame(List<int> imageBytes, {String mimeType = 'image/jpeg'}) {
    if (_wsChannel == null) return;

    _wsChannel!.sink.add(jsonEncode({
      'type': 'image',
      'data': base64Encode(imageBytes),
      'mime_type': mimeType,
    }));
  }

  // WebSocket: 텍스트 메시지 전송
  void sendTextMessage(String text) {
    if (_wsChannel == null) return;

    _wsChannel!.sink.add(jsonEncode({
      'type': 'text',
      'data': text,
    }));
  }

  // WebSocket: 연결 종료
  void disconnectWebSocket() {
    if (_wsChannel != null) {
      _wsChannel!.sink.add(jsonEncode({'type': 'end'}));
      _wsChannel!.sink.close();
      _wsChannel = null;
    }
  }

  // 헬스체크
  Future<bool> healthCheck() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

class ApiException implements Exception {
  final String message;
  final String audioResponse;

  ApiException(this.message, this.audioResponse);

  @override
  String toString() => message;
}
