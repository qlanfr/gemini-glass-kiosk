// MenuMate - 음식 경험 모델 (RAG용 로컬 DB)

/// 경험 타입
enum ExperienceType {
  loved,      // 좋아요
  disliked,   // 싫어요
  allergic,   // 알레르기 반응
}

/// 음식 경험 데이터
class FoodExperience {
  final String id;
  final String foodName;
  final ExperienceType type;
  final int rating; // 1-5
  final DateTime createdAt;

  FoodExperience({
    String? id,
    required this.foodName,
    required this.type,
    required this.rating,
    DateTime? createdAt,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now();

  /// JSON 변환 (Hive 저장용)
  Map<String, dynamic> toJson() => {
    'id': id,
    'foodName': foodName,
    'type': type.name,
    'rating': rating,
    'createdAt': createdAt.toIso8601String(),
  };

  factory FoodExperience.fromJson(Map<String, dynamic> json) => FoodExperience(
    id: json['id'] as String,
    foodName: json['foodName'] as String,
    type: ExperienceType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => ExperienceType.loved,
    ),
    rating: json['rating'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  /// RAG 검색 우선순위 (알레르기가 가장 높음)
  int get priority {
    switch (type) {
      case ExperienceType.allergic:
        return 100;
      case ExperienceType.disliked:
        return 50;
      case ExperienceType.loved:
        return 30;
    }
  }

  /// 프롬프트용 텍스트
  String toPromptText() {
    final emoji = switch (type) {
      ExperienceType.loved => '❤️',
      ExperienceType.disliked => '👎',
      ExperienceType.allergic => '⚠️',
    };
    return '$emoji "$foodName": $rating점';
  }

  /// 경고 메시지 (알레르기용)
  String? get warningMessage {
    if (type == ExperienceType.allergic) {
      return '⚠️ 주의: "$foodName"에서 알레르기 반응 경험이 있습니다!';
    }
    return null;
  }

  @override
  String toString() => 'FoodExperience($foodName, $type, $rating점)';
}
