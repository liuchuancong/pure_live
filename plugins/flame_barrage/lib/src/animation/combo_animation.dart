import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;

class ComboAnimation extends PositionComponent {
  ComboAnimation({required this.count, required Vector2 startPosition}) {
    position = startPosition;
    _buildParagraph();
  }

  int count;
  double _scale = 1.5;
  double _opacity = 1.0;
  double _time = 0.0;
  late Paragraph _paragraph;

  void updateCount(int newCount) {
    count = newCount;
    _scale = 1.8;
    _time = 0.0;
    _opacity = 1.0;
    _buildParagraph();
  }

  void _buildParagraph() {
    final builder = ParagraphBuilder(ParagraphStyle(fontSize: 20))
      ..pushStyle(
        TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.orangeAccent.withValues(alpha: _opacity),
          shadows: [
            Shadow(
              blurRadius: 3.0,
              color: const Color(0xFF000000).withValues(alpha: _opacity),
              offset: const Offset(1.5, 1.5),
            ),
          ],
        ),
      )
      ..addText(' x$count');
    _paragraph = builder.build()..layout(const ParagraphConstraints(width: double.infinity));
    size = Vector2(_paragraph.maxIntrinsicWidth, _paragraph.height);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    if (_scale > 1.0) {
      _scale -= dt * 4.0;
      if (_scale < 1.0) _scale = 1.0;
    }

    if (_time > 0.8) {
      _opacity -= dt * 2.0;
      _buildParagraph();
      if (_opacity <= 0) {
        removeFromParent();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.scale(_scale);
    canvas.drawParagraph(_paragraph, Offset.zero);
    canvas.restore();
  }
}
