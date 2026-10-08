import 'dart:ui' show Color;

import 'package:flutter/painting.dart' show BoxFit;

import 'package:pure_live/core/consts/background_source.dart';

/// The app background: which surface to paint, and how to fit and dim it.
///
/// Persisted as one JSON value, so every field must survive [toJson] /
/// [fromJson] round-trips, and unknown or malformed input degrades to the
/// default rather than throwing at start-up.
class BackgroundConfig {
  static const double defaultMaskOpacity = 0.35;
  static const int maxBlurSigma = 60;

  /// A desaturated navy ramp: the fallback surface behind artwork while it
  /// decodes, and the default gradient when none has been chosen.
  static const List<Color> defaultGradientColors = <Color>[Color(0xFF141E30), Color(0xFF243B55), Color(0xFF141E30)];

  final BackgroundSource source;
  final BoxFit boxFit;

  /// Opacity of the layer that keeps page text readable over artwork.
  final double maskOpacity;

  /// Gaussian blur strength (sigma); 0 disables it. Only media backgrounds blur
  /// - a flat fill blurred is still a flat fill.
  final double blurSigma;
  final Color solidColor;
  final List<Color> gradientColors;
  final String imagePath;
  final String imageUrl;
  final String videoPath;
  final String videoUrl;

  const BackgroundConfig({
    this.source = BackgroundSource.none,
    this.boxFit = BoxFit.cover,
    this.maskOpacity = defaultMaskOpacity,
    this.blurSigma = 0,
    this.solidColor = const Color(0xFF141E30),
    this.gradientColors = defaultGradientColors,
    this.imagePath = '',
    this.imageUrl = '',
    this.videoPath = '',
    this.videoUrl = '',
  });

  bool get isVideo => isVideoBackground(source);

  bool get isImage => isImageBackground(source);

  bool get hasBackground => source != BackgroundSource.none;

  BackgroundConfig copyWith({
    BackgroundSource? source,
    BoxFit? boxFit,
    double? maskOpacity,
    double? blurSigma,
    Color? solidColor,
    List<Color>? gradientColors,
    String? imagePath,
    String? imageUrl,
    String? videoPath,
    String? videoUrl,
  }) {
    return BackgroundConfig(
      source: source ?? this.source,
      boxFit: boxFit ?? this.boxFit,
      maskOpacity: maskOpacity ?? this.maskOpacity,
      blurSigma: blurSigma ?? this.blurSigma,
      solidColor: solidColor ?? this.solidColor,
      gradientColors: gradientColors ?? this.gradientColors,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      videoPath: videoPath ?? this.videoPath,
      videoUrl: videoUrl ?? this.videoUrl,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'source': backgroundSourceToString(source),
    'boxFit': boxFit.name,
    'maskOpacity': maskOpacity,
    'blurSigma': blurSigma,
    'solidColor': colorToHex(solidColor),
    'gradientColors': gradientColors.map(colorToHex).join(','),
    'imagePath': imagePath,
    'imageUrl': imageUrl,
    'videoPath': videoPath,
    'videoUrl': videoUrl,
  };

  factory BackgroundConfig.fromJson(Map<String, dynamic> json) {
    return BackgroundConfig(
      source: backgroundSourceFromString(json['source']?.toString() ?? 'none'),
      boxFit: _boxFitFromName(json['boxFit']?.toString()),
      maskOpacity: _unitInterval(json['maskOpacity'], defaultMaskOpacity),
      blurSigma: _sigma(json['blurSigma']),
      solidColor: colorFromHex(json['solidColor']?.toString() ?? '') ?? const Color(0xFF141E30),
      gradientColors: _colorsFrom(json['gradientColors']?.toString()),
      imagePath: json['imagePath']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      videoPath: json['videoPath']?.toString() ?? '',
      videoUrl: json['videoUrl']?.toString() ?? '',
    );
  }
}

BoxFit _boxFitFromName(String? name) => BoxFit.values.firstWhere((fit) => fit.name == name, orElse: () => BoxFit.cover);

double _unitInterval(Object? value, double fallback) {
  final number = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
  if (number == null) return fallback;
  return number.clamp(0.0, 1.0);
}

double _sigma(Object? value) {
  final number = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
  if (number == null || number <= 0) return 0;
  return number.clamp(0.0, BackgroundConfig.maxBlurSigma.toDouble());
}

List<Color> _colorsFrom(String? joined) {
  if (joined == null || joined.isEmpty) return BackgroundConfig.defaultGradientColors;
  final colors = joined.split(',').map(colorFromHex).whereType<Color>().toList(growable: false);
  // A two-stop minimum keeps LinearGradient valid; a single swatch still reads
  // as itself, and a truncated ramp should not fail the whole configuration.
  if (colors.isEmpty) return BackgroundConfig.defaultGradientColors;
  if (colors.length == 1) return <Color>[colors.first, colors.first];
  return colors;
}

/// `#rrggbb` - the form the wallpaper APIs and colour pickers publish.
String colorToHex(Color color) => '#${((color.toARGB32() & 0xFFFFFF)).toRadixString(16).padLeft(6, '0')}';

/// Accepts `#rgb`, `#rrggbb`, `rrggbb` and `0xffrrggbb`; anything else is null
/// so the caller can apply its own default.
Color? colorFromHex(String value) {
  var text = value.trim();
  if (text.isEmpty) return null;
  if (text.startsWith('#')) text = text.substring(1);
  if (text.length == 3) {
    text = text.split('').map((digit) => '$digit$digit').join();
  }
  if (text.length == 8) text = text.substring(2);
  if (text.length != 6) return null;
  final parsed = int.tryParse(text, radix: 16);
  if (parsed == null) return null;
  return Color(0xFF000000 | parsed);
}
