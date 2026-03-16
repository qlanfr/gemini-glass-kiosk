// GlassKiosk Copilot - 카메라 화면

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/kiosk_provider.dart';
import '../widgets/ar_overlay.dart';
import '../widgets/experience_logger_dialog.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    // 카메라 권한 요청
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _errorMessage = '카메라 권한이 필요합니다';
      });
      return;
    }

    // 사용 가능한 카메라 목록
    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) {
      setState(() {
        _errorMessage = '사용 가능한 카메라가 없습니다';
      });
      return;
    }

    // 후면 카메라 선택
    final camera = _cameras!.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );

    // 카메라 컨트롤러 초기화
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '카메라 초기화 실패: $e';
      });
    }
  }

  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // 이미지 캡처
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();

      // API 요청
      final provider = context.read<KioskProvider>();
      await provider.processImage(bytes, query: '이 화면을 분석해주세요');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _captureWithQuery(String query) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();

      final provider = context.read<KioskProvider>();
      await provider.processImage(bytes, query: query);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('키오스크 스캔'),
        actions: [
          // 설정 버튼
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeCamera,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('카메라 초기화 중...'),
          ],
        ),
      );
    }

    return Consumer<KioskProvider>(
      builder: (context, provider, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // 카메라 프리뷰
            CameraPreview(_cameraController!),

            // AR 오버레이
            if (provider.highlightCoordinates != null)
              ArOverlay(
                coordinates: provider.highlightCoordinates!,
                label: provider.lastResponse?.targetItem,
              ),

            // 처리 중 인디케이터
            if (_isProcessing || provider.state == KioskState.processing)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        '분석 중...',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),

            // 응답 메시지 표시
            if (provider.lastResponse != null &&
                provider.state == KioskState.success)
              Positioned(
                bottom: 100,
                left: 16,
                right: 16,
                child: _buildResponseCard(provider),
              ),
          ],
        );
      },
    );
  }

  Widget _buildResponseCard(KioskProvider provider) {
    final response = provider.lastResponse!;
    return Card(
      color: Colors.white.withOpacity(0.9),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (response.targetItem != null) ...[
              Text(
                response.targetItem!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(response.audioResponse),
            const SizedBox(height: 8),
            Row(
              children: [
                // TTS 재생 버튼
                IconButton(
                  icon: Icon(
                    provider.isSpeaking ? Icons.stop : Icons.volume_up,
                  ),
                  onPressed: () {
                    if (provider.isSpeaking) {
                      provider.stopSpeaking();
                    } else {
                      provider.speakResponse(
                        response.audioResponse,
                        response.detectedLanguage,
                      );
                    }
                  },
                ),
                const Spacer(),
                // 경험 기록 버튼
                if (response.targetItem != null)
                  TextButton.icon(
                    onPressed: () => _showExperienceLogger(
                      provider,
                      response.targetItem!,
                    ),
                    icon: const Icon(Icons.rate_review, size: 18),
                    label: const Text('평가'),
                  ),
                // 닫기 버튼
                TextButton(
                  onPressed: () => provider.reset(),
                  child: const Text('닫기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 음식 경험 기록 다이얼로그 표시
  Future<void> _showExperienceLogger(
    KioskProvider provider,
    String foodName,
  ) async {
    final result = await ExperienceLoggerDialog.show(
      context,
      foodName: foodName,
    );

    if (result != null) {
      await provider.addFoodExperience(
        foodName: result.foodName,
        type: result.type,
        rating: result.rating,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${result.foodName}" 경험이 저장되었습니다'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black87,
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 빠른 질문 버튼들
            _buildQuickButton('이거 뭐야?', Icons.help_outline),

            // 캡처 버튼
            GestureDetector(
              onTap: _isProcessing ? null : _captureAndAnalyze,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: _isProcessing ? Colors.grey : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Icon(
                  Icons.camera,
                  size: 40,
                  color: _isProcessing ? Colors.white : Colors.black,
                ),
              ),
            ),

            // 추천 질문
            _buildQuickButton('추천해줘', Icons.thumb_up_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton(String text, IconData icon) {
    return InkWell(
      onTap: _isProcessing ? null : () => _captureWithQuery(text),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('설정'),
        content: Consumer<KioskProvider>(
          builder: (context, provider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('감지된 언어'),
                  subtitle: Text(
                    provider.lastResponse?.detectedLanguage ?? '없음',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.wifi),
                  title: const Text('서버 주소'),
                  subtitle: Text(provider.serverUrl),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}
