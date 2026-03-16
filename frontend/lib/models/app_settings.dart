// MenuMate - 앱 설정 모델

class AppSettings {
  final AppLanguage language;
  final bool showResponseText;
  final bool enableTTS;
  final double cameraZoom;

  const AppSettings({
    this.language = AppLanguage.korean,
    this.showResponseText = true,
    this.enableTTS = true,
    this.cameraZoom = 1.0,
  });

  AppSettings copyWith({
    AppLanguage? language,
    bool? showResponseText,
    bool? enableTTS,
    double? cameraZoom,
  }) {
    return AppSettings(
      language: language ?? this.language,
      showResponseText: showResponseText ?? this.showResponseText,
      enableTTS: enableTTS ?? this.enableTTS,
      cameraZoom: cameraZoom ?? this.cameraZoom,
    );
  }

  Map<String, dynamic> toJson() => {
        'language': language.code,
        'showResponseText': showResponseText,
        'enableTTS': enableTTS,
        'cameraZoom': cameraZoom,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      language: AppLanguage.fromCode(json['language'] as String? ?? 'ko'),
      showResponseText: json['showResponseText'] as bool? ?? true,
      enableTTS: json['enableTTS'] as bool? ?? true,
      cameraZoom: (json['cameraZoom'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

enum AppLanguage {
  korean('ko', '한국어'),
  english('en', 'English');

  final String code;
  final String displayName;

  const AppLanguage(this.code, this.displayName);

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLanguage.korean,
    );
  }
}

// 다국어 문자열
class AppStrings {
  static String get(AppLanguage lang, StringKey key) {
    return _strings[lang]?[key] ?? _strings[AppLanguage.korean]![key]!;
  }

  static const Map<AppLanguage, Map<StringKey, String>> _strings = {
    AppLanguage.korean: {
      // 홈 화면
      StringKey.appName: 'MenuMate',
      StringKey.whatCanIHelp: '무엇을 도와드릴까요?',
      StringKey.aiAssistant: 'AI 어시스턴트',
      StringKey.startWithCamera: '카메라로 시작하기',
      StringKey.howToUse: '사용 방법',
      StringKey.myProfile: '내 프로필',
      StringKey.profileSettings: '프로필 설정',
      StringKey.connectToServer: '서버에 연결하면 AI 어시스턴트를 선택할 수 있어요',
      StringKey.cloudRun: 'Cloud Run',
      StringKey.localServer: '로컬 서버',
      StringKey.autoDetect: '자동 감지',
      StringKey.connectionTest: '연결 테스트',
      StringKey.serverConnected: '서버 연결 성공!',
      StringKey.serverNotFound: '서버에 연결할 수 없습니다',
      StringKey.autoDetecting: '서버 자동 감지 중...',

      // 카메라 화면
      StringKey.liveMode: '실시간 모드',
      StringKey.kioskScan: '키오스크 스캔',
      StringKey.liveModeOn: '실시간 모드 켜기',
      StringKey.liveModeOff: '실시간 모드 끄기',
      StringKey.analyzing: '분석 중...',
      StringKey.whatIsThis: '이거 뭐야?',
      StringKey.recommend: '추천해줘',
      StringKey.voiceInputStart: '음성 입력 시작',
      StringKey.connected: '실시간 연결됨',
      StringKey.connecting: '연결 중...',
      StringKey.disconnected: '연결 종료됨',
      StringKey.close: '닫기',
      StringKey.evaluate: '평가',

      // 설정
      StringKey.settings: '설정',
      StringKey.language: '언어',
      StringKey.showResponseText: '응답 텍스트 표시',
      StringKey.enableTTS: '음성 출력',
      StringKey.cameraZoom: '카메라 줌',
      StringKey.touchToSelect: '터치하여 선택',

      // 모드
      StringKey.modeMenu: '메뉴판',
      StringKey.modeMenuDesc: '메뉴 분석',
      StringKey.modeKiosk: '키오스크',
      StringKey.modeKioskDesc: '주문 도움',
      StringKey.modeGrocery: '장보기',
      StringKey.modeGroceryDesc: '식재료 분석',
      StringKey.modeProduct: '상품',
      StringKey.modeProductDesc: '영양 정보',
      StringKey.modeGeneral: '만능',
      StringKey.modeGeneralDesc: '모든 것',

      // 도움말
      StringKey.help1Title: '카메라로 비추기',
      StringKey.help1Desc: '메뉴판이나 키오스크 화면을 카메라로 비춰주세요',
      StringKey.help2Title: '메뉴 가리키기',
      StringKey.help2Desc: '궁금한 메뉴를 손가락으로 가리키거나 터치하세요',
      StringKey.help3Title: '질문하기',
      StringKey.help3Desc: '"이거 뭐야?", "추천해줘" 등 음성으로 물어보세요',
      StringKey.help4Title: '안내 듣기',
      StringKey.help4Desc: 'AI가 친절하게 음성으로 안내해드려요',
      StringKey.confirm: '확인',

      // 기타
      StringKey.micPermissionRequired: '마이크 권한이 필요합니다',
      StringKey.cameraPermissionRequired: '카메라 권한이 필요합니다',
      StringKey.retry: '다시 시도',
      StringKey.error: '오류',
      StringKey.experienceSaved: '경험이 저장되었습니다',
    },
    AppLanguage.english: {
      // Home Screen
      StringKey.appName: 'MenuMate',
      StringKey.whatCanIHelp: 'How can I help you?',
      StringKey.aiAssistant: 'AI Assistant',
      StringKey.startWithCamera: 'Start with Camera',
      StringKey.howToUse: 'How to Use',
      StringKey.myProfile: 'My Profile',
      StringKey.profileSettings: 'Profile Settings',
      StringKey.connectToServer: 'Connect to server to select AI assistant',
      StringKey.cloudRun: 'Cloud Run',
      StringKey.localServer: 'Local Server',
      StringKey.autoDetect: 'Auto Detect',
      StringKey.connectionTest: 'Test Connection',
      StringKey.serverConnected: 'Server connected!',
      StringKey.serverNotFound: 'Cannot connect to server',
      StringKey.autoDetecting: 'Auto detecting server...',

      // Camera Screen
      StringKey.liveMode: 'Live Mode',
      StringKey.kioskScan: 'Kiosk Scan',
      StringKey.liveModeOn: 'Turn on Live Mode',
      StringKey.liveModeOff: 'Turn off Live Mode',
      StringKey.analyzing: 'Analyzing...',
      StringKey.whatIsThis: 'What is this?',
      StringKey.recommend: 'Recommend',
      StringKey.voiceInputStart: 'Voice input started',
      StringKey.connected: 'Live connected',
      StringKey.connecting: 'Connecting...',
      StringKey.disconnected: 'Disconnected',
      StringKey.close: 'Close',
      StringKey.evaluate: 'Rate',

      // Settings
      StringKey.settings: 'Settings',
      StringKey.language: 'Language',
      StringKey.showResponseText: 'Show Response Text',
      StringKey.enableTTS: 'Enable TTS',
      StringKey.cameraZoom: 'Camera Zoom',
      StringKey.touchToSelect: 'Touch to Select',

      // Modes
      StringKey.modeMenu: 'Menu',
      StringKey.modeMenuDesc: 'Analyze menu',
      StringKey.modeKiosk: 'Kiosk',
      StringKey.modeKioskDesc: 'Order help',
      StringKey.modeGrocery: 'Grocery',
      StringKey.modeGroceryDesc: 'Ingredients',
      StringKey.modeProduct: 'Product',
      StringKey.modeProductDesc: 'Nutrition',
      StringKey.modeGeneral: 'General',
      StringKey.modeGeneralDesc: 'Everything',

      // Help
      StringKey.help1Title: 'Point Camera',
      StringKey.help1Desc: 'Point your camera at the menu or kiosk screen',
      StringKey.help2Title: 'Point or Touch',
      StringKey.help2Desc: 'Point at or touch the item you want to know about',
      StringKey.help3Title: 'Ask Questions',
      StringKey.help3Desc: 'Ask "What is this?" or "Recommend something"',
      StringKey.help4Title: 'Listen to Guide',
      StringKey.help4Desc: 'AI will guide you with friendly voice',
      StringKey.confirm: 'OK',

      // Others
      StringKey.micPermissionRequired: 'Microphone permission required',
      StringKey.cameraPermissionRequired: 'Camera permission required',
      StringKey.retry: 'Retry',
      StringKey.error: 'Error',
      StringKey.experienceSaved: 'Experience saved',
    },
  };
}

enum StringKey {
  appName,
  whatCanIHelp,
  aiAssistant,
  startWithCamera,
  howToUse,
  myProfile,
  profileSettings,
  connectToServer,
  cloudRun,
  localServer,
  autoDetect,
  connectionTest,
  serverConnected,
  serverNotFound,
  autoDetecting,
  liveMode,
  kioskScan,
  liveModeOn,
  liveModeOff,
  analyzing,
  whatIsThis,
  recommend,
  voiceInputStart,
  connected,
  connecting,
  disconnected,
  close,
  evaluate,
  settings,
  language,
  showResponseText,
  enableTTS,
  cameraZoom,
  touchToSelect,
  modeMenu,
  modeMenuDesc,
  modeKiosk,
  modeKioskDesc,
  modeGrocery,
  modeGroceryDesc,
  modeProduct,
  modeProductDesc,
  modeGeneral,
  modeGeneralDesc,
  help1Title,
  help1Desc,
  help2Title,
  help2Desc,
  help3Title,
  help3Desc,
  help4Title,
  help4Desc,
  confirm,
  micPermissionRequired,
  cameraPermissionRequired,
  retry,
  error,
  experienceSaved,
}
