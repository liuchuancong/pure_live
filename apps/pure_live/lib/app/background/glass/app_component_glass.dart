import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/background/settings/background_settings.dart';

/// Gives every surface one translucent fill, the floating layers included,
/// so the wallpaper keeps reading through the app.
///
/// Two halves: [themeOf] turns the theme's own surface token translucent,
/// which reaches every card, list section, table and the app's hand-painted
/// panels (the room's columns included) at once; this widget gives the
/// desen_ui layers that take a `backdropFilter` — the menu family (anchored
/// menus, context menus, a select's list), popovers, dialogs, panels,
/// toasts, toolbars, tooltips, the bottom navigation and the text selection
/// bar — the matching fill.
final class AppComponentGlass extends ConsumerWidget {
  /// Paints the floating layers of [child] as glass, as the background
  /// settings ask.
  const AppComponentGlass({required this.child, super.key});

  /// The app (the router's navigator).
  final Widget child;

  /// [theme] with its surface token as translucent as [fill] asks. Cards,
  /// list sections and the app's own surface fills read the token, so they
  /// turn glass along with the themed layers below.
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
        (colors, _) => colors.copyWith(surface: colors.surface.withValues(alpha: fill)),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(backgroundSettingsProvider);
    // The scope stays in the tree either way: switching the glass on must
    // not remount the navigator below it (route state would go with it).
    if (!settings.glass) return DsComponentThemes(themes: const [], child: child);
    final fill = DsTheme.colorsOf(context).overlay.withValues(alpha: settings.glassFill);
    return DsComponentThemes(
      themes: [
        DsMenuThemeData(
          style: DsMenuStyle(background: fill),
        ),
        DsPopoverThemeData(
          style: DsPopoverStyle(background: fill),
        ),
        DsDialogThemeData(
          style: DsDialogStyle(background: fill),
        ),
        DsPanelThemeData(
          style: DsPanelStyle(background: fill),
        ),
        DsToastThemeData(
          style: DsToastStyle(background: fill),
        ),
        DsToolbarThemeData(
          style: DsToolbarStyle(background: fill),
        ),
        DsTooltipThemeData(
          style: DsTooltipStyle(background: fill),
        ),
        DsBottomNavThemeData(
          style: DsBottomNavStyle(background: fill),
        ),
        DsTextSelectionToolbarThemeData(
          style: DsTextSelectionToolbarStyle(background: fill),
        ),
      ],
      child: child,
    );
  }
}
