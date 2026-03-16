// GlassKiosk Copilot - TTS 서비스
// 다국어 음성 출력

import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  String _currentLanguage = 'en-US';

  // 언어 코드 매핑 (API 응답 -> TTS 언어 코드)
  static const Map<String, String> _languageMap = {
    'ko-KR': 'ko-KR',
    'ko': 'ko-KR',
    'en-US': 'en-US',
    'en': 'en-US',
    'ja-JP': 'ja-JP',
    'ja': 'ja-JP',
    'zh-CN': 'zh-CN',
    'zh': 'zh-CN',
    'es-ES': 'es-ES',
    'es': 'es-ES',
    'fr-FR': 'fr-FR',
    'fr': 'fr-FR',
    'de-DE': 'de-DE',
    'de': 'de-DE',
    'vi-VN': 'vi-VN',
    'vi': 'vi-VN',
    'th-TH': 'th-TH',
    'th': 'th-TH',
  };

  Future<void> _initialize() async {
    if (_isInitialized) return;

    await _flutterTts.setSharedInstance(true);
    await _flutterTts.setSpeechRate(0.5); // 느린 속도로 명확하게
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _isInitialized = true;
  }

  // 언어 설정
  Future<void> setLanguage(String languageCode) async {
    await _initialize();

    // 언어 코드 매핑
    final mappedLanguage = _languageMap[languageCode] ?? 'en-US';

    // 해당 언어 지원 여부 확인
    final languages = await _flutterTts.getLanguages;
    final isSupported = (languages as List).any(
      (lang) => lang.toString().startsWith(mappedLanguage.split('-')[0]),
    );

    if (isSupported) {
      await _flutterTts.setLanguage(mappedLanguage);
      _currentLanguage = mappedLanguage;
    } else {
      // 지원하지 않으면 영어로 폴백
      await _flutterTts.setLanguage('en-US');
      _currentLanguage = 'en-US';
    }
  }

  // 마크다운 제거
  String _stripMarkdown(String text) {
    return text
        // 볼드/이탤릭 제거
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')
        .replaceAll(RegExp(r'__(.+?)__'), r'$1')
        .replaceAll(RegExp(r'_(.+?)_'), r'$1')
        // 코드 블록 제거
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        .replaceAll(RegExp(r'`(.+?)`'), r'$1')
        // 헤더 제거
        .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
        // 링크 텍스트만 남기기
        .replaceAll(RegExp(r'\[(.+?)\]\(.+?\)'), r'$1')
        // 불릿 포인트 정리
        .replaceAll(RegExp(r'^[\-\*]\s+', multiLine: true), '')
        // 이모지는 유지
        .trim();
  }

  // 음성 출력
  Future<void> speak(String text, [String? languageCode]) async {
    await _initialize();

    if (languageCode != null && languageCode != _currentLanguage) {
      await setLanguage(languageCode);
    }

    // 마크다운 제거 후 음성 출력
    final cleanText = _stripMarkdown(text);
    await _flutterTts.speak(cleanText);
  }

  // 음성 중지
  Future<void> stop() async {
    await _flutterTts.stop();
  }

  // 음성 일시정지
  Future<void> pause() async {
    await _flutterTts.pause();
  }

  // 사용 가능한 언어 목록
  Future<List<String>> getAvailableLanguages() async {
    await _initialize();
    final languages = await _flutterTts.getLanguages;
    return (languages as List).map((e) => e.toString()).toList();
  }

  // 현재 언어 반환
  String get currentLanguage => _currentLanguage;

  // 리소스 해제
  void dispose() {
    _flutterTts.stop();
  }
}
