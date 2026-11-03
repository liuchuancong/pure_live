import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/background/glass/live_glass.dart';
import 'package:pure_live/app/background/settings/background_settings.dart';
import 'package:pure_live/app/background/tone/background_tone.dart';

/// Paints the floating family — dialogs, panels, menus, popovers, notices and
/// the text-selection bar — with the fill and frost the floating opacity
/// slider resolves, while the surface and field tokens go translucent so every
/// card, list, table and text field reads the wallpaper through it.
///
/// The phone's floating navigation is the exception here: it frosts itself
/// through LiquidGlassPane (driven by the same floating opacity), so it is not
/// given a second themed blur. Every fill and its frost come from the same
/// resolved recipe, so they can never drift apart.
final class AppComponentGlass extends ConsumerWidget {
  /// Paints the floating layers of [child] as the glass policy resolves them.
  const AppComponentGlass({required this.child, super.key});

  /// The app (the router's navigator).
  final Widget child;

  /// [theme] with its surface and field tokens as translucent as the panel
  /// fill [fill] asks. Cards, list sections, text fields and the app's own
  /// surface fills read those tokens, so they turn glass along with the
  /// themed layers below. [glass] off keeps every token opaque.
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
    final dark = DsTheme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.maybeOf(context);
    final policy = ref
        .watch(liveGlassPolicyProvider)
        .demoted(reduceVisualEffects: media?.disableAnimations == true || media?.highContrast == true);
    final raise = liveGlassReadabilityRaise(settings: settings, tone: ref.watch(backgroundToneProvider), dark: dark);
    // The scope stays in the tree either way: switching the glass on must not
    // remount the navigator below it (route state would go with it).
    if (!policy.enabled) return DsComponentThemes(themes: const [], child: child);
    // One material for the whole floating family — dialogs, panels, menus,
    // popovers, notices and the selection bar — from the viewer's single
    // opacity slider. The fill and its frost come from the same resolved
    // recipe so they can never drift apart.
    final material = policy.floatingMaterial(opacity: settings.glassFloatingOpacity, readabilityRaise: raise);
    final colors = DsTheme.colorsOf(context);
    final typography = DsTheme.of(context).typography;
    final fill = colors.overlay.withValues(alpha: material.fillAlpha);
    final frost = material.backdropFilter;
    return DsComponentThemes(
      themes: [
        DsDialogThemeData(
          style: DsDialogStyle(background: fill, backdropFilter: frost),
        ),
        DsPanelThemeData(
          style: DsPanelStyle(background: fill, backdropFilter: frost),
        ),
        DsPopoverThemeData(
          style: DsPopoverStyle(background: fill, backdropFilter: frost),
        ),
        DsMenuThemeData(
          style: DsMenuStyle(background: fill, backdropFilter: frost),
        ),
        // A tooltip's default text is the on-tooltip colour meant for the
        // opaque dark chip; over a translucent glass fill it has to follow
        // the layer under it, or it reads white-on-light.
        DsTooltipThemeData(
          style: DsTooltipStyle(
            background: fill,
            backdropFilter: frost,
            textStyle: typography.label.copyWith(color: colors.text),
            shortcutStyle: typography.caption.copyWith(color: colors.textMuted),
          ),
        ),
        DsToastThemeData(
          style: DsToastStyle(background: fill, backdropFilter: frost),
        ),
        // The bottom navigation is deliberately absent: its only consumer is
        // the phone's floating bar, which paints its own glass through
        // LiquidGlassPane — frosting it here too would blur the page a second
        // time behind the same capsule (§9.2: one blur per region).
        // The text-selection bar rides the same floating material.
        DsTextSelectionToolbarThemeData(
          style: DsTextSelectionToolbarStyle(background: fill, backdropFilter: frost),
        ),
      ],
      child: child,
    );
  }
}
