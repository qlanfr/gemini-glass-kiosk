// MenuMate - RAG (Retrieval-Augmented Generation) Service
// 사용자의 음식 경험을 저장하고 검색하여 AI 프롬프트에 컨텍스트 제공

import 'package:hive_flutter/hive_flutter.dart';
import '../models/food_experience.dart';
import '../models/user_profile.dart';

/// RAG 검색 결과
class RAGContext {
  final List<FoodExperience> experiences;
  final List<String> warnings;
  final String? targetItem;

  RAGContext({
    required this.experiences,
    required this.warnings,
    this.targetItem,
  });

  /// AI 프롬프트용 컨텍스트 문자열 생성
  String toPromptContext(UserProfile profile) {
    final buffer = StringBuffer();

    // 1. 사용자 프로필
    if (profile.hasAnyPreference) {
      buffer.writeln('[사용자 프로필]');
      buffer.writeln(profile.toPromptContext());
      buffer.writeln();
    }

    // 2. 경고 (알레르기 등)
    if (warnings.isNotEmpty) {
      buffer.writeln('[주의사항]');
      for (final warning in warnings) {
        buffer.writeln(warning);
      }
      buffer.writeln();
    }

    // 3. 이전 경험
    if (experiences.isNotEmpty) {
      buffer.writeln('[이전 음식 경험]');
      for (final exp in experiences) {
        buffer.writeln(exp.toPromptText());
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  bool get hasContext =>
      experiences.isNotEmpty || warnings.isNotEmpty;
}

/// RAG 서비스 - 음식 경험 저장 및 검색
class RAGService {
  static const String _boxName = 'food_experiences';
  late Box<Map> _box;
  bool _isInitialized = false;

  /// 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;
    _box = await Hive.openBox<Map>(_boxName);
    _isInitialized = true;
  }

  /// 모든 경험 가져오기
  List<FoodExperience> getAllExperiences() {
    return _box.values
        .map((json) => FoodExperience.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// 경험 추가
  Future<void> addExperience(FoodExperience experience) async {
    await _box.put(experience.id, experience.toJson());
  }

  /// 경험 삭제
  Future<void> deleteExperience(String id) async {
    await _box.delete(id);
  }

  /// 이름으로 경험 검색 (정확히 일치)
  List<FoodExperience> findByName(String foodName) {
    return getAllExperiences()
        .where((exp) => exp.foodName.toLowerCase() == foodName.toLowerCase())
        .toList();
  }

  /// 이름에 포함된 경험 검색 (부분 일치)
  List<FoodExperience> findByNameContains(String keyword) {
    final lowerKeyword = keyword.toLowerCase();
    return getAllExperiences()
        .where((exp) => exp.foodName.toLowerCase().contains(lowerKeyword))
        .toList();
  }

  /// 알레르기 경험만 가져오기
  List<FoodExperience> getAllAllergyExperiences() {
    return getAllExperiences()
        .where((exp) => exp.type == ExperienceType.allergic)
        .toList();
  }

  /// RAG 컨텍스트 검색
  /// [targetItem]: AI가 인식한 음식 이름
  Future<RAGContext> retrieveContext({
    String? targetItem,
    int maxResults = 5,
  }) async {
    await initialize();

    final experiences = <FoodExperience>[];
    final warnings = <String>[];

    // 1. 알레르기 경험 확인 (항상 체크 - 안전 최우선)
    final allergyExperiences = getAllAllergyExperiences();
    for (final exp in allergyExperiences) {
      // 타겟 아이템과 알레르기 음식이 관련 있는지 확인
      if (targetItem != null && _isRelated(targetItem, exp.foodName)) {
        warnings.add(exp.warningMessage!);
      }
      // 알레르기 경험은 우선적으로 포함
      if (!experiences.contains(exp)) {
        experiences.add(exp);
      }
    }

    // 2. 타겟 아이템과 정확히 일치하는 경험
    if (targetItem != null) {
      final exactMatches = findByName(targetItem);
      for (final exp in exactMatches) {
        if (!experiences.contains(exp)) {
          experiences.add(exp);
        }
      }

      // 3. 부분 일치하는 경험
      final partialMatches = findByNameContains(targetItem);
      for (final exp in partialMatches) {
        if (!experiences.contains(exp) && experiences.length < maxResults) {
          experiences.add(exp);
        }
      }
    }

    // 4. 최근 경험 추가 (컨텍스트 보충)
    if (experiences.length < maxResults) {
      final allExperiences = getAllExperiences();
      allExperiences.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      for (final exp in allExperiences) {
        if (!experiences.contains(exp) && experiences.length < maxResults) {
          experiences.add(exp);
        }
      }
    }

    // 우선순위로 정렬 (알레르기 > 싫어요 > 좋아요)
    experiences.sort((a, b) => b.priority.compareTo(a.priority));

    return RAGContext(
      experiences: experiences.take(maxResults).toList(),
      warnings: warnings,
      targetItem: targetItem,
    );
  }

  /// 두 음식 이름이 관련 있는지 확인
  bool _isRelated(String item1, String item2) {
    final lower1 = item1.toLowerCase();
    final lower2 = item2.toLowerCase();

    // 정확히 일치
    if (lower1 == lower2) return true;

    // 포함 관계
    if (lower1.contains(lower2) || lower2.contains(lower1)) return true;

    // 공통 키워드 (예: "새우버거"와 "새우튀김" → "새우")
    final words1 = _extractKeywords(lower1);
    final words2 = _extractKeywords(lower2);

    for (final w1 in words1) {
      for (final w2 in words2) {
        if (w1 == w2 && w1.length >= 2) return true;
      }
    }

    return false;
  }

  /// 음식 이름에서 키워드 추출
  List<String> _extractKeywords(String name) {
    // 한글 및 영문 단어 추출
    final regex = RegExp(r'[가-힣]+|[a-zA-Z]+');
    return regex.allMatches(name).map((m) => m.group(0)!).toList();
  }

  /// 경험 통계
  Map<String, int> getStats() {
    final all = getAllExperiences();
    return {
      'total': all.length,
      'loved': all.where((e) => e.type == ExperienceType.loved).length,
      'disliked': all.where((e) => e.type == ExperienceType.disliked).length,
      'allergic': all.where((e) => e.type == ExperienceType.allergic).length,
    };
  }

  /// 데이터 초기화 (테스트/디버그용)
  Future<void> clearAll() async {
    await _box.clear();
  }
}
