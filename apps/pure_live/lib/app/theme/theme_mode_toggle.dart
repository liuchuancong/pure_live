import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/providers/environment_providers.dart' show deviceProfileProvider;
import 'package:pure_live/app/theme/theme_mode_dialog.dart' show showThemeModeDialog, themeModeLabel;
import 'package:pure_live/app/theme/theme_settings.dart' show AppThemeScope;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/widgets/chrome_icon_button.dart';

/// The theme switch every title bar carries: the sun while the app is dark,
/// the moon while it is light. Desktop opens a dropdown menu under it;
/// touch opens the three-way choice in a dialog. The appearance pane's row
/// follows the same rule through its own select.
///
/// The choice goes through [AppThemeScope], the root persists it like the
/// pane's own write.
final class ThemeModeToggle extends ConsumerWidget {
  /// A toggle drawn [size] square, its tooltip opening to [tooltipSide].
  const ThemeModeToggle({this.size = 44, this.iconSize = 16, this.tooltipSide = DsSide.bottom, super.key});

  /// The square's side; the title bar uses 44, a touch bar 48.
  final double size;

  /// The glyph's side; 16 beside a caption, 20 on a touch bar.
  final double iconSize;

  /// The side the tooltip opens to.
  final DsSide tooltipSide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    Widget button(VoidCallback onPressed) => ChromeIconButton(
      icon: dark ? DsIcons.sun : DsIcons.moon,
      semanticLabel: t.settings.themeMode,
      tooltip: t.settings.themeMode,
      tooltipSide: tooltipSide,
      size: size,
      iconSize: iconSize,
      onPressed: onPressed,
    );

    if (!ref.watch(deviceProfileProvider).isDesktop) {
      return button(() => unawaited(showThemeModeDialog(context)));
    }
    return DsMenuAnchor(
      semanticLabel: t.settings.themeMode,
      items: [
        for (final mode in DsThemeMode.values)
          DsMenuItem(
            label: Text(themeModeLabel(t, mode)),
            leading: DsIcon(switch (mode) {
              DsThemeMode.system => DsIcons.monitor,
              DsThemeMode.light => DsIcons.sun,
              DsThemeMode.dark => DsIcons.moon,
            }),
            trailing: settings.mode == mode ? const DsIcon(DsIcons.check, size: 16) : null,
            onPressed: () {
              if (mode != settings.mode) scope.onChanged(settings.rebuild((b) => b..mode = mode));
            },
          ),
      ],
      builder: (context, controller, _) => button(controller.toggle),
    );
  }
}
