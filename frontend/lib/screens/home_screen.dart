// MenuMate - 홈 화면

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kiosk_provider.dart';
import '../models/prompt_info.dart';
import '../models/user_profile.dart';
import 'camera_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _serverController = TextEditingController();
  bool _isConnected = false;
  bool _isChecking = false;
  bool _showServerSettings = false;

  @override
  void initState() {
    super.initState();
    _serverController.text = 'http://localhost:8000';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<KioskProvider>();
      provider.loadPrompts();
      provider.loadProfileFromStorage();
      // 앱 시작시 자동으로 서버 감지
      await _autoDetectServer();
    });
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    setState(() => _isChecking = true);

    final provider = context.read<KioskProvider>();
    provider.setServerUrl(_serverController.text);

    try {
      final response = await provider.checkServerConnection();
      setState(() {
        _isConnected = response;
        _isChecking = false;
      });

      if (_isConnected) {
        _showSnackBar('서버 연결 성공!', const Color(0xFF10B981));
        // 연결 성공 시 프롬프트 다시 로드
        provider.loadPrompts();
      } else {
        _showSnackBar('서버에 연결할 수 없습니다', const Color(0xFFEF4444));
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _isChecking = false;
      });
      _showSnackBar('연결 오류', const Color(0xFFEF4444));
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startCamera() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CameraScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5F3FF), // Light purple
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // 프로필 버튼
                _buildProfileButton(),
                const SizedBox(height: 24),

                // 로고 & 타이틀
                _buildHeader(),
                const SizedBox(height: 32),

                // 모드 선택
                _buildModeSelector(),
                const SizedBox(height: 24),

                // AI 어시스턴트 선택
                _buildAssistantSelector(),
                const SizedBox(height: 24),

                // 서버 설정 (접이식)
                _buildServerSettings(),
                const SizedBox(height: 32),

                // 시작 버튼
                _buildStartButton(),
                const SizedBox(height: 16),

                // 도움말
                Center(
                  child: TextButton.icon(
                    onPressed: _showHelpDialog,
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: const Text('사용 방법'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileButton() {
    return Consumer<KioskProvider>(
      builder: (context, provider, _) {
        return Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: provider.hasUserProfile
                    ? const Color(0xFF6366F1).withOpacity(0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: provider.hasUserProfile
                      ? const Color(0xFF6366F1).withOpacity(0.3)
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    provider.hasUserProfile ? Icons.person : Icons.person_outline,
                    size: 18,
                    color: provider.hasUserProfile
                        ? const Color(0xFF6366F1)
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    provider.hasUserProfile ? '내 프로필' : '프로필 설정',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: provider.hasUserProfile
                          ? const Color(0xFF6366F1)
                          : Colors.grey.shade600,
                    ),
                  ),
                  if (provider.hasUserProfile) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Consumer<KioskProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            // 로고 아이콘
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(provider.currentMode.color),
                    Color(provider.currentMode.color).withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Color(provider.currentMode.color).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                _getModeIcon(provider.currentMode),
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // 앱 이름
            const Text(
              'MenuMate',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),

            // 현재 모드 설명
            Text(
              provider.currentMode.description,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }

  IconData _getModeIcon(UseMode mode) {
    switch (mode) {
      case UseMode.menu:
        return Icons.restaurant_menu;
      case UseMode.kiosk:
        return Icons.touch_app;
      case UseMode.grocery:
        return Icons.shopping_cart;
      case UseMode.product:
        return Icons.qr_code_scanner;
      case UseMode.general:
        return Icons.auto_awesome;
    }
  }

  Widget _buildModeSelector() {
    return Consumer<KioskProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.apps, size: 20, color: Color(0xFF6366F1)),
                SizedBox(width: 8),
                Text(
                  '무엇을 도와드릴까요?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: UseMode.values.map((mode) {
                final isSelected = provider.currentMode == mode;
                return _buildModeChip(mode, isSelected, provider);
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModeChip(UseMode mode, bool isSelected, KioskProvider provider) {
    final color = Color(mode.color);
    return GestureDetector(
      onTap: () => provider.setMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getModeIcon(mode),
              size: 20,
              color: isSelected ? color : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mode.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? color : Colors.grey.shade700,
                  ),
                ),
                Text(
                  mode.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? color.withOpacity(0.8) : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle, size: 16, color: color),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantSelector() {
    return Consumer<KioskProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingPrompts) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (provider.availablePrompts.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '서버에 연결하면 AI 어시스턴트를 선택할 수 있어요',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.smart_toy, size: 20, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                const Text(
                  'AI 어시스턴트',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                if (provider.selectedPrompt != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      provider.selectedPrompt!.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: provider.availablePrompts.length,
                itemBuilder: (context, index) {
                  final prompt = provider.availablePrompts[index];
                  final isSelected = prompt.id == provider.selectedPromptId;
                  return _buildPromptCard(prompt, isSelected, provider);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPromptCard(PromptInfo prompt, bool isSelected, KioskProvider provider) {
    return GestureDetector(
      onTap: () => provider.selectPrompt(prompt.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              prompt.icon,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 6),
            Text(
              prompt.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF374151),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              prompt.languageDisplay,
              style: TextStyle(
                fontSize: 9,
                color: isSelected ? Colors.white70 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerSettings() {
    return Consumer<KioskProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            // 서버 타입 선택 (Cloud Run / Local)
            Row(
              children: [
                Expanded(
                  child: _buildServerTypeButton(
                    icon: Icons.cloud,
                    label: 'Cloud Run',
                    isSelected: provider.isUsingCloudRun,
                    onTap: () async {
                      setState(() => _isChecking = true);
                      await provider.useCloudRun();
                      _serverController.text = provider.serverUrl;
                      await _checkConnection();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildServerTypeButton(
                    icon: Icons.computer,
                    label: '로컬 서버',
                    isSelected: !provider.isUsingCloudRun,
                    onTap: () {
                      provider.useLocalServer();
                      _serverController.text = provider.serverUrl;
                      _checkConnection();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // 자동 감지 버튼
                IconButton(
                  onPressed: _autoDetectServer,
                  icon: const Icon(Icons.auto_fix_high),
                  tooltip: '자동 감지',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 토글 버튼
            InkWell(
              onTap: () => setState(() => _showServerSettings = !_showServerSettings),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      provider.isUsingCloudRun ? Icons.cloud_done : Icons.dns,
                      size: 18,
                      color: _isConnected ? const Color(0xFF10B981) : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        provider.isUsingCloudRun ? 'Cloud Run' : '로컬 서버',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // 연결 상태 표시
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isConnected ? const Color(0xFF10B981) : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _showServerSettings ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            ),

            // 설정 내용 (접이식)
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    TextField(
                      controller: _serverController,
                      decoration: InputDecoration(
                        hintText: provider.serverUrl,
                        prefixIcon: const Icon(Icons.link, size: 20),
                        suffixIcon: _isChecking
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                icon: Icon(
                                  _isConnected ? Icons.check_circle : Icons.refresh,
                                  color: _isConnected ? const Color(0xFF10B981) : null,
                                ),
                                onPressed: _checkConnection,
                              ),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isChecking ? null : _checkConnection,
                        icon: const Icon(Icons.wifi, size: 18),
                        label: const Text('연결 테스트'),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: _showServerSettings
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        );
      },
    );
  }

  Widget _buildServerTypeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _autoDetectServer() async {
    setState(() => _isChecking = true);
    _showSnackBar('서버 자동 감지 중...', Colors.blue);

    final provider = context.read<KioskProvider>();
    await provider.autoDetectServer();

    _serverController.text = provider.serverUrl;
    final connected = await provider.checkServerConnection();

    setState(() {
      _isConnected = connected;
      _isChecking = false;
    });

    if (connected) {
      _showSnackBar(
        provider.isUsingCloudRun ? 'Cloud Run 연결됨!' : '로컬 서버 연결됨!',
        const Color(0xFF10B981),
      );
    } else {
      _showSnackBar('서버를 찾을 수 없습니다', const Color(0xFFEF4444));
    }
  }

  Widget _buildStartButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _startCamera,
        icon: const Icon(Icons.camera_alt, size: 24),
        label: const Text(
          '카메라로 시작하기',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 핸들
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              '사용 방법',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            _buildHelpItem(
              number: '1',
              icon: Icons.camera_alt,
              title: '카메라로 비추기',
              description: '메뉴판이나 키오스크 화면을 카메라로 비춰주세요',
            ),
            _buildHelpItem(
              number: '2',
              icon: Icons.touch_app,
              title: '메뉴 가리키기',
              description: '궁금한 메뉴를 손가락으로 가리키세요',
            ),
            _buildHelpItem(
              number: '3',
              icon: Icons.mic,
              title: '질문하기',
              description: '"이거 뭐야?", "추천해줘" 등 음성으로 물어보세요',
            ),
            _buildHelpItem(
              number: '4',
              icon: Icons.volume_up,
              title: '안내 듣기',
              description: 'AI가 친절하게 음성으로 안내해드려요',
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem({
    required String number,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: const Color(0xFF6366F1)),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
