import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/app/theme/theme_settings.dart' show AppThemeScope;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/widgets/chrome_icon_button.dart';

/// The one-press light/dark switch every title bar carries: the sun while
/// the app is dark (press for light), the moon while it is light (press for
/// dark). A system mode resolves against the platform's brightness before
/// it flips, so the first press always lands on the opposite of what the
/// viewer sees; the full three-way choice stays in the appearance pane.
///
/// The choice goes through [AppThemeScope], the root persists it like the
/// pane's own write.
final class ThemeModeToggle extends StatelessWidget {
  /// A toggle drawn [size] square, its tooltip opening to [tooltipSide].
  const ThemeModeToggle({this.size = 44, this.iconSize = 16, this.tooltipSide = DsSide.bottom, super.key});

  /// The square's side; the title bar uses 44, a touch bar 48.
  final double size;

  /// The glyph's side; 16 beside a caption, 20 on a touch bar.
  final double iconSize;

  /// The side the tooltip opens to.
  final DsSide tooltipSide;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    // Rendered outside the app's root (a preview, a test leaf): no theme
    // scope to write, no switch to offer.
    if (scope == null) return const SizedBox.shrink();
    final settings = scope.settings;
    final platformDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final dark = switch (settings.mode) {
      DsThemeMode.light => false,
      DsThemeMode.dark => true,
      DsThemeMode.system => platformDark,
    };
    final t = context.t;
    final label = dark ? t.common.switchToLight : t.common.switchToDark;
    return ChromeIconButton(
      icon: dark ? DsIcons.sun : DsIcons.moon,
      semanticLabel: label,
      tooltip: label,
      tooltipSide: tooltipSide,
      size: size,
      iconSize: iconSize,
      onPressed: () {
        final next = dark ? DsThemeMode.light : DsThemeMode.dark;
        scope.onChanged(settings.rebuild((b) => b..mode = next));
      },
    );
  }
}
