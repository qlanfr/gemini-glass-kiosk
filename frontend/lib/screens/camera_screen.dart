// GlassKiosk Copilot - 카메라 화면 (실시간 모드 + 음성 입력)

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../providers/kiosk_provider.dart';
import '../models/kiosk_response.dart';
import '../models/app_settings.dart';
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

  // 음성 녹음 관련
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  double _audioLevel = 0.0; // 0.0 ~ 1.0

  // 카메라 줌
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 5.0;

  // 터치 선택
  Offset? _touchPoint;
  bool _showTouchIndicator = false;

  // 연속 대화 상태
  bool _isAiReady = true; // AI가 입력을 받을 준비 상태

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _stopLiveMode();
    _cameraController?.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    // 카메라 권한 요청
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      setState(() {
        _errorMessage = '카메라 권한이 필요합니다';
      });
      return;
    }

    // 마이크 권한 요청
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      _showSnackBar('마이크 권한이 없으면 음성 입력이 불가합니다', Colors.orange);
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
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();

      // 줌 범위 설정
      _minZoom = await _cameraController!.getMinZoomLevel();
      _maxZoom = await _cameraController!.getMaxZoomLevel();
      _currentZoom = _minZoom;

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '카메라 초기화 실패: $e';
      });
    }
  }

  // 줌 변경
  Future<void> _setZoom(double zoom) async {
    if (_cameraController == null) return;
    final clampedZoom = zoom.clamp(_minZoom, _maxZoom);
    await _cameraController!.setZoomLevel(clampedZoom);
    setState(() {
      _currentZoom = clampedZoom;
    });
  }

  // 터치로 물체 선택
  void _onTapToSelect(TapDownDetails details, Size previewSize) {
    if (!_isLiveConnected) return;

    final provider = context.read<KioskProvider>();
    final x = details.localPosition.dx;
    final y = details.localPosition.dy;

    // 화면 비율로 좌표 계산
    final normalizedX = (x / previewSize.width * 100).round();
    final normalizedY = (y / previewSize.height * 100).round();

    setState(() {
      _touchPoint = details.localPosition;
      _showTouchIndicator = true;
    });

    // 터치 위치 정보와 함께 질문 전송
    final query = provider.language == AppLanguage.korean
        ? '화면에서 x:$normalizedX%, y:$normalizedY% 위치에 있는 것이 뭐야?'
        : 'What is at position x:$normalizedX%, y:$normalizedY% on screen?';
    _apiService.sendTextMessage(query);

    // 2초 후 터치 인디케이터 숨김
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showTouchIndicator = false;
        });
      }
    });
  }

  // ===== 실시간 모드 =====

  void _toggleLiveMode() {
    if (_isLiveMode) {
      _stopLiveMode();
    } else {
      _startLiveMode();
    }
  }

  void _startLiveMode() async {
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
          _isAiReady = false; // AI가 응답 중
        });
        // TTS로 응답 읽기 (설정에 따라)
        if (response.audioResponse.isNotEmpty && provider.enableTTS) {
          provider.speakResponse(response.audioResponse, response.detectedLanguage);
        }
      },
      onError: (error) {
        setState(() {
          _liveError = error;
          _isAiReady = true;
        });
      },
      onConnected: () {
        setState(() {
          _isLiveConnected = true;
          _isAiReady = true;
        });
        _showSnackBar(provider.str(StringKey.connected), Colors.green);
        // 프레임 전송 시작
        _startFrameCapture();
        // 음성 녹음 시작
        _startAudioRecording();
      },
      onDisconnected: () {
        setState(() {
          _isLiveConnected = false;
          _isLiveMode = false;
          _isAiReady = true;
        });
        _showSnackBar(provider.str(StringKey.disconnected), Colors.orange);
        _stopAudioRecording();
      },
      onTurnComplete: () {
        // AI가 응답 완료 - 다시 입력 받을 준비됨
        setState(() {
          _isAiReady = true;
        });
      },
      onTranscription: (text) {
        // 사용자 음성 인식 결과 표시 (선택적)
        if (text.isNotEmpty) {
          _showSnackBar('🎤 $text', Colors.blue.shade700);
        }
      },
      promptId: provider.selectedPromptId,
    );
  }

  void _stopLiveMode() {
    _frameTimer?.cancel();
    _frameTimer = null;
    _stopAudioRecording();
    _apiService.disconnectWebSocket();
    setState(() {
      _isLiveMode = false;
      _isLiveConnected = false;
      _liveResponse = null;
      _liveError = null;
    });
  }

  void _startFrameCapture() {
    // 2초마다 프레임 캡처 및 전송 (음성과 병행하므로 줄임)
    _frameTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) async {
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

  // ===== 음성 녹음 =====

  Future<void> _startAudioRecording() async {
    if (_isRecording) return;

    // 마이크 권한 확인
    if (!await _audioRecorder.hasPermission()) {
      _showSnackBar('마이크 권한이 필요합니다', Colors.red);
      return;
    }

    try {
      // PCM 16kHz 스트림 녹음 시작
      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _audioStreamSubscription = stream.listen((data) {
        // 오디오 레벨 계산 (간단한 RMS)
        if (data.isNotEmpty) {
          double sum = 0;
          for (int i = 0; i < data.length; i += 2) {
            if (i + 1 < data.length) {
              int sample = (data[i + 1] << 8) | data[i];
              if (sample > 32767) sample -= 65536;
              sum += sample * sample;
            }
          }
          double rms = sum / (data.length / 2);
          double level = (rms / 32768 / 32768).clamp(0.0, 1.0);
          setState(() {
            _audioLevel = level * 10; // 증폭
            if (_audioLevel > 1.0) _audioLevel = 1.0;
          });
        }

        // 오디오 데이터를 서버로 전송
        if (_isLiveConnected) {
          _apiService.sendAudioData(data);
        }
      });

      setState(() {
        _isRecording = true;
      });

      _showSnackBar('음성 입력 시작', Colors.blue);
    } catch (e) {
      _showSnackBar('녹음 시작 실패: $e', Colors.red);
    }
  }

  Future<void> _stopAudioRecording() async {
    if (!_isRecording) return;

    try {
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
      });
    } catch (e) {
      // 무시
    }
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
            // 카메라 프리뷰 (터치로 물체 선택 가능)
            LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (details) => _onTapToSelect(
                    details,
                    Size(constraints.maxWidth, constraints.maxHeight),
                  ),
                  onScaleUpdate: (details) {
                    // 핀치 줌
                    if (details.scale != 1.0) {
                      final newZoom = _currentZoom * details.scale;
                      _setZoom(newZoom);
                    }
                  },
                  child: CameraPreview(_cameraController!),
                );
              },
            ),

            // 터치 인디케이터
            if (_showTouchIndicator && _touchPoint != null)
              Positioned(
                left: _touchPoint!.dx - 30,
                top: _touchPoint!.dy - 30,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.yellow, width: 3),
                    color: Colors.yellow.withValues(alpha: 0.2),
                  ),
                  child: const Icon(Icons.touch_app, color: Colors.yellow),
                ),
              ),

            // 실시간 모드 표시
            if (_isLiveMode)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    // LIVE 배지
                    Container(
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
                            _isLiveConnected ? 'LIVE' : provider.str(StringKey.connecting),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // AI 준비 상태 표시
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isAiReady ? Colors.green : Colors.purple,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isAiReady ? Icons.hearing : Icons.record_voice_over,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isAiReady
                                ? (provider.language == AppLanguage.korean ? '듣는 중' : 'Listening')
                                : (provider.language == AppLanguage.korean ? '말하는 중' : 'Speaking'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 마이크 상태 + 레벨 표시
                    if (_isRecording)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _audioLevel > 0.1 ? Colors.green : Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _audioLevel > 0.1 ? Icons.mic : Icons.mic_none,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            // 오디오 레벨 바
                            Container(
                              width: 40,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _audioLevel,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

            // 줌 슬라이더
            Positioned(
              right: 16,
              top: 80,
              bottom: 200,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, color: Colors.white, size: 20),
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white38,
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: _currentZoom,
                          min: _minZoom,
                          max: _maxZoom,
                          onChanged: (value) => _setZoom(value),
                        ),
                      ),
                    ),
                  ),
                  const Icon(Icons.remove, color: Colors.white, size: 20),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentZoom.toStringAsFixed(1)}x',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
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
                    color: Colors.red.withValues(alpha: 0.9),
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

            // 응답 메시지 표시 (실시간 모드) - 설정에 따라
            if (_isLiveMode && _liveResponse != null && provider.showResponseText)
              Positioned(
                bottom: 100,
                left: 16,
                right: 16,
                child: _buildLiveResponseCard(provider),
              ),
          ],
        );
      },
    );
  }

  Widget _buildResponseCard(KioskProvider provider) {
    final response = provider.lastResponse!;
    return Card(
      color: Colors.white.withValues(alpha: 0.9),
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

  Widget _buildLiveResponseCard(KioskProvider provider) {
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.read<KioskProvider>().str(StringKey.settings)),
          content: Consumer<KioskProvider>(
            builder: (context, provider, child) {
              final isKorean = provider.language == AppLanguage.korean;
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 언어 설정
                    ListTile(
                      leading: const Icon(Icons.language),
                      title: Text(provider.str(StringKey.language)),
                      trailing: DropdownButton<AppLanguage>(
                        value: provider.language,
                        underline: const SizedBox(),
                        items: AppLanguage.values.map((lang) {
                          return DropdownMenuItem(
                            value: lang,
                            child: Text(lang.displayName),
                          );
                        }).toList(),
                        onChanged: (lang) {
                          if (lang != null) {
                            provider.setLanguage(lang);
                            setDialogState(() {});
                          }
                        },
                      ),
                    ),
                    const Divider(),

                    // 응답 텍스트 표시
                    SwitchListTile(
                      title: Text(provider.str(StringKey.showResponseText)),
                      subtitle: Text(isKorean
                          ? '화면에 AI 응답 텍스트 표시'
                          : 'Show AI response text on screen'),
                      value: provider.showResponseText,
                      onChanged: (_) {
                        provider.toggleShowResponseText();
                        setDialogState(() {});
                      },
                    ),

                    // TTS 설정
                    SwitchListTile(
                      title: Text(provider.str(StringKey.enableTTS)),
                      subtitle: Text(isKorean
                          ? 'AI 응답을 음성으로 읽기'
                          : 'Read AI response aloud'),
                      value: provider.enableTTS,
                      onChanged: (_) {
                        provider.toggleEnableTTS();
                        setDialogState(() {});
                      },
                    ),
                    const Divider(),

                    // 실시간 모드
                    SwitchListTile(
                      title: Text(provider.str(StringKey.liveMode)),
                      subtitle: Text(_isLiveMode
                          ? (isKorean ? '켜짐' : 'On')
                          : (isKorean ? '꺼짐' : 'Off')),
                      value: _isLiveMode,
                      onChanged: (_) {
                        Navigator.pop(context);
                        _toggleLiveMode();
                      },
                    ),

                    // 마이크 상태
                    ListTile(
                      leading: Icon(
                        _isRecording ? Icons.mic : Icons.mic_off,
                        color: _isRecording ? Colors.blue : Colors.grey,
                      ),
                      title: Text(isKorean ? '음성 입력' : 'Voice Input'),
                      subtitle: Text(_isRecording
                          ? (isKorean ? '녹음 중' : 'Recording')
                          : (isKorean ? '대기' : 'Standby')),
                    ),

                    // 카메라 줌
                    ListTile(
                      leading: const Icon(Icons.zoom_in),
                      title: Text(provider.str(StringKey.cameraZoom)),
                      subtitle: Slider(
                        value: _currentZoom,
                        min: _minZoom,
                        max: _maxZoom,
                        divisions: 20,
                        label: '${_currentZoom.toStringAsFixed(1)}x',
                        onChanged: (value) {
                          _setZoom(value);
                          setDialogState(() {});
                        },
                      ),
                    ),
                    const Divider(),

                    // 서버 상태
                    ListTile(
                      leading: const Icon(Icons.wifi),
                      title: Text(isKorean ? '서버 주소' : 'Server URL'),
                      subtitle: Text(provider.serverUrl),
                    ),
                    if (_isLiveMode)
                      ListTile(
                        leading: Icon(
                          _isLiveConnected ? Icons.check_circle : Icons.error,
                          color: _isLiveConnected ? Colors.green : Colors.red,
                        ),
                        title: Text(isKorean ? 'WebSocket 상태' : 'WebSocket Status'),
                        subtitle: Text(_isLiveConnected
                            ? (isKorean ? '연결됨' : 'Connected')
                            : (isKorean ? '연결 안됨' : 'Disconnected')),
                      ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.read<KioskProvider>().str(StringKey.close)),
            ),
          ],
        ),
      ),
    );
  }
}
