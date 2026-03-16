// VisionMate - 사용자 프로필 모델

class UserProfile {
  final List<String> allergies;        // 알레르기 목록
  final List<String> dietaryRestrictions; // 식이 제한 (채식, 할랄 등)
  final List<String> healthGoals;      // 건강 목표
  final List<String> avoidIngredients; // 피해야 할 성분
  final String preferredLanguage;      // 선호 언어

  UserProfile({
    this.allergies = const [],
    this.dietaryRestrictions = const [],
    this.healthGoals = const [],
    this.avoidIngredients = const [],
    this.preferredLanguage = 'ko',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      allergies: List<String>.from(json['allergies'] ?? []),
      dietaryRestrictions: List<String>.from(json['dietary_restrictions'] ?? []),
      healthGoals: List<String>.from(json['health_goals'] ?? []),
      avoidIngredients: List<String>.from(json['avoid_ingredients'] ?? []),
      preferredLanguage: json['preferred_language'] ?? 'ko',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allergies': allergies,
      'dietary_restrictions': dietaryRestrictions,
      'health_goals': healthGoals,
      'avoid_ingredients': avoidIngredients,
      'preferred_language': preferredLanguage,
    };
  }

  UserProfile copyWith({
    List<String>? allergies,
    List<String>? dietaryRestrictions,
    List<String>? healthGoals,
    List<String>? avoidIngredients,
    String? preferredLanguage,
  }) {
    return UserProfile(
      allergies: allergies ?? this.allergies,
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      healthGoals: healthGoals ?? this.healthGoals,
      avoidIngredients: avoidIngredients ?? this.avoidIngredients,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }

  /// 프로필 요약 텍스트 (AI에게 전달용)
  String toPromptContext() {
    final parts = <String>[];

    if (allergies.isNotEmpty) {
      parts.add('알레르기: ${allergies.join(", ")}');
    }
    if (dietaryRestrictions.isNotEmpty) {
      parts.add('식이 제한: ${dietaryRestrictions.join(", ")}');
    }
    if (healthGoals.isNotEmpty) {
      parts.add('건강 목표: ${healthGoals.join(", ")}');
    }
    if (avoidIngredients.isNotEmpty) {
      parts.add('피해야 할 성분: ${avoidIngredients.join(", ")}');
    }

    return parts.isEmpty ? '' : '[사용자 프로필]\n${parts.join("\n")}';
  }

  bool get hasAnyPreference =>
      allergies.isNotEmpty ||
      dietaryRestrictions.isNotEmpty ||
      healthGoals.isNotEmpty ||
      avoidIngredients.isNotEmpty;
}

/// 사용 모드 정의
enum UseMode {
  menu('menu', '메뉴판', '식당 메뉴 읽기 & 추천', 'restaurant_menu', 0xFF10B981),
  kiosk('kiosk', '키오스크', '주문 도우미', 'touch_app', 0xFFF59E0B),
  grocery('grocery', '장보기', '건강한 쇼핑 도우미', 'shopping_cart', 0xFF3B82F6),
  product('product', '제품 정보', '성분 & 영양 분석', 'qr_code_scanner', 0xFF8B5CF6),
  general('general', '일반', '뭐든지 물어보세요', 'auto_awesome', 0xFFEC4899);

  final String id;
  final String name;
  final String description;
  final String iconName;
  final int color;

  const UseMode(this.id, this.name, this.description, this.iconName, this.color);
}

/// 알레르기 옵션
class AllergyOption {
  static const List<Map<String, String>> options = [
    {'id': 'nuts', 'name': '견과류', 'icon': '🥜'},
    {'id': 'dairy', 'name': '유제품', 'icon': '🥛'},
    {'id': 'eggs', 'name': '달걀', 'icon': '🥚'},
    {'id': 'gluten', 'name': '글루텐', 'icon': '🌾'},
    {'id': 'shellfish', 'name': '갑각류', 'icon': '🦐'},
    {'id': 'fish', 'name': '생선', 'icon': '🐟'},
    {'id': 'soy', 'name': '대두', 'icon': '🫘'},
    {'id': 'sesame', 'name': '참깨', 'icon': '🌱'},
  ];
}

/// 식이 제한 옵션
class DietaryOption {
  static const List<Map<String, String>> options = [
    {'id': 'vegetarian', 'name': '채식', 'icon': '🥗'},
    {'id': 'vegan', 'name': '비건', 'icon': '🌱'},
    {'id': 'halal', 'name': '할랄', 'icon': '☪️'},
    {'id': 'kosher', 'name': '코셔', 'icon': '✡️'},
    {'id': 'pescatarian', 'name': '페스코', 'icon': '🐟'},
    {'id': 'lactose_free', 'name': '유당불내증', 'icon': '🚫🥛'},
  ];
}

/// 건강 목표 옵션
class HealthGoalOption {
  static const List<Map<String, String>> options = [
    {'id': 'weight_loss', 'name': '다이어트', 'icon': '⚖️'},
    {'id': 'muscle_gain', 'name': '근육 증가', 'icon': '💪'},
    {'id': 'low_sodium', 'name': '저염식', 'icon': '🧂'},
    {'id': 'low_sugar', 'name': '저당', 'icon': '🍬'},
    {'id': 'high_protein', 'name': '고단백', 'icon': '🥩'},
    {'id': 'low_carb', 'name': '저탄수화물', 'icon': '🍞'},
    {'id': 'heart_healthy', 'name': '심장 건강', 'icon': '❤️'},
    {'id': 'diabetic_friendly', 'name': '당뇨 관리', 'icon': '💉'},
  ];
}
