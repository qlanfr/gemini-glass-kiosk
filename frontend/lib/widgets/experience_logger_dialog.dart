// MenuMate - 음식 경험 기록 다이얼로그
// AI 응답 후 간단한 팝업으로 음식 경험을 기록

import 'package:flutter/material.dart';
import '../models/food_experience.dart';

/// 음식 경험 기록 결과
class ExperienceLogResult {
  final String foodName;
  final ExperienceType type;
  final int rating;

  ExperienceLogResult({
    required this.foodName,
    required this.type,
    required this.rating,
  });
}

/// 음식 경험 기록 다이얼로그
class ExperienceLoggerDialog extends StatefulWidget {
  final String foodName;

  const ExperienceLoggerDialog({
    super.key,
    required this.foodName,
  });

  /// 다이얼로그 표시
  static Future<ExperienceLogResult?> show(
    BuildContext context, {
    required String foodName,
  }) {
    return showModalBottomSheet<ExperienceLogResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExperienceLoggerDialog(foodName: foodName),
    );
  }

  @override
  State<ExperienceLoggerDialog> createState() => _ExperienceLoggerDialogState();
}

class _ExperienceLoggerDialogState extends State<ExperienceLoggerDialog> {
  ExperienceType? _selectedType;
  int _rating = 3;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // 타이틀
          Text(
            '"${widget.foodName}" 어땠어요?',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '다음에 더 좋은 추천을 위해 알려주세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),

          // 별점
          _buildRatingSelector(),
          const SizedBox(height: 24),

          // 경험 타입 선택
          _buildTypeSelector(),
          const SizedBox(height: 32),

          // 버튼들
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('건너뛰기'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _selectedType != null ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '저장하기',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildRatingSelector() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starIndex = index + 1;
            return GestureDetector(
              onTap: () => setState(() => _rating = starIndex),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  starIndex <= _rating ? Icons.star : Icons.star_border,
                  size: 40,
                  color: starIndex <= _rating
                      ? Colors.amber
                      : Colors.grey.shade300,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          _getRatingText(),
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  String _getRatingText() {
    switch (_rating) {
      case 1:
        return '별로예요';
      case 2:
        return '그냥 그래요';
      case 3:
        return '괜찮아요';
      case 4:
        return '맛있어요';
      case 5:
        return '최고예요!';
      default:
        return '';
    }
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        _buildTypeButton(
          type: ExperienceType.loved,
          emoji: '❤️',
          label: '좋아요',
          color: Colors.pink,
        ),
        const SizedBox(width: 12),
        _buildTypeButton(
          type: ExperienceType.disliked,
          emoji: '👎',
          label: '싫어요',
          color: Colors.grey,
        ),
        const SizedBox(width: 12),
        _buildTypeButton(
          type: ExperienceType.allergic,
          emoji: '⚠️',
          label: '알레르기',
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildTypeButton({
    required ExperienceType type,
    required String emoji,
    required String label,
    required Color color,
  }) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? color : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (_selectedType == null) return;

    Navigator.pop(
      context,
      ExperienceLogResult(
        foodName: widget.foodName,
        type: _selectedType!,
        rating: _rating,
      ),
    );
  }
}
