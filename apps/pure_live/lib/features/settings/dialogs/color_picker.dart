import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

/// The saturation/value square: horizontal white → hue, vertical
/// transparent → black, with the current colour marked. Shared by the colour
/// dialogs so every picker in settings behaves the same way.
final class ColorPickerField extends StatelessWidget {
  /// The field over [hsv], reporting every drag as a new colour.
  const ColorPickerField({required this.hsv, required this.onChanged, required this.semanticLabel, super.key});

  /// The colour the marker sits on.
  final HSVColor hsv;

  /// Fired while the finger or pointer moves across the field.
  final ValueChanged<HSVColor> onChanged;

  /// Name for screen readers.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const height = 160.0;
        final width = constraints.maxWidth;
        void pick(Offset position) {
          final saturation = (position.dx / width).clamp(0.0, 1.0);
          final value = (1 - position.dy / height).clamp(0.0, 1.0);
          onChanged(hsv.withSaturation(saturation).withValue(value));
        }

        return Semantics(
          label: semanticLabel,
          value: '${(hsv.saturation * 100).round()}% / ${(hsv.value * 100).round()}%',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(theme.radii.card / 2),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (details) => pick(details.localPosition),
              onPanUpdate: (details) => pick(details.localPosition),
              child: CustomPaint(size: Size(width, height), painter: _ColorFieldPainter(hsv)),
            ),
          ),
        );
      },
    );
  }
}

final class _ColorFieldPainter extends CustomPainter {
  const _ColorFieldPainter(this.hsv);

  final HSVColor hsv;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hue = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
    canvas
      ..drawRect(rect, Paint()..shader = LinearGradient(colors: [const Color(0xFFFFFFFF), hue]).createShader(rect))
      ..drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), Color(0xFF000000)],
          ).createShader(rect),
      );
    final center = Offset(hsv.saturation * size.width, (1 - hsv.value) * size.height);
    canvas
      ..drawCircle(
        center,
        8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFFFFFF),
      )
      ..drawCircle(
        center,
        9.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x99000000),
      );
  }

  @override
  bool shouldRepaint(_ColorFieldPainter oldDelegate) => oldDelegate.hsv != hsv;
}

/// The hue strip: the full colour circle across the width, with the current
/// hue marked.
final class ColorPickerHueBar extends StatelessWidget {
  /// The strip over [hue], reporting every drag as a new hue in degrees.
  const ColorPickerHueBar({required this.hue, required this.onChanged, required this.semanticLabel, super.key});

  /// The hue the marker sits on, in degrees.
  final double hue;

  /// Fired while the finger or pointer moves across the strip.
  final ValueChanged<double> onChanged;

  /// Name for screen readers.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const height = 20.0;
        final width = constraints.maxWidth;
        void pick(Offset position) => onChanged((position.dx / width).clamp(0.0, 1.0) * 360);
        return Semantics(
          label: semanticLabel,
          value: '${hue.round()}°',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DsRadii.pill),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (details) => pick(details.localPosition),
              onPanUpdate: (details) => pick(details.localPosition),
              child: CustomPaint(size: Size(width, height), painter: _HueBarPainter(hue)),
            ),
          ),
        );
      },
    );
  }
}

final class _HueBarPainter extends CustomPainter {
  const _HueBarPainter(this.hue);

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFFF0000),
            Color(0xFFFFFF00),
            Color(0xFF00FF00),
            Color(0xFF00FFFF),
            Color(0xFF0000FF),
            Color(0xFFFF00FF),
            Color(0xFFFF0000),
          ],
        ).createShader(rect),
    );
    final center = Offset(hue / 360 * size.width, size.height / 2);
    canvas
      ..drawCircle(
        center,
        7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFFFFFF),
      )
      ..drawCircle(
        center,
        8.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x99000000),
      );
  }

  @override
  bool shouldRepaint(_HueBarPainter oldDelegate) => oldDelegate.hue != hue;
}

/// One colour as a dot; a rim keeps white readable on white.
final class ColorDot extends StatelessWidget {
  /// The dot for [color].
  const ColorDot({required this.color, this.size = 14, super.key});

  /// The ARGB colour to show.
  final int color;

  /// The dot's diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(color),
        border: Border.all(color: DsTheme.colorsOf(context).border),
      ),
    );
  }
}

/// A colour as its six hex digits, uppercase: what the pickers show beside
/// the swatch.
String colorPickerHexLabel(int color) => '#${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Parses a pasted hex colour (`#RRGGBB` or `#AARRGGBB`); the alpha is
/// dropped, because every stored colour is opaque. Null when the text is not
/// a colour.
int? parseColorPickerHex(String text) {
  final value = text.trim().replaceFirst('#', '');
  if (value.length != 6 && value.length != 8) return null;
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : 0xFF000000 | (parsed & 0xFFFFFF);
}
