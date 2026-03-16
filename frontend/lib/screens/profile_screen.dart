// MenuMate - 사용자 프로필 설정 화면

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../providers/kiosk_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          '내 프로필',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<KioskProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 프로필 헤더
                _buildProfileHeader(context, provider),
                const SizedBox(height: 24),

                // 알레르기 섹션
                _buildSection(
                  context,
                  title: '알레르기',
                  subtitle: '해당하는 알레르기를 선택하세요',
                  icon: Icons.warning_amber_rounded,
                  iconColor: Colors.orange,
                  child: _buildAllergyChips(provider),
                ),
                const SizedBox(height: 20),

                // 식이 제한 섹션
                _buildSection(
                  context,
                  title: '식이 제한',
                  subtitle: '식단 유형을 선택하세요',
                  icon: Icons.restaurant_menu,
                  iconColor: Colors.green,
                  child: _buildDietaryChips(provider),
                ),
                const SizedBox(height: 20),

                // 건강 목표 섹션
                _buildSection(
                  context,
                  title: '건강 목표',
                  subtitle: '목표에 맞는 추천을 받으세요',
                  icon: Icons.fitness_center,
                  iconColor: Colors.blue,
                  child: _buildHealthGoalChips(provider),
                ),
                const SizedBox(height: 32),

                // 프로필 요약
                if (provider.hasUserProfile) _buildProfileSummary(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, KioskProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '맞춤 프로필 설정',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  provider.hasUserProfile
                      ? '프로필이 설정되었습니다'
                      : '프로필을 설정해 맞춤 추천을 받으세요',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (provider.hasUserProfile)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    '설정됨',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildAllergyChips(KioskProvider provider) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AllergyOption.options.map((option) {
        final isSelected = provider.userProfile.allergies.contains(option['id']);
        return _buildSelectableChip(
          icon: option['icon']!,
          label: option['name']!,
          isSelected: isSelected,
          selectedColor: Colors.orange,
          onTap: () => provider.toggleAllergy(option['id']!),
        );
      }).toList(),
    );
  }

  Widget _buildDietaryChips(KioskProvider provider) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: DietaryOption.options.map((option) {
        final isSelected =
            provider.userProfile.dietaryRestrictions.contains(option['id']);
        return _buildSelectableChip(
          icon: option['icon']!,
          label: option['name']!,
          isSelected: isSelected,
          selectedColor: Colors.green,
          onTap: () => provider.toggleDietaryRestriction(option['id']!),
        );
      }).toList(),
    );
  }

  Widget _buildHealthGoalChips(KioskProvider provider) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: HealthGoalOption.options.map((option) {
        final isSelected =
            provider.userProfile.healthGoals.contains(option['id']);
        return _buildSelectableChip(
          icon: option['icon']!,
          label: option['name']!,
          isSelected: isSelected,
          selectedColor: Colors.blue,
          onTap: () => provider.toggleHealthGoal(option['id']!),
        );
      }).toList(),
    );
  }

  Widget _buildSelectableChip({
    required String icon,
    required String label,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? selectedColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? selectedColor : Colors.grey.shade700,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(Icons.check, size: 14, color: selectedColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSummary(KioskProvider provider) {
    final profile = provider.userProfile;
    final summaryItems = <String>[];

    if (profile.allergies.isNotEmpty) {
      final allergyNames = profile.allergies
          .map((id) => AllergyOption.options
              .firstWhere((o) => o['id'] == id, orElse: () => {'name': id})['name'])
          .join(', ');
      summaryItems.add('알레르기: $allergyNames');
    }

    if (profile.dietaryRestrictions.isNotEmpty) {
      final dietNames = profile.dietaryRestrictions
          .map((id) => DietaryOption.options
              .firstWhere((o) => o['id'] == id, orElse: () => {'name': id})['name'])
          .join(', ');
      summaryItems.add('식이 제한: $dietNames');
    }

    if (profile.healthGoals.isNotEmpty) {
      final goalNames = profile.healthGoals
          .map((id) => HealthGoalOption.options
              .firstWhere((o) => o['id'] == id, orElse: () => {'name': id})['name'])
          .join(', ');
      summaryItems.add('건강 목표: $goalNames');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize, color: Colors.indigo.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                '프로필 요약',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...summaryItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $item',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.indigo.shade800,
                  ),
                ),
              )),
          const SizedBox(height: 8),
          Text(
            'AI가 이 정보를 참고해 맞춤 추천을 제공합니다',
            style: TextStyle(
              fontSize: 11,
              color: Colors.indigo.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
