// GlassKiosk Copilot - 홈 화면

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kiosk_provider.dart';
import 'camera_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _serverController = TextEditingController();
  bool _isConnected = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _serverController.text = 'http://localhost:8000';
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

    // 간단한 연결 테스트
    try {
      final response = await provider.checkServerConnection();
      setState(() {
        _isConnected = response;
        _isChecking = false;
      });

      if (_isConnected) {
        _showSnackBar('서버 연결 성공!', Colors.green);
      } else {
        _showSnackBar('서버에 연결할 수 없습니다', Colors.red);
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _isChecking = false;
      });
      _showSnackBar('연결 오류: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
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
      appBar: AppBar(
        title: const Text('GlassKiosk Copilot'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 로고 및 설명
              const Icon(
                Icons.assistant,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              const Text(
                'AI 키오스크 도우미',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '카메라로 키오스크를 비추면\nAI가 사용법을 안내해드립니다',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // 서버 URL 입력
              TextField(
                controller: _serverController,
                decoration: InputDecoration(
                  labelText: '서버 주소',
                  hintText: 'http://localhost:8000',
                  border: const OutlineInputBorder(),
                  suffixIcon: _isChecking
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: Icon(
                            _isConnected ? Icons.check_circle : Icons.refresh,
                            color: _isConnected ? Colors.green : null,
                          ),
                          onPressed: _checkConnection,
                        ),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),

              // 연결 테스트 버튼
              OutlinedButton.icon(
                onPressed: _isChecking ? null : _checkConnection,
                icon: const Icon(Icons.wifi),
                label: const Text('연결 테스트'),
              ),
              const Spacer(),

              // 시작 버튼
              ElevatedButton.icon(
                onPressed: _startCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('카메라 시작'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 16),

              // 도움말
              TextButton(
                onPressed: () => _showHelpDialog(),
                child: const Text('사용 방법 보기'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사용 방법'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. 카메라를 키오스크 화면에 비춰주세요'),
            SizedBox(height: 8),
            Text('2. 궁금한 메뉴를 손가락으로 가리키세요'),
            SizedBox(height: 8),
            Text('3. "이거 뭐야?" 라고 말하거나 버튼을 누르세요'),
            SizedBox(height: 8),
            Text('4. AI가 음성으로 안내해드립니다'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
