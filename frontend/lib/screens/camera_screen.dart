// GlassKiosk Copilot - 카메라 화면 (실시간 모드 지원)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/kiosk_provider.dart';
import '../models/kiosk_response.dart';
import '../services/api_service.dart';
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

  // 실시간 모드 관련
  bool _isLiveMode = false;
  bool _isLiveConnected = false;
  Timer? _frameTimer;
  final ApiService _apiService = ApiService();
  KioskResponse? _liveResponse;
  String? _liveError;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _stopLiveMode();
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
      ResolutionPreset.medium, // 실시간 모드를 위해 medium으로 변경
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

  // ===== 실시간 모드 =====

  void _toggleLiveMode() {
    if (_isLiveMode) {
      _stopLiveMode();
    } else {
      _startLiveMode();
    }
  }

  void _startLiveMode() {
    final provider = context.read<KioskProvider>();
    _apiService.setBaseUrl(provider.serverUrl);

    setState(() {
      _isLiveMode = true;
      _liveError = null;
      _liveResponse = null;
    });

    // WebSocket 연결
    _apiService.connectWebSocket(
      onResponse: (response) {
        setState(() {
          _liveResponse = response;
        });
        // TTS로 응답 읽기
        if (response.audioResponse.isNotEmpty) {
          provider.speakResponse(response.audioResponse, response.detectedLanguage);
        }
      },
      onError: (error) {
        setState(() {
          _liveError = error;
        });
      },
      onConnected: () {
        setState(() {
          _isLiveConnected = true;
        });
        _showSnackBar('실시간 연결됨', Colors.green);
        // 프레임 전송 시작 (초당 1프레임)
        _startFrameCapture();
      },
      onDisconnected: () {
        setState(() {
          _isLiveConnected = false;
          _isLiveMode = false;
        });
        _showSnackBar('연결 종료됨', Colors.orange);
      },
      promptId: provider.selectedPromptId,
    );
  }

  void _stopLiveMode() {
    _frameTimer?.cancel();
    _frameTimer = null;
    _apiService.disconnectWebSocket();
    setState(() {
      _isLiveMode = false;
      _isLiveConnected = false;
      _liveResponse = null;
      _liveError = null;
    });
  }

  void _startFrameCapture() {
    // 1초마다 프레임 캡처 및 전송
    _frameTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) async {
      if (!_isLiveConnected || _cameraController == null) return;

      try {
        final image = await _cameraController!.takePicture();
        final bytes = await image.readAsBytes();
        _apiService.sendImageFrame(bytes);
      } catch (e) {
        // 프레임 캡처 실패 시 무시
      }
    });
  }

  void _sendVoiceQuery(String query) {
    if (!_isLiveConnected) return;
    _apiService.sendTextMessage(query);
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ===== 일반 모드 (사진 촬영) =====

  Future<void> _captureAndAnalyze() async {
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
    if (_isLiveMode) {
      // 실시간 모드에서는 텍스트만 전송
      _sendVoiceQuery(query);
      return;
    }

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
        title: Text(_isLiveMode ? '실시간 모드' : '키오스크 스캔'),
        backgroundColor: _isLiveMode ? Colors.red.shade700 : null,
        actions: [
          // 실시간 모드 토글
          IconButton(
            icon: Icon(
              _isLiveMode ? Icons.videocam : Icons.videocam_outlined,
              color: _isLiveMode ? Colors.white : null,
            ),
            onPressed: _isInitialized ? _toggleLiveMode : null,
            tooltip: _isLiveMode ? '실시간 모드 끄기' : '실시간 모드',
          ),
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

            // 실시간 모드 표시
            if (_isLiveMode)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isLiveConnected ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isLiveConnected ? Icons.fiber_manual_record : Icons.sync,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isLiveConnected ? 'LIVE' : '연결 중...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // AR 오버레이 (일반 모드)
            if (!_isLiveMode && provider.highlightCoordinates != null)
              ArOverlay(
                coordinates: provider.highlightCoordinates!,
                label: provider.lastResponse?.targetItem,
              ),

            // AR 오버레이 (실시간 모드)
            if (_isLiveMode && _liveResponse?.coordinates != null)
              ArOverlay(
                coordinates: _liveResponse!.coordinates!,
                label: _liveResponse?.targetItem,
              ),

            // 처리 중 인디케이터 (일반 모드)
            if (!_isLiveMode && (_isProcessing || provider.state == KioskState.processing))
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

            // 실시간 에러 표시
            if (_isLiveMode && _liveError != null)
              Positioned(
                top: 60,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _liveError!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),

            // 응답 메시지 표시 (일반 모드)
            if (!_isLiveMode &&
                provider.lastResponse != null &&
                provider.state == KioskState.success)
              Positioned(
                bottom: 100,
                left: 16,
                right: 16,
                child: _buildResponseCard(provider),
              ),

            // 응답 메시지 표시 (실시간 모드)
            if (_isLiveMode && _liveResponse != null)
              Positioned(
                bottom: 100,
                left: 16,
                right: 16,
                child: _buildLiveResponseCard(),
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
                if (response.targetItem != null)
                  TextButton.icon(
                    onPressed: () => _showExperienceLogger(
                      provider,
                      response.targetItem!,
                    ),
                    icon: const Icon(Icons.rate_review, size: 18),
                    label: const Text('평가'),
                  ),
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

  Widget _buildLiveResponseCard() {
    return Card(
      color: Colors.white.withValues(alpha: 0.95),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_liveResponse?.targetItem != null)
                  Expanded(
                    child: Text(
                      _liveResponse!.targetItem!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _liveResponse!.audioResponse,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

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
      color: _isLiveMode ? Colors.red.shade900 : Colors.black87,
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 빠른 질문 버튼들
            _buildQuickButton('이거 뭐야?', Icons.help_outline),

            // 캡처/실시간 토글 버튼
            GestureDetector(
              onTap: _isLiveMode
                  ? _toggleLiveMode
                  : (_isProcessing ? null : _captureAndAnalyze),
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: _isLiveMode
                      ? Colors.white
                      : (_isProcessing ? Colors.grey : Colors.white),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isLiveMode ? Colors.red : Colors.white,
                    width: 3,
                  ),
                ),
                child: Icon(
                  _isLiveMode ? Icons.stop : Icons.camera,
                  size: 40,
                  color: _isLiveMode
                      ? Colors.red
                      : (_isProcessing ? Colors.white : Colors.black),
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
                SwitchListTile(
                  title: const Text('실시간 모드'),
                  subtitle: Text(_isLiveMode ? '켜짐' : '꺼짐'),
                  value: _isLiveMode,
                  onChanged: (_) {
                    Navigator.pop(context);
                    _toggleLiveMode();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('감지된 언어'),
                  subtitle: Text(
                    _isLiveMode
                        ? (_liveResponse?.detectedLanguage ?? '없음')
                        : (provider.lastResponse?.detectedLanguage ?? '없음'),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.wifi),
                  title: const Text('서버 주소'),
                  subtitle: Text(provider.serverUrl),
                ),
                if (_isLiveMode)
                  ListTile(
                    leading: Icon(
                      _isLiveConnected ? Icons.check_circle : Icons.error,
                      color: _isLiveConnected ? Colors.green : Colors.red,
                    ),
                    title: const Text('WebSocket 상태'),
                    subtitle: Text(_isLiveConnected ? '연결됨' : '연결 안됨'),
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
