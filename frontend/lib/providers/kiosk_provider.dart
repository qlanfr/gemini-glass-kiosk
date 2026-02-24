// GlassKiosk Copilot - 상태 관리 Provider

import 'package:flutter/foundation.dart';
import '../models/kiosk_response.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';

enum KioskState { idle, processing, success, error }

class KioskProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final TtsService _ttsService = TtsService();

  KioskState _state = KioskState.idle;
  KioskResponse? _lastResponse;
  String? _errorMessage;
  bool _isSpeaking = false;

  // Getters
  KioskState get state => _state;
  KioskResponse? get lastResponse => _lastResponse;
  String? get errorMessage => _errorMessage;
  bool get isSpeaking => _isSpeaking;
  Coordinates? get highlightCoordinates => _lastResponse?.coordinates;

  // API 서버 URL 설정
  String _serverUrl = 'http://localhost:8000';
  String get serverUrl => _serverUrl;

  void setServerUrl(String url) {
    _serverUrl = url;
    _apiService.setBaseUrl(url);
    notifyListeners();
  }

  // 이미지 분석 요청
  Future<void> processImage(List<int> imageBytes, {String? query}) async {
    _state = KioskState.processing;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.processKioskImage(
        imageBytes,
        userQuery: query,
      );

      _lastResponse = response;
      _state = response.isSuccess ? KioskState.success : KioskState.error;

      // TTS로 응답 읽기
      if (response.audioResponse.isNotEmpty) {
        await speakResponse(response.audioResponse, response.detectedLanguage);
      }
    } catch (e) {
      _state = KioskState.error;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  // TTS 음성 출력
  Future<void> speakResponse(String text, String language) async {
    _isSpeaking = true;
    notifyListeners();

    try {
      await _ttsService.speak(text, language);
    } finally {
      _isSpeaking = false;
      notifyListeners();
    }
  }

  // TTS 중지
  Future<void> stopSpeaking() async {
    await _ttsService.stop();
    _isSpeaking = false;
    notifyListeners();
  }

  // 상태 초기화
  void reset() {
    _state = KioskState.idle;
    _lastResponse = null;
    _errorMessage = null;
    notifyListeners();
  }

  // 서버 연결 테스트
  Future<bool> checkServerConnection() async {
    return await _apiService.healthCheck();
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }
}
