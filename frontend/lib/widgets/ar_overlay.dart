// GlassKiosk Copilot - AR 오버레이 위젯
// 좌표 기반 하이라이트 박스 렌더링

import 'package:flutter/material.dart';
import '../models/kiosk_response.dart';

class ArOverlay extends StatefulWidget {
  final Coordinates coordinates;
  final String? label;
  final Color highlightColor;
  final double strokeWidth;

  const ArOverlay({
    super.key,
    required this.coordinates,
    this.label,
    this.highlightColor = Colors.green,
    this.strokeWidth = 3.0,
  });

  @override
  State<ArOverlay> createState() => _ArOverlayState();
}

class _ArOverlayState extends State<ArOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: HighlightPainter(
            coordinates: widget.coordinates,
            color: widget.highlightColor.withOpacity(_animation.value),
            strokeWidth: widget.strokeWidth,
            label: widget.label,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class HighlightPainter extends CustomPainter {
  final Coordinates coordinates;
  final Color color;
  final double strokeWidth;
  final String? label;

  HighlightPainter({
    required this.coordinates,
    required this.color,
    required this.strokeWidth,
    this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // 하이라이트 박스
    final rect = Rect.fromLTWH(
      coordinates.x.toDouble(),
      coordinates.y.toDouble(),
      coordinates.width.toDouble(),
      coordinates.height.toDouble(),
    );

    // 둥근 모서리 박스
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, paint);

    // 코너 강조
    _drawCorners(canvas, rect, paint);

    // 라벨 표시
    if (label != null && label!.isNotEmpty) {
      _drawLabel(canvas, rect);
    }
  }

  void _drawCorners(Canvas canvas, Rect rect, Paint paint) {
    final cornerLength = 15.0;
    final cornerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 2
      ..strokeCap = StrokeCap.round;

    // 좌상단
    canvas.drawLine(
      rect.topLeft,
      rect.topLeft + Offset(cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      rect.topLeft,
      rect.topLeft + Offset(0, cornerLength),
      cornerPaint,
    );

    // 우상단
    canvas.drawLine(
      rect.topRight,
      rect.topRight + Offset(-cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      rect.topRight,
      rect.topRight + Offset(0, cornerLength),
      cornerPaint,
    );

    // 좌하단
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + Offset(cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + Offset(0, -cornerLength),
      cornerPaint,
    );

    // 우하단
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + Offset(-cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + Offset(0, -cornerLength),
      cornerPaint,
    );
  }

  void _drawLabel(Canvas canvas, Rect rect) {
    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // 라벨 배경
    final labelRect = Rect.fromLTWH(
      rect.left,
      rect.top - textPainter.height - 8,
      textPainter.width + 16,
      textPainter.height + 8,
    );

    final bgPaint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
      bgPaint,
    );

    // 라벨 텍스트
    textPainter.paint(
      canvas,
      Offset(rect.left + 8, rect.top - textPainter.height - 4),
    );
  }

  @override
  bool shouldRepaint(covariant HighlightPainter oldDelegate) {
    return oldDelegate.coordinates != coordinates ||
        oldDelegate.color != color ||
        oldDelegate.label != label;
  }
}

// 간단한 포인터 오버레이 (손가락 위치 표시용)
class PointerOverlay extends StatelessWidget {
  final Offset position;
  final Color color;
  final double size;

  const PointerOverlay({
    super.key,
    required this.position,
    this.color = Colors.red,
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.3),
          border: Border.all(color: color, width: 2),
        ),
        child: Center(
          child: Container(
            width: size / 3,
            height: size / 3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
