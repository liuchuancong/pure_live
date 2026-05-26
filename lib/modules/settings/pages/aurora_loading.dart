import 'dart:math' as math;
import 'package:flutter/material.dart';

class AuroraLoading extends StatefulWidget {
  final double size;
  final Duration rotateDuration;
  final Duration colorChangeDuration;

  const AuroraLoading({
    super.key,
    required this.size,
    this.rotateDuration = const Duration(milliseconds: 1500),
    this.colorChangeDuration = const Duration(seconds: 4),
  });

  @override
  State<AuroraLoading> createState() => _AuroraLoadingState();
}

class _AuroraLoadingState extends State<AuroraLoading> with TickerProviderStateMixin {
  late AnimationController _rotateController;
  late AnimationController _colorController;

  late List<Color> _baseColors;
  late int _currentIndex;
  late int _nextIndex;

  @override
  void initState() {
    super.initState();

    _baseColors = [
      const Color(0xFF00E5FF),
      const Color(0xFFFF4081),
      const Color(0xFF00E676),
      const Color(0xFFFFEA00),
      const Color(0xFF7C4DFF),
    ];

    _currentIndex = 0;
    _nextIndex = 1;

    _rotateController = AnimationController(vsync: this, duration: widget.rotateDuration)..repeat();

    _colorController = AnimationController(vsync: this, duration: widget.colorChangeDuration);

    _colorController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentIndex = _nextIndex;
          final random = math.Random();
          do {
            _nextIndex = random.nextInt(_baseColors.length);
          } while (_nextIndex == _currentIndex);

          _colorController.reset();
          _colorController.forward();
        });
      }
    });

    _colorController.forward();
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double strokeWidth = widget.size * 0.10;

    return AnimatedBuilder(
      animation: Listenable.merge([_rotateController, _colorController]),
      builder: (context, child) {
        final Color headColor = Color.lerp(
          _baseColors[_currentIndex],
          _baseColors[_nextIndex],
          _colorController.value,
        )!;

        final List<Color> tailColors = [
          headColor,
          headColor.withValues(alpha: 0.85),
          headColor.withValues(alpha: 0.55),
          headColor.withValues(alpha: 0.25),
          headColor.withValues(alpha: 0.05),
          Colors.transparent,
        ];

        final List<double> stops = [0.0, 0.3, 0.6, 0.8, 0.92, 1.0];

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _AuroraTailPainter(
              colors: tailColors,
              stops: stops,
              rotationAngle: _rotateController.value * 2 * math.pi,
              strokeWidth: strokeWidth,
            ),
          ),
        );
      },
    );
  }
}

class _AuroraTailPainter extends CustomPainter {
  final List<Color> colors;
  final List<double> stops;
  final double rotationAngle;
  final double strokeWidth;

  _AuroraTailPainter({
    required this.colors,
    required this.stops,
    required this.rotationAngle,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.save();

    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);

    paint.shader = SweepGradient(colors: colors, stops: stops, center: Alignment.center).createShader(rect);

    canvas.drawCircle(Offset.zero, radius, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AuroraTailPainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle || oldDelegate.colors != colors;
  }
}
