import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/background/settings/background_settings.dart';

/// Turns the theme's own surface and field tokens translucent while the
/// glass is on, so every card, list section, table, text field and
/// hand-painted panel (the room's columns included) reads the wallpaper
/// through it — and sorts the official floating layers into the ones that
/// follow that fill and the ones that must stay opaque.
///
/// Following the panel fill: dialogs, the side and bottom panels, popovers,
/// toolbars and the bottom navigation — layers a viewer settles into, laid
/// out like the panels around them. Opaque whatever the fill asks: tooltips,
/// toasts, the menu family (anchored menus, context menus, a select's list)
/// and the text selection bar — small, text-dense, read for a moment over
/// whatever happens to be behind them, the one place a wallpaper makes words
/// unreadable.
final class AppComponentGlass extends ConsumerWidget {
  /// Paints the floating layers of [child] as the background settings ask.
  const AppComponentGlass({required this.child, super.key});

  /// The app (the router's navigator).
  final Widget child;

  /// [theme] with its surface and field tokens as translucent as [fill]
  /// asks. Cards, list sections, text fields and the app's own surface fills
  /// read the tokens, so they turn glass along with the themed layers below.
  static DsThemeData themeOf(DsThemeData theme, {required bool glass, required double fill}) {
    if (!glass) return theme;
    final outer = theme.adjustColors;
    // One adjuster per fill: theme equality (and the scope's cache key) uses
    // the hook's identity, and a fresh closure on every build would make the
    // palette regenerate for no change.
    final adjust = outer == null ? _fillAdjuster(fill) : _compose(outer, _fillAdjuster(fill));
    return theme.copyWith(adjustColors: () => adjust);
  }

  static DsColorsAdjuster _compose(DsColorsAdjuster first, DsColorsAdjuster second) =>
      (colors, brightness) => second(first(colors, brightness), brightness);

  static final Map<double, DsColorsAdjuster> _fillAdjusters = {};

  static DsColorsAdjuster _fillAdjuster(double fill) => _fillAdjusters.putIfAbsent(
    fill,
    () =>
        (colors, _) => colors.copyWith(
          surface: colors.surface.withValues(alpha: fill),
          field: colors.field.withValues(alpha: fill),
        ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(backgroundSettingsProvider);
    // The scope stays in the tree either way: switching the glass on must
    // not remount the navigator below it (route state would go with it).
    if (!settings.glass) return DsComponentThemes(themes: const [], child: child);
    final overlay = DsTheme.colorsOf(context).overlay;
    // The layers that follow the panel fill, and the ones that stay opaque.
    final glass = overlay.withValues(alpha: settings.glassFill);
    final opaque = overlay.withValues(alpha: 1);
    return DsComponentThemes(
      themes: [
        DsDialogThemeData(style: DsDialogStyle(background: glass)),
        DsPanelThemeData(style: DsPanelStyle(background: glass)),
        DsPopoverThemeData(style: DsPopoverStyle(background: glass)),
        DsToolbarThemeData(style: DsToolbarStyle(background: glass)),
        DsBottomNavThemeData(style: DsBottomNavStyle(background: glass)),
        DsTooltipThemeData(style: DsTooltipStyle(background: opaque)),
        DsToastThemeData(style: DsToastStyle(background: opaque)),
        DsMenuThemeData(style: DsMenuStyle(background: opaque)),
        DsTextSelectionToolbarThemeData(style: DsTextSelectionToolbarStyle(background: opaque)),
      ],
      child: child,
    );
  }
}
