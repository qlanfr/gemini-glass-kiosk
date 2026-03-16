// GlassKiosk Copilot - Prompt Info Model
// 시스템 프롬프트 정보 모델

class PromptInfo {
  final String id;
  final String name;
  final String description;
  final String language;
  final String icon;

  PromptInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.language,
    required this.icon,
  });

  factory PromptInfo.fromJson(Map<String, dynamic> json) {
    return PromptInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      language: json['language'] as String,
      icon: json['icon'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'language': language,
      'icon': icon,
    };
  }

  /// 언어 코드를 사람이 읽을 수 있는 형태로 변환
  String get languageDisplay {
    switch (language) {
      case 'ko':
        return '한국어';
      case 'en':
        return 'English';
      case 'ja':
        return '日本語';
      case 'zh':
        return '中文';
      case 'multi':
        return '다국어';
      default:
        return language;
    }
  }
}

class PromptsListResponse {
  final List<PromptInfo> prompts;
  final String defaultPromptId;

  PromptsListResponse({
    required this.prompts,
    required this.defaultPromptId,
  });

  factory PromptsListResponse.fromJson(Map<String, dynamic> json) {
    return PromptsListResponse(
      prompts: (json['prompts'] as List)
          .map((p) => PromptInfo.fromJson(p as Map<String, dynamic>))
          .toList(),
      defaultPromptId: json['default_prompt_id'] as String,
    );
  }
}
