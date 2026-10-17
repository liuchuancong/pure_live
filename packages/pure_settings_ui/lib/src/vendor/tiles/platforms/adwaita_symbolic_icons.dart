import 'package:flutter/widgets.dart';

/// The GNOME foreground color in light mode, `rgba(0, 0, 6, 0.8)`.
const Color _kForegroundLight = Color.fromRGBO(0, 0, 6, 0.8);

/// The `pan-down-symbolic` arrow that GNOME combo rows (`AdwComboRow`) show
/// after the selected value.
///
/// It is a 16 px icon with a chevron drawn with a 2 px round stroke (10x6
/// of ink, 3 px in from each side),
/// in the ambient [IconTheme] color unless [color] is set. Inside a GNOME
/// style (`DevicePlatform.linux`) tile, that is the foreground color.
///
/// To make a row look like a combo row, put the value and the arrow in the
/// tile's `trailing`, with 9 px between them:
///
/// ```dart
/// SettingsTile(
///   title: const Text('Screen Blank'),
///   trailing: const Row(
///     mainAxisSize: MainAxisSize.min,
///     children: [
///       Text('5 minutes'),
///       SizedBox(width: 9),
///       AdwaitaPanDownIcon(),
///     ],
///   ),
///   onPressed: (context) { /* show the choices */ },
/// )
/// ```
class AdwaitaPanDownIcon extends StatelessWidget {
  /// Creates a GNOME `pan-down-symbolic` arrow.
  const AdwaitaPanDownIcon({super.key, this.color, this.size = 16});

  /// Defaults to the ambient [IconTheme] color.
  final Color? color;

  /// The size of the square icon box. The chevron keeps its 16 px
  /// proportions. Defaults to 16.
  final double size;

  @override
  Widget build(BuildContext context) {
    return _SymbolicChevron(
      points: const [Offset(4, 6), Offset(8, 10), Offset(12, 6)],
      color: color,
      size: size,
    );
  }
}

/// The `go-next-symbolic` arrow that ends GNOME navigation rows: a 16 px
/// icon with a chevron drawn with a 2 px round stroke (8x14 of ink). It points left
/// in right-to-left layouts, like GTK's `-rtl` icon variants.
class AdwaitaGoNextIcon extends StatelessWidget {
  const AdwaitaGoNextIcon({super.key, this.color, this.size = 16});

  /// Defaults to the ambient [IconTheme] color.
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return _SymbolicChevron(
      points: const [Offset(5, 2), Offset(11, 8), Offset(5, 14)],
      color: color,
      size: size,
      mirrored: Directionality.maybeOf(context) == TextDirection.rtl,
    );
  }
}

/// The `go-previous-symbolic` arrow of a GNOME back button:
/// [AdwaitaGoNextIcon] pointing the other way.
class AdwaitaGoPreviousIcon extends StatelessWidget {
  const AdwaitaGoPreviousIcon({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return _SymbolicChevron(
      points: const [Offset(11, 2), Offset(5, 8), Offset(11, 14)],
      color: color,
      size: 16,
      mirrored: Directionality.of(context) == TextDirection.rtl,
    );
  }
}

/// A chevron through [points] in a 16x16 icon, like the Adwaita symbolic
/// arrows.
class _SymbolicChevron extends StatelessWidget {
  const _SymbolicChevron({
    required this.points,
    required this.color,
    required this.size,
    this.mirrored = false,
  });

  final List<Offset> points;
  final Color? color;
  final double size;
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _ChevronPainter(
        points: points,
        color: color ?? IconTheme.of(context).color ?? _kForegroundLight,
        mirrored: mirrored,
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({
    required this.points,
    required this.color,
    required this.mirrored,
  });

  final List<Offset> points;
  final Color color;
  final bool mirrored;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 16;
    canvas.drawPath(
      Path()..addPolygon([
        for (final Offset p in points)
          Offset((mirrored ? 16 - p.dx : p.dx) * scale, p.dy * scale),
      ], false),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.mirrored != mirrored ||
      oldDelegate.points != points;
}
