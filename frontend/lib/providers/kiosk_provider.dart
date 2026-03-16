// GlassKiosk Copilot - 상태 관리 Provider

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/kiosk_response.dart';
import '../models/prompt_info.dart';
import '../models/user_profile.dart';
import '../models/food_experience.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../services/rag_service.dart';

enum KioskState { idle, processing, success, error }

class KioskProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final TtsService _ttsService = TtsService();
  final RAGService _ragService = RAGService();

  KioskState _state = KioskState.idle;
  KioskResponse? _lastResponse;
  String? _errorMessage;
  bool _isSpeaking = false;

  // 프롬프트 관련 상태
  List<PromptInfo> _availablePrompts = [];
  String? _selectedPromptId;
  bool _isLoadingPrompts = false;

  // 사용자 프로필 & 모드
  UserProfile _userProfile = UserProfile();
  UseMode _currentMode = UseMode.general;

  // Getters
  KioskState get state => _state;
  KioskResponse? get lastResponse => _lastResponse;
  String? get errorMessage => _errorMessage;
  bool get isSpeaking => _isSpeaking;
  Coordinates? get highlightCoordinates => _lastResponse?.coordinates;

  // 프롬프트 Getters
  List<PromptInfo> get availablePrompts => _availablePrompts;
  String? get selectedPromptId => _selectedPromptId;
  bool get isLoadingPrompts => _isLoadingPrompts;
  PromptInfo? get selectedPrompt => _availablePrompts.isEmpty
      ? null
      : _availablePrompts.firstWhere(
          (p) => p.id == _selectedPromptId,
          orElse: () => _availablePrompts.first,
        );

  // 프로필 & 모드 Getters
  UserProfile get userProfile => _userProfile;
  UseMode get currentMode => _currentMode;
  bool get hasUserProfile => _userProfile.hasAnyPreference;

  // API 서버 URL 설정
  static const String _defaultLocalUrl = 'http://localhost:8000';
  // GitHub Pages에서 자동으로 가져오는 설정 URL
  static const String _configUrl = 'https://qlanfr.github.io/gemini-glass-kiosk/config/server.json';

  String _serverUrl = _defaultLocalUrl;
  String? _cloudRunUrl; // GitHub Pages에서 가져온 URL
  String get serverUrl => _serverUrl;
  bool get isUsingCloudRun => _serverUrl.contains('run.app');

  void setServerUrl(String url) {
    _serverUrl = url;
    _apiService.setBaseUrl(url);
    notifyListeners();
  }

  /// GitHub Pages에서 최신 Cloud Run URL 가져오기
  Future<String?> fetchCloudRunUrl() async {
    try {
      final response = await _apiService.fetchConfig(_configUrl);
      if (response != null && response['server_url'] != null) {
        _cloudRunUrl = response['server_url'] as String;
        return _cloudRunUrl;
      }
    } catch (e) {
      // 설정 가져오기 실패 시 무시
    }
    return null;
  }

  /// Cloud Run URL로 전환
  Future<void> useCloudRun() async {
    // 저장된 URL이 없으면 GitHub Pages에서 가져오기
    _cloudRunUrl ??= await fetchCloudRunUrl();

    if (_cloudRunUrl != null && _cloudRunUrl!.isNotEmpty) {
      setServerUrl(_cloudRunUrl!);
    }
  }

  /// 로컬 서버로 전환
  void useLocalServer() {
    setServerUrl(_defaultLocalUrl);
  }

  /// 자동 감지: Cloud Run 먼저 시도, 실패 시 로컬
  Future<void> autoDetectServer() async {
    // 1. GitHub Pages에서 최신 Cloud Run URL 가져오기
    final cloudUrl = await fetchCloudRunUrl();

    // 2. Cloud Run 먼저 시도
    if (cloudUrl != null && cloudUrl.isNotEmpty) {
      _apiService.setBaseUrl(cloudUrl);
      if (await _apiService.healthCheck()) {
        _serverUrl = cloudUrl;
        notifyListeners();
        return;
      }
    }

    // 3. 로컬 서버 시도
    _apiService.setBaseUrl(_defaultLocalUrl);
    if (await _apiService.healthCheck()) {
      _serverUrl = _defaultLocalUrl;
      notifyListeners();
      return;
    }

    // 4. 둘 다 실패 시 기본값 유지
    _serverUrl = _defaultLocalUrl;
    _apiService.setBaseUrl(_serverUrl);
    notifyListeners();
  }

  // 사용 모드 변경
  void setMode(UseMode mode) {
    _currentMode = mode;
    // 모드에 따라 적절한 프롬프트 자동 선택
    switch (mode) {
      case UseMode.menu:
        _selectedPromptId = 'kio_friendly';
        break;
      case UseMode.kiosk:
        _selectedPromptId = 'kio_friendly';
        break;
      case UseMode.grocery:
        _selectedPromptId = 'grocery_helper';
        break;
      case UseMode.product:
        _selectedPromptId = 'nutrition_expert';
        break;
      case UseMode.general:
        _selectedPromptId = 'universal_vision';
        break;
    }
    notifyListeners();
  }

  // 사용자 프로필 업데이트
  void updateProfile(UserProfile profile) {
    _userProfile = profile;
    _saveProfileToStorage();
    notifyListeners();
  }

  // 알레르기 토글
  void toggleAllergy(String allergyId) {
    final allergies = List<String>.from(_userProfile.allergies);
    if (allergies.contains(allergyId)) {
      allergies.remove(allergyId);
    } else {
      allergies.add(allergyId);
    }
    _userProfile = _userProfile.copyWith(allergies: allergies);
    _saveProfileToStorage();
    notifyListeners();
  }

  // 식이 제한 토글
  void toggleDietaryRestriction(String restrictionId) {
    final restrictions = List<String>.from(_userProfile.dietaryRestrictions);
    if (restrictions.contains(restrictionId)) {
      restrictions.remove(restrictionId);
    } else {
      restrictions.add(restrictionId);
    }
    _userProfile = _userProfile.copyWith(dietaryRestrictions: restrictions);
    _saveProfileToStorage();
    notifyListeners();
  }

  // 건강 목표 토글
  void toggleHealthGoal(String goalId) {
    final goals = List<String>.from(_userProfile.healthGoals);
    if (goals.contains(goalId)) {
      goals.remove(goalId);
    } else {
      goals.add(goalId);
    }
    _userProfile = _userProfile.copyWith(healthGoals: goals);
    _saveProfileToStorage();
    notifyListeners();
  }

  // 프로필 로컬 저장
  Future<void> _saveProfileToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', jsonEncode(_userProfile.toJson()));
  }

  // 프로필 로컬에서 불러오기
  Future<void> loadProfileFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString('user_profile');
    if (profileJson != null) {
      _userProfile = UserProfile.fromJson(jsonDecode(profileJson));
      notifyListeners();
    }
  }

  // 프롬프트 목록 로드
  Future<void> loadPrompts() async {
    _isLoadingPrompts = true;
    notifyListeners();

    try {
      final response = await _apiService.getPrompts();
      _availablePrompts = response.prompts;
      _selectedPromptId ??= response.defaultPromptId;
    } catch (e) {
      // 프롬프트 로드 실패 시 기본값 사용
      _availablePrompts = [];
    } finally {
      _isLoadingPrompts = false;
      notifyListeners();
    }
  }

  // 프롬프트 선택
  void selectPrompt(String promptId) {
    _selectedPromptId = promptId;
    notifyListeners();
  }

  // 이미지 분석 요청 (RAG 컨텍스트 포함)
  Future<void> processImage(List<int> imageBytes, {String? query}) async {
    _state = KioskState.processing;
    _errorMessage = null;
    notifyListeners();

    try {
      // RAG 컨텍스트 검색 (이전 음식 경험 기반)
      await _ragService.initialize();
      final ragContext = await _ragService.retrieveContext(targetItem: query);

      // RAG 컨텍스트를 쿼리에 추가
      String augmentedQuery = query ?? '';
      if (ragContext.hasContext) {
        final contextString = ragContext.toPromptContext(_userProfile);
        augmentedQuery = '$contextString\n[사용자 질문]\n$augmentedQuery';
      } else if (_userProfile.hasAnyPreference) {
        // RAG 경험이 없어도 프로필은 포함
        augmentedQuery = '${_userProfile.toPromptContext()}\n\n[사용자 질문]\n$augmentedQuery';
      }

      final response = await _apiService.processKioskImage(
        imageBytes,
        userQuery: augmentedQuery.isNotEmpty ? augmentedQuery : null,
        promptId: _selectedPromptId,
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

  // ===== RAG: 음식 경험 관리 =====

  /// RAG 서비스 초기화
  Future<void> initializeRAG() async {
    await _ragService.initialize();
  }

  /// 음식 경험 추가
  Future<void> addFoodExperience({
    required String foodName,
    required ExperienceType type,
    required int rating,
  }) async {
    await _ragService.initialize();
    final experience = FoodExperience(
      foodName: foodName,
      type: type,
      rating: rating,
    );
    await _ragService.addExperience(experience);
    notifyListeners();
  }

  /// 모든 음식 경험 가져오기
  Future<List<FoodExperience>> getAllFoodExperiences() async {
    await _ragService.initialize();
    return _ragService.getAllExperiences();
  }

  /// 음식 경험 삭제
  Future<void> deleteFoodExperience(String id) async {
    await _ragService.deleteExperience(id);
    notifyListeners();
  }

  /// RAG 통계
  Future<Map<String, int>> getRAGStats() async {
    await _ragService.initialize();
    return _ragService.getStats();
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }
}
