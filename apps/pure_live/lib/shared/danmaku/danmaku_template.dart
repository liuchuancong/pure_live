import 'package:pure_live/app/preferences/app_preferences.dart';

/// A danmaku look in one tap (the reference's `DanmakuTemplate`): the band,
/// margins, speed, size, weight, outline width, opacity and outline together;
/// presets apply a bundle, and the viewer's own look round-trips through the
/// `barrageTemplate` preference string.
final class BarrageTemplate {
  /// A look over explicit values.
  const new({
    required this.area,
    required this.speed,
    required this.fontSize,
    required this.strokeWidth,
    required this.opacity,
    this.top = 0,
    this.bottom = 0,
    this.fontWeight = 500,
    this.stroke = true,
  });

  /// The current look of [preferences].
  // ignore: unnecessary_type_name_in_constructor -- a factory keeps its spelled-out name.
  factory BarrageTemplate.of(AppPreferences preferences) => BarrageTemplate(
    area: preferences.barrageArea,
    top: preferences.barrageTopArea,
    bottom: preferences.barrageBottomArea,
    speed: preferences.barrageSpeed,
    fontSize: preferences.barrageFontSize,
    fontWeight: preferences.barrageFontWeight,
    strokeWidth: preferences.barrageStrokeWidth,
    opacity: preferences.barrageOpacity,
    stroke: preferences.barrageStroke,
  );

  /// The three 3.x viewing presets and the reset, with their text keys.
  static const List<(String, BarrageTemplate)> presets = [
    ('best', BarrageTemplate(area: 0.2, speed: 118, fontSize: 16, strokeWidth: 1.5, opacity: 0.92)),
    ('comfort', BarrageTemplate(area: 0.35, speed: 105, fontSize: 17, strokeWidth: 1.5, opacity: 0.9)),
    ('dense', BarrageTemplate(area: 0.55, speed: 138, fontSize: 15, strokeWidth: 1.2, opacity: 0.88)),
    ('reset', BarrageTemplate(area: 1, speed: 120, fontSize: 16, strokeWidth: 1.5, opacity: 1)),
  ];

  /// The share of the picture the barrage may use.
  final double area;

  /// Pixels kept free at the top of the band.
  final double top;

  /// Pixels kept free at the bottom of the band.
  final double bottom;

  /// Crossing speed, px/s.
  final double speed;

  /// The text size.
  final double fontSize;

  /// The CSS text weight, 100..900.
  final int fontWeight;

  /// The outline's blur width.
  final double strokeWidth;

  /// Whether the outline draws at all.
  final bool stroke;

  /// The text opacity.
  final double opacity;

  /// This look written onto [preferences] — what applying a template is.
  AppPreferences applyTo(AppPreferences preferences) => preferences.copyWith(
    barrageArea: area,
    barrageTopArea: top,
    barrageBottomArea: bottom,
    barrageSpeed: speed,
    barrageFontSize: fontSize,
    barrageFontWeight: fontWeight,
    barrageStrokeWidth: strokeWidth,
    barrageStroke: stroke,
    barrageOpacity: opacity,
  );

  /// The preset this look equals, or null for a look of the viewer's own.
  String? get presetKey {
    for (final (key, preset) in presets) {
      if (preset._sameAs(this)) {
        return key;
      }
    }
    return null;
  }

  bool _sameAs(BarrageTemplate other) =>
      (area - other.area).abs() < 0.005 &&
      (top - other.top).abs() < 0.5 &&
      (bottom - other.bottom).abs() < 0.5 &&
      (speed - other.speed).abs() < 0.5 &&
      (fontSize - other.fontSize).abs() < 0.05 &&
      fontWeight == other.fontWeight &&
      (strokeWidth - other.strokeWidth).abs() < 0.05 &&
      stroke == other.stroke &&
      (opacity - other.opacity).abs() < 0.005;

  /// A `k=v;` encoding of the look (the reference's saved template string).
  String encode() => <String, String>{
    'area': _num(area),
    'top': _num(top),
    'bottom': _num(bottom),
    'speed': _num(speed),
    'fontSize': _num(fontSize),
    'fontWeight': '$fontWeight',
    'strokeWidth': _num(strokeWidth),
    'stroke': stroke ? '1' : '0',
    'opacity': _num(opacity),
  }.entries.map((entry) => '${entry.key}=${entry.value}').join(';');

  /// Decodes [text]; null when it is not a template — a broken save is
  /// reported rather than half-applied. Values stay in their sliders' ranges.
  static BarrageTemplate? tryDecode(String text) {
    final values = <String, String>{};
    for (final part in text.split(';')) {
      final at = part.indexOf('=');
      if (at > 0) {
        values[part.substring(0, at)] = part.substring(at + 1);
      }
    }
    double? num(String key, double low, double high) {
      final value = double.tryParse(values[key] ?? '');
      if (value == null || value < low || value > high) {
        return null;
      }
      return value;
    }

    final area = num('area', 0, 1);
    final speed = num('speed', 20, 400);
    final fontSize = num('fontSize', 10, 30);
    final strokeWidth = num('strokeWidth', 0, 4);
    final opacity = num('opacity', 0, 1);
    final weight = int.tryParse(values['fontWeight'] ?? '');
    if (area == null || speed == null || fontSize == null || strokeWidth == null || opacity == null || weight == null) {
      return null;
    }
    return BarrageTemplate(
      area: area,
      top: num('top', 0, 300) ?? 0,
      bottom: num('bottom', 0, 300) ?? 0,
      speed: speed,
      fontSize: fontSize,
      fontWeight: weight.clamp(100, 900),
      strokeWidth: strokeWidth,
      stroke: values['stroke'] != '0',
      opacity: opacity,
    );
  }

  static String _num(double value) => value == value.roundToDouble() ? '${value.round()}' : value.toString();
}
