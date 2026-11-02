import 'dart:ui' show Brightness, ImageFilter;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/background/glass/live_glass.dart';
import 'package:pure_live/app/background/settings/background_settings.dart';
import 'package:pure_live/app/background/tone/background_tone.dart';

/// Sorts the official floating layers onto the G0–G4 glass ladder and paints
/// each with its resolved fill *and* its frost, while the surface and field
/// tokens go translucent so every card, list, table and text field reads the
/// wallpaper through it.
///
/// The fill follows [LiveGlassLevel]: dialogs and the side/bottom panels wear
/// the strong glass, the menu family — dropdowns, anchored and context menus,
/// popovers and tooltips — the standard glass, and the toolbars the subtle
/// one. The phone's floating navigation is the exception: it frosts itself
/// through LiquidGlassPane, so it is not given a second themed blur here. Each
/// level keeps its own readability floor, so the wallpaper can show through
/// without ever making words unreadable; the busy wallpaper only raises that
/// floor, never lowers it. This is the layer that turns the theme's
/// translucent fill into actual frosted glass — without a backdrop filter the
/// fill was only ever see-through, never blurred.
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
    final raise = liveGlassReadabilityRaise(
      settings: settings,
      tone: ref.watch(backgroundToneProvider),
      dark: dark,
    );
    final overlay = DsTheme.colorsOf(context).overlay;
    // The scope stays in the tree either way: switching the glass on must not
    // remount the navigator below it (route state would go with it).
    if (!policy.enabled) return DsComponentThemes(themes: const [], child: child);
    // One material per level the layers use; the fill and its frost come from
    // the same resolved recipe so they can never drift apart.
    Color fill(LiveGlassLevel level) =>
        overlay.withValues(alpha: policy.materialFor(level, dark: dark, readabilityRaise: raise).fillAlpha);
    ImageFilter? frost(LiveGlassLevel level) =>
        policy.materialFor(level, dark: dark, readabilityRaise: raise).backdropFilter;
    final strong = fill(LiveGlassLevel.strong);
    final standard = fill(LiveGlassLevel.standard);
    return DsComponentThemes(
      themes: [
        // Dialogs and the large sheets: the strong glass, the most opaque of
        // the frosted tiers, so a form over a busy wallpaper still reads.
        DsDialogThemeData(style: DsDialogStyle(background: strong, backdropFilter: frost(LiveGlassLevel.strong))),
        DsPanelThemeData(style: DsPanelStyle(background: strong, backdropFilter: frost(LiveGlassLevel.strong))),
        // The menu family and popovers: standard glass — small, text-dense,
        // read for a moment over whatever is behind them.
        DsPopoverThemeData(style: DsPopoverStyle(background: standard, backdropFilter: frost(LiveGlassLevel.standard))),
        DsMenuThemeData(style: DsMenuStyle(background: standard, backdropFilter: frost(LiveGlassLevel.standard))),
        DsTooltipThemeData(style: DsTooltipStyle(background: standard, backdropFilter: frost(LiveGlassLevel.standard))),
        DsToastThemeData(style: DsToastStyle(background: standard, backdropFilter: frost(LiveGlassLevel.standard))),
        // Toolbars: subtle glass — a settled chrome bar, light frost.
        DsToolbarThemeData(
          style: DsToolbarStyle(background: fill(LiveGlassLevel.subtle), backdropFilter: frost(LiveGlassLevel.subtle)),
        ),
        // The bottom navigation is deliberately absent: its only consumer is
        // the phone's floating bar, which paints its own subtle (G1) glass
        // through LiquidGlassPane — frosting it here too would blur the page a
        // second time behind the same capsule (§9.2: one blur per region).
        // The text-selection bar sits over the very words being selected: it
        // keeps the opaque overlay so the selection is never blurred out.
        DsTextSelectionToolbarThemeData(style: DsTextSelectionToolbarStyle(background: overlay)),
      ],
      child: child,
    );
  }
}
