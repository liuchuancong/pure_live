import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/split/sidebar_button.dart';
import 'package:pure_settings_ui/src/vendor/utils/fluent_tokens.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';

// What the pane and the page header of the Windows style split view share:
// the focus visual and the subtle button.

/// ControlCornerRadius.
const double kFluentControlRadius = 4;

/// [child] with the WinUI keyboard focus visual around it. With [show]
/// false it draws nothing and only keeps [child] at the same place in the
/// tree, so its State survives the visual coming and going.
Widget fluentFocusRing(FluentTokens tokens, Widget child, {bool show = true}) =>
    CustomPaint(
      foregroundPainter: show ? _FocusRingPainter(tokens) : null,
      child: child,
    );

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter(this.tokens);

  final FluentTokens tokens;

  @override
  void paint(Canvas canvas, Size size) => paintFluentFocusRing(
    canvas,
    Offset.zero & size,
    kFluentControlRadius,
    tokens,
  );

  @override
  bool shouldRepaint(_FocusRingPainter oldDelegate) =>
      oldDelegate.tokens != tokens;
}

/// The glyphs of the Windows pane buttons (Segoe Fluent Icons), drawn.
enum FluentGlyph {
  /// E72B Back.
  back,

  /// E700 GlobalNavigationButton.
  menu,
}

/// A 40x36 subtle button of the Windows pane and title bar (back, pane
/// toggle): transparent at rest, SubtleFillSecondary on hover,
/// SubtleFillTertiary with a secondary glyph while pressed. Internal.
class FluentSubtleButton extends SidebarButton {
  const FluentSubtleButton({
    super.key,
    required String super.semanticLabel,
    required VoidCallback super.onPressed,
    required this.glyph,
  });

  final FluentGlyph glyph;

  @override
  Widget buildButton(BuildContext context, SidebarButtonStates states) {
    final theme = SettingsTheme.of(context).themeData;
    final tokens = fluentTokensOf(context);
    final primary = theme.settingsTileTextColor ?? tokens.textPrimary;
    final secondary = theme.tileDescriptionTextColor ?? tokens.textSecondary;
    final button = Container(
      width: 40,
      height: 36,
      decoration: BoxDecoration(
        color: states.pressed
            ? tokens.navItemPressed
            : states.hovered
            ? tokens.navItemSelected
            : null,
        borderRadius: BorderRadius.circular(kFluentControlRadius),
      ),
      alignment: Alignment.center,
      child: CustomPaint(
        size: const Size.square(16),
        painter: _GlyphPainter(
          glyph: glyph,
          color: states.pressed ? secondary : primary,
          textDirection: Directionality.of(context),
        ),
      ),
    );
    return states.focused ? fluentFocusRing(tokens, button) : button;
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({
    required this.glyph,
    required this.color,
    required this.textDirection,
  });

  final FluentGlyph glyph;
  final Color color;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final scale = size.shortestSide / 16;
    canvas.scale(scale);
    switch (glyph) {
      case FluentGlyph.back:
        if (textDirection == TextDirection.rtl) {
          canvas.translate(16, 0);
          canvas.scale(-1, 1);
        }
        canvas.drawPath(
          Path()
            ..moveTo(14.5, 8)
            ..lineTo(1.5, 8)
            ..moveTo(7.5, 2)
            ..lineTo(1.5, 8)
            ..lineTo(7.5, 14),
          paint,
        );
      case FluentGlyph.menu:
        for (final y in [3.5, 8.0, 12.5]) {
          canvas.drawLine(Offset(1.5, y), Offset(14.5, y), paint);
        }
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.color != color ||
      oldDelegate.textDirection != textDirection;
}
