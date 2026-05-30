import 'dart:math' show pi;
import 'dart:ui' show PathMetric;
import 'package:flutter/material.dart';
import 'package:pure_live/plugins/emoji_manager.dart';

enum DanmakuItemType { scroll, top, bottom, special }

enum ContentType { text, emoji }

class MixedContent {
  final ContentType type;
  final String value;

  const MixedContent(this.type, this.value);
}

class DanmakuContentItem {
  final String text;
  final Color color;
  final DanmakuItemType type;
  final bool selfSend;
  final List<MixedContent> mixedContent;
  String? fontFamily;

  DanmakuContentItem(
    this.text, {
    this.color = Colors.white,
    this.type = DanmakuItemType.scroll,
    this.selfSend = false,
    this.fontFamily,
  }) : mixedContent = _parseMixedContent(text);

  static List<MixedContent> _parseMixedContent(String text) {
    if (text.isEmpty) return const [];

    final List<MixedContent> result = [];
    final regex = RegExp(r'\[(.*?)\]');
    int lastIndex = 0;
    final emojiCache = EmojiManager.instance.cache;

    for (final match in regex.allMatches(text)) {
      final matchedStr = match.group(0);
      if (matchedStr == null) continue;

      if (match.start > lastIndex) {
        result.add(MixedContent(ContentType.text, text.substring(lastIndex, match.start)));
      }

      if (emojiCache.containsKey(matchedStr)) {
        result.add(MixedContent(ContentType.emoji, matchedStr));
      } else {
        result.add(MixedContent(ContentType.text, matchedStr));
      }
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      result.add(MixedContent(ContentType.text, text.substring(lastIndex)));
    }
    return result;
  }
}

class SpecialDanmakuContentItem extends DanmakuContentItem {
  final int duration;
  final double fontSize;
  final bool hasStroke;
  final Tween<double>? alphaTween;
  final Tween<double> translateXTween;
  final Tween<double> translateYTween;
  final int translationDuration;
  final int translationStartDelay;
  final Matrix4? matrix;
  final PathMetric? motionPathMetric;
  final Curve easingType;

  @override
  bool get selfSend => false;
  @override
  DanmakuItemType get type => DanmakuItemType.special;

  TextPainter? painterCache;

  SpecialDanmakuContentItem(
    super.text, {
    required this.duration,
    required super.color,
    required this.fontSize,
    this.hasStroke = false,
    required this.translateXTween,
    required this.translateYTween,
    this.alphaTween,
    this.matrix,
    this.motionPathMetric,
    int? translationDuration,
    this.translationStartDelay = 0,
    this.easingType = Curves.linear,
  }) : translationDuration = translationDuration ?? duration;

  factory SpecialDanmakuContentItem.fromList(
    Color color,
    double fontSize,
    List list, {
    double videoX = 1920,
    double videoY = 1080,
    bool disableGradient = false,
  }) {
    if (list.length < 14) {
      return SpecialDanmakuContentItem(
        "",
        duration: 3000,
        color: color,
        fontSize: fontSize,
        translateXTween: Tween(begin: 0.0, end: 0.0),
        translateYTween: Tween(begin: 0.0, end: 0.0),
      );
    }

    var (startX, endX) = _toRelativePosition(list[0], list[7], videoX);
    var (startY, endY) = _toRelativePosition(list[1], list[8], videoY);

    List<String> alphaString = (list[2] ?? "1-1").toString().split('-');
    double startA = double.tryParse(alphaString[0]) ?? 1.0;
    double endA = alphaString.length > 1 ? (double.tryParse(alphaString[1]) ?? 1.0) : startA;

    Tween<double>? alphaTween;
    if (disableGradient || startA == endA) {
      color = color.withValues(alpha: (startA + endA) / 2);
    } else {
      alphaTween = Tween(begin: startA, end: endA);
    }

    int duration = (_parseDouble(list[3]) * 1000).round();
    String text = (list[4] ?? "").toString().trim();
    int rotateZ = _parseInt(list[5]);
    int rotateY = _parseInt(list[6]);

    Matrix4? matrix;
    if (rotateZ != 0 || rotateY != 0) {
      matrix = Matrix4.identity();
      if (rotateZ != 0) matrix.rotateZ(_degreeToRadian(rotateZ));
      if (rotateY != 0) matrix.rotateY(_degreeToRadian(rotateY));
    }

    var translateXTween = _makeTween(startX, endX);
    var translateYTween = _makeTween(startY, endY);
    int translationDuration = _parseInt(list[9]);
    int translationStartDelay = _parseInt(list[10]);
    bool hasStroke = list[11] == 1;
    var easingType = list[13] == 1 ? Curves.easeInCubic : Curves.linear;

    return SpecialDanmakuContentItem(
      text,
      duration: duration,
      color: color,
      fontSize: fontSize,
      hasStroke: hasStroke,
      alphaTween: alphaTween,
      translateXTween: translateXTween,
      translateYTween: translateYTween,
      translationDuration: translationDuration,
      translationStartDelay: translationStartDelay,
      matrix: matrix,
      easingType: easingType,
    );
  }

  static (double, double) _toRelativePosition(dynamic rawStart, dynamic rawEnd, double videoSize) {
    double toRadix(double? value, dynamic rawValue) {
      if (value == null) return 0.0;
      return (value > 1 || (rawValue is String && !rawValue.contains('.'))) ? value / videoSize : value;
    }

    double? convert(value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    double? start = convert(rawStart);
    double? end = convert(rawEnd);

    if (start == null && end == null) return (0.0, 0.0);
    start ??= end;
    end ??= start;

    return (toRadix(start, rawStart), toRadix(end, rawEnd));
  }

  static int _parseInt(dynamic digit) => switch (digit) {
    int() => digit,
    double() => digit.toInt(),
    String() => int.tryParse(digit) ?? 0,
    _ => 0,
  };

  static double _parseDouble(dynamic digit) => switch (digit) {
    int() => digit.toDouble(),
    double() => digit,
    String() => double.tryParse(digit) ?? 0.0,
    _ => 0.0,
  };

  static Tween<T> _makeTween<T>(T start, T end) {
    return start == end ? ConstantTween<T>(start) : Tween<T>(begin: start, end: end);
  }

  static double _degreeToRadian(int degree) {
    const pi180 = pi / 180;
    return degree * pi180;
  }
}
