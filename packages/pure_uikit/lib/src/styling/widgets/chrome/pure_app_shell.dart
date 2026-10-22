import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pure_uikit/src/scales/radii.dart';
import 'package:pure_uikit/src/scales/sizing.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/widgets/chrome/pure_nav_bar.dart';
import 'package:pure_uikit/src/styling/widgets/chrome/pure_shell_types.dart';
import 'package:pure_uikit/src/styling/widgets/layout/pure_environment.dart';

/// The public application shell: one widget, every design language.
///
/// It sits between the host and the page — the routing layer's `ShellRoute` in
/// an app — and takes only neutral data: the destinations, the selected id,
/// the callback and the body. One private `_ShellVisual` is resolved from
/// `PureTheme.of(context)` plus `theme.config.language`, and all nine
/// languages paint their navigation pane here, from the tokens: Windows
/// Fluent's NavigationView row with its accent edge pill, macOS's source list
/// with the solid-accent chip, iOS's grouped list with hairline separators,
/// Material 3's icon-over-label rail with its container pill, Ubuntu's quiet
/// rounded chips, forui's shadcn card rows, the frosted glass pane, the
/// raised-and-sunk neumorphic pane and wind's bold-quiet Harmony rows.
/// Nothing is borrowed from fluent_2, macos_ui, forui or the Material rail:
/// the pane surface, the row states, the separators, the overlay drawer, its
/// scrim and its hamburger are all painted from `PureTheme`, so a language
/// re-skin and a dark switch still come out right.
///
/// The host chain is the app's, not the shell's: the per-language hosts
/// `PureApp` mounts (`buildFluentAppHost`, `buildMacosAppHost`, the
/// `WidgetsApp`-based forui/glass/neumorphic/wind hosts, the Material, Yaru
/// and Cupertino app hosts) still wrap the tree, own the library theme data
/// and — with `window_manager` behind `PureTitleBar`'s actions seam — own the
/// real window. That chain is documented work and is not this widget's to
/// remove; what the shell no longer does is borrow those libraries'
/// *appearance* widgets to draw its pane. Window frame, title reservation and
/// safe-area insets belong to `PureScaffold` and `PureTitleBar` (the scaffold
/// lane); the shell reserves its pane, hands the body through, and answers
/// for nothing above the fold.
///
/// Every pane row answers to the same interaction contract, whatever the
/// language: hover and pressed tints, a disabled destination that keeps its
/// row and refuses the tap, a focus ring with up/down traversal and
/// Enter/Space/Select activation for keyboards and remotes, screen-reader
/// semantics on every row, and motion that honours the config's `animations`
/// flag. The bottom-strip form stays delegated to [PureNavBar] — the same
/// dispatched control a page names — so the two forms cannot drift apart.
class PureAppShell extends StatefulWidget {
  /// A shell around [child].
  const new({
    required this.child,
    this.destinations = const <PureShellDestination>[],
    this.selectedId,
    this.onSelected,
    this.leading,
    this.trailing,
    this.placement = PureShellPlacement.adaptive,
    super.key,
  });

  /// The page content.
  final Widget child;

  /// The destinations, in order.
  final List<PureShellDestination> destinations;

  /// The selected destination's id.
  final String? selectedId;

  /// Called with a destination's id.
  final ValueChanged<String>? onSelected;

  /// Content pinned at the head of a navigation column, above the
  /// destinations — the entries a rail carries that are not destinations
  /// (a menu, a search, a tool that opens its own page).
  final Widget? leading;

  /// Content pinned at the end of a navigation column; the bottom-strip form
  /// has neither a head nor a foot slot and drops both rather than inventing a
  /// place for them.
  final Widget? trailing;

  /// Where the caller wants the navigation.
  final PureShellPlacement placement;

  @override
  PureAppShellState createState() => PureAppShellState();
}

/// The shell's state: only the fluent narrow form keeps any — whether its
/// overlay drawer (painted here now, not the library's) is showing. Every
/// other form is a pure function of the placement and the destinations, so
/// the configuration below reads exactly as it did when the whole shell was
/// stateless.
class PureAppShellState extends State<PureAppShell> {
  /// Whether the fluent narrow form's overlay drawer is showing.
  bool _fluentDrawerOpen = false;

  /// The page content.
  Widget get child => widget.child;

  /// The destinations, in order.
  List<PureShellDestination> get destinations => widget.destinations;

  /// The selected destination's id.
  String? get selectedId => widget.selectedId;

  /// Called with a destination's id.
  ValueChanged<String>? get onSelected => widget.onSelected;

  /// Content pinned at the head of a navigation column.
  Widget? get leading => widget.leading;

  /// Content pinned at the end of a navigation column.
  Widget? get trailing => widget.trailing;

  /// Where the caller wants the navigation.
  PureShellPlacement get placement => widget.placement;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    if (_standsAside) {
      return child;
    }
    if (!_wantsRail(placement, context)) {
      return _bottomStrip();
    }
    final visual = _resolveVisual(theme);
    // Only fluent trades the pane for an overlay drawer below the breakpoint:
    // the Windows 11 Settings grammar. The buckets come from the shared
    // [PureBreakpoints] qualification (768/1024), the same source every
    // dynamic layout reads.
    if (visual.overlayWhenNarrow) {
      return PureAdaptiveLayout(
        child: child,
        mobile: (context, child) => _fluentNarrow(context, theme, visual, child!),
        tablet: (context, child) => _rail(context, theme, visual, child!),
        desktop: (context, child) => _rail(context, theme, visual, child!),
      );
    }
    return _rail(context, theme, visual, child);
  }

  /// One destination is not a navigation choice, and a shell asked for none:
  /// the frame is the page's own and the shell stands aside.
  bool get _standsAside => placement == PureShellPlacement.none || destinations.length < 2;

  /// Whether the rail form is drawn for [placement]: `rail` always, `bottom`
  /// never, and `adaptive` whenever the environment reports a rail width above
  /// zero — the same width rule every language reads, so the form switch
  /// happens at one breakpoint across the family.
  static bool _wantsRail(PureShellPlacement placement, BuildContext context) => switch (placement) {
    PureShellPlacement.rail => true,
    PureShellPlacement.bottom || PureShellPlacement.none => false,
    PureShellPlacement.adaptive =>
      (PureEnvironmentScope.maybeOf(context)?.geometry.railWidth ?? PureSizing.railWidth) > 0,
  };

  /// The language's pane grammar, resolved once per build. Nine grammars,
  /// nine self-painted visuals — no library widget below this line.
  static _ShellVisual _resolveVisual(PureTheme theme) => switch (theme.config.language) {
    PureDesignLanguage.fluent => _ShellVisual.fluentPane(),
    PureDesignLanguage.macos => _ShellVisual.sourceList(),
    PureDesignLanguage.cupertino => _ShellVisual.groupedList(),
    PureDesignLanguage.material => _ShellVisual.m3Rail(),
    PureDesignLanguage.yaru => _ShellVisual.ubuntuChips(),
    PureDesignLanguage.forui => _ShellVisual.cardRows(),
    PureDesignLanguage.glass => _ShellVisual.frostedPane(),
    PureDesignLanguage.neumorphic => _ShellVisual.softPane(),
    PureDesignLanguage.wind => _ShellVisual.quietRows(),
  };

  /// The bottom-strip form: the shell delegates to [PureNavBar] — the same
  /// dispatched control a page names — rather than drawing a second strip, so
  /// the two forms cannot drift apart. `leading` and `trailing` have no slot in
  /// a strip and are dropped, as the contract documents.
  Widget _bottomStrip() {
    return Column(
      children: [
        Expanded(child: child),
        PureNavBar(
          items: [
            for (final destination in destinations) PureNavBarItem(label: destination.label, icon: destination.icon),
          ],
          index: destinations.indexWhere((destination) => destination.id == selectedId),
          onChanged: (index) {
            final destination = destinations[index];
            if (destination.enabled) {
              onSelected?.call(destination.id);
            }
          },
        ),
      ],
    );
  }

  /// The rail form: the pane stands beside the page, at least as wide as the
  /// language's rows need. The environment's rail metric decides the
  /// rail-versus-strip *form*; the visual's floor decides that a row never
  /// gets squeezed out of its grammar — the macOS source list documented its
  /// own 154 minimum, and every row-form language now carries one.
  Widget _rail(BuildContext context, PureTheme theme, _ShellVisual visual, Widget body) {
    final railWidth = PureEnvironmentScope.maybeOf(context)?.geometry.railWidth ?? PureSizing.railWidth;
    return Row(
      children: [
        SizedBox(width: visual.widen(railWidth), child: _pane(context, theme, visual)),
        Expanded(child: body),
      ],
    );
  }

  /// The fluent narrow form: the pane is gone — a hamburger strip takes its
  /// place and the nav comes back as an overlay drawer over the full-width
  /// page. The slide, the scrim and the dismissal are painted here; the tween
  /// is the WinUI pane's, and it collapses to zero when animations are off.
  Widget _fluentNarrow(BuildContext context, PureTheme theme, _ShellVisual visual, Widget body) {
    final open = _fluentDrawerOpen;
    return Stack(
      children: [
        Column(
          children: [
            _fluentTopStrip(theme),
            Expanded(child: body),
          ],
        ),
        // The scrim outlives the open state so its fade is the same tween as
        // the drawer's slide; closed, it neither hit-tests nor speaks.
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !open,
            child: ExcludeSemantics(
              child: AnimatedOpacity(
                opacity: open ? 1 : 0,
                duration: theme.duration,
                curve: Curves.easeOut,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _fluentDrawerOpen = false),
                  child: ColoredBox(color: theme.colors.mask),
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: 0,
          bottom: 0,
          start: 0,
          width: visual.drawerWidth,
          child: IgnorePointer(
            ignoring: !open,
            child: ExcludeSemantics(
              excluding: !open,
              child: AnimatedSlide(
                // The closed drawer rests fully off-stage to the start.
                offset: open ? Offset.zero : const Offset(-1, 0),
                duration: theme.duration,
                curve: Curves.easeOutCubic,
                child: _pane(context, theme, visual),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The pane column every form shares: head slot, scrolling destination list
  /// (a sidebar that cannot scroll is not a sidebar), foot slot — dressed by
  /// the language's own surface.
  Widget _pane(BuildContext context, PureTheme theme, _ShellVisual visual) {
    final iconSize = PureEnvironmentScope.maybeOf(context)?.geometry.iconSize ?? 18;
    return visual.pane(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (leading case final Widget head)
            Padding(padding: EdgeInsets.fromLTRB(visual.inset, visual.inset, visual.inset, 0), child: head),
          Expanded(
            child: _ShellRail(
              destinations: destinations,
              selectedId: selectedId,
              select: onSelected,
              visual: visual,
              theme: theme,
              iconSize: iconSize,
            ),
          ),
          if (trailing case final Widget footer)
            Padding(padding: EdgeInsets.fromLTRB(visual.inset, 0, visual.inset, visual.inset), child: footer),
        ],
      ),
    );
  }

  /// The narrow form's top strip: the hamburger that summons the overlay
  /// drawer, over the language's own pane surface under a hairline — the
  /// NavigationView's chrome bar, painted from the tokens.
  Widget _fluentTopStrip(PureTheme theme) {
    return SizedBox(
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.bgContainer,
          border: Border(bottom: BorderSide(color: theme.colors.borderSecondary)),
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: _DrawerButton(
              key: const ValueKey('PureAppShell.drawer-toggle'),
              onPressed: () => setState(() => _fluentDrawerOpen = true),
              semanticLabel: '菜单',
              theme: theme,
            ),
          ),
        ),
      ),
    );
  }
}

/// The shell's one visual value class: how a language paints the pane it
/// stands on, the rows inside it, and the selection that names one of them.
/// Mirrors the control-layer idiom (see `pure_tab_bar.dart`'s `_BarVisual`):
/// geometry and colour arrive as closures, so one row builder serves nine
/// grammars and every difference is data.
@immutable
final class _ShellVisual {
  const new({
    required this.pane,
    required this.rowsStacked,
    required this.minPaneWidth,
    required this.inset,
    required this.rowHeight,
    required this.rowRadius,
    required this.rowFill,
    required this.hoverTint,
    required this.pressedTint,
    required this.content,
    required this.selectedBold,
    required this.separator,
    this.indicator,
    this.overlayWhenNarrow = false,
  });

  /// Fluent: the NavigationView inline pane. A flat surface under a right
  /// hairline; the selected row takes the subtle grey fill and the accent
  /// edge pill — WinUI says "chosen" with the indicator, not with colour, so
  /// the content stays at the plain text roles. The narrow form trades the
  /// pane for the overlay drawer, the grammar this shell painted first.
  factory fluentPane() {
    return _ShellVisual(
      pane: (theme, body) => DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.bgContainer,
          border: Border(right: BorderSide(color: theme.colors.borderSecondary)),
        ),
        child: body,
      ),
      rowsStacked: false,
      minPaneWidth: 200,
      inset: 4,
      rowHeight: 36,
      rowRadius: BorderRadius.circular(PureRadii.xs),
      rowFill: (theme, {required active}) =>
          BoxDecoration(color: active ? theme.colors.fillTertiary : theme.colors.fillQuaternary),
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      content: plainContent,
      selectedBold: false,
      separator: false,
      indicator: (theme) => _FluentEdgePill(color: theme.colors.primary),
      overlayWhenNarrow: true,
    );
  }

  /// macOS: the source list. Rows ride the container colour under the hairline
  /// split, 28 logical pixels to a row — the library's own density — and the
  /// selection is the solid accent chip with the content knocked out of it.
  /// The chip's corner is the source list's squircle-soft 6, not a pill.
  factory sourceList() {
    return _ShellVisual(
      pane: (theme, body) => DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.bgContainer,
          border: Border(right: BorderSide(color: theme.colors.borderSecondary)),
        ),
        child: body,
      ),
      rowsStacked: false,
      minPaneWidth: 154,
      inset: 10,
      rowHeight: 28,
      rowRadius: BorderRadius.circular(PureRadii.xs + 2),
      rowFill: (theme, {required active}) => BoxDecoration(color: active ? theme.colors.primary : theme.colors.fillSecondary),
      hoverTint: (theme) => theme.colors.textSecondary.withValues(alpha: 0.12),
      pressedTint: (theme) => theme.colors.textSecondary.withValues(alpha: 0.18),
      content: contentOnChip,
      selectedBold: false,
      separator: false,
    );
  }

  /// Cupertino: the grouped list. The pane is the grouped background under a
  /// hairline; rows are 44-grammar cells divided by separators that start
  /// where the glyph ends — the inset-grouped answer iOS draws — and the
  /// selection is the rounded grey chip with the label in the accent and the
  /// weight to match.
  factory groupedList() {
    return _ShellVisual(
      pane: (theme, body) => DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.bgLayout,
          border: Border(right: BorderSide(color: theme.colors.borderSecondary)),
        ),
        child: body,
      ),
      rowsStacked: false,
      minPaneWidth: 154,
      inset: 10,
      rowHeight: 44,
      rowRadius: BorderRadius.circular(PureRadii.sm),
      rowFill: (theme, {required active}) =>
          BoxDecoration(color: active ? theme.colors.fillSecondary : theme.colors.fillQuaternary),
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      content: (theme, {required selected, required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (selected) {
          return theme.colors.primaryText;
        }
        return theme.colors.text;
      },
      selectedBold: true,
      separator: true,
    );
  }

  /// Material: the M3 navigation rail. The pane is flat on the container
  /// colour — the rail carries no border — and the cell stacks the glyph over
  /// a 12-label; the selection is the primary-tinted pill behind the glyph
  /// alone, the glyph and label inked in the accent. Flutter's own rail
  /// grammar rebuilt on the tokens, so it survives a test binding that never
  /// installed a Material theme.
  factory m3Rail() {
    return _ShellVisual(
      pane: (theme, body) => ColoredBox(color: theme.colors.bgContainer, child: body),
      rowsStacked: true,
      minPaneWidth: 72,
      inset: 4,
      rowHeight: 72,
      rowRadius: BorderRadius.circular(PureRadii.pill),
      rowFill: (theme, {required active}) => BoxDecoration(color: active ? theme.colors.primaryBg : theme.colors.fillTertiary),
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      content: (theme, {required selected, required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (selected) {
          return theme.colors.primary;
        }
        return theme.colors.textSecondary;
      },
      selectedBold: false,
      separator: false,
    );
  }

  /// Yaru: the Ubuntu side panel. Flat on the layout colour, roomy rounded
  /// chips; the selected row is a pale grey pill with the label out front and
  /// the accent never used as a fill — Yaru reserves it for the icon's mood
  /// and the window itself.
  factory ubuntuChips() {
    return _ShellVisual(
      pane: (theme, body) => ColoredBox(color: theme.colors.bgLayout, child: body),
      rowsStacked: false,
      minPaneWidth: 176,
      inset: 8,
      rowHeight: 40,
      rowRadius: BorderRadius.circular(PureRadii.sm),
      rowFill: (theme, {required active}) => BoxDecoration(color: active ? theme.colors.fill : theme.colors.fillQuaternary),
      hoverTint: (theme) => theme.colors.fillTertiary,
      pressedTint: (theme) => theme.colors.fillSecondary,
      content: (theme, {required selected, required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (selected) {
          return theme.colors.text;
        }
        return theme.colors.textSecondary;
      },
      selectedBold: false,
      separator: false,
    );
  }

  /// forui: the shadcn sidebar. The pane is the container under its full
  /// `border` hairline; a row is a quiet ghost cell that rises to an elevated,
  /// bordered card when chosen — the sidebar item's own state ramp, painted on
  /// the tokens instead of the library's theme data.
  factory cardRows() {
    return _ShellVisual(
      pane: (theme, body) => DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.bgContainer,
          border: Border(right: BorderSide(color: theme.colors.border)),
        ),
        child: body,
      ),
      rowsStacked: false,
      minPaneWidth: 216,
      inset: 12,
      rowHeight: 40,
      rowRadius: BorderRadius.circular(PureRadii.sm),
      rowFill: (theme, {required active}) => BoxDecoration(
        color: active ? theme.colors.bgElevated : theme.colors.fillQuaternary,
        border: active ? Border.all(color: theme.colors.border) : null,
        boxShadow: active
            ? [BoxShadow(color: theme.colors.shadowBase, blurRadius: 4, offset: const Offset(0, 1))]
            : null,
      ),
      hoverTint: (theme) => theme.colors.fillTertiary,
      pressedTint: (theme) => theme.colors.fill,
      content: (theme, {required selected, required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (selected) {
          return theme.colors.text;
        }
        if (pressed || hovered) {
          return theme.colors.text;
        }
        return theme.colors.textSecondary;
      },
      selectedBold: true,
      separator: false,
    );
  }

  /// Glass: the frosted pane. A real backdrop blur where the `canBlur` policy
  /// affords one, a translucent slab under a light hairline, and the gradient
  /// accent pill for the selection with the primary glow beneath it — the
  /// language's two signatures, drawn exactly as the tab bar draws its own.
  factory frostedPane() {
    Color hairline(PureTheme theme) =>
        theme.isDark ? theme.colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.7);
    return _ShellVisual(
      pane: (theme, body) {
        final decorated = DecoratedBox(
          decoration: BoxDecoration(
            color: theme.isDark
                ? theme.colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.55),
            border: Border(right: BorderSide(color: hairline(theme))),
          ),
          child: body,
        );
        if (!theme.canBlur) {
          return decorated;
        }
        return ClipRect(
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: decorated),
        );
      },
      rowsStacked: false,
      minPaneWidth: 176,
      inset: 10,
      rowHeight: 36,
      rowRadius: BorderRadius.circular(PureRadii.pill),
      rowFill: (theme, {required active}) {
        if (!active) {
          return BoxDecoration(color: theme.colors.fill.withValues(alpha: 0.5));
        }
        return BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [theme.colors.primary, Color.lerp(theme.colors.primary, theme.colors.link, 0.35)!],
          ),
          borderRadius: BorderRadius.circular(PureRadii.pill),
          boxShadow: [
            BoxShadow(color: theme.colors.primary.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        );
      },
      hoverTint: (theme) =>
          theme.isDark ? theme.colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
      pressedTint: (theme) =>
          theme.isDark ? theme.colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
      content: contentOnChip,
      selectedBold: false,
      separator: false,
    );
  }

  /// Neumorphic: the soft pane. The whole rail is one raised slab — light
  /// from the top-left, shadow from the bottom-right, no borders anywhere —
  /// and the selected row *sinks* into it, the slab's shadows inverted; the
  /// same pressed-in answer the tab bar's pill gives.
  factory softPane() {
    List<BoxShadow> raised(PureTheme theme) => [
      BoxShadow(color: theme.colors.shadowBase, blurRadius: 8, offset: const Offset(4, 4)),
      BoxShadow(
        color: theme.colors.white.withValues(alpha: theme.isDark ? 0.04 : 0.7),
        blurRadius: 8,
        offset: const Offset(-4, -4),
      ),
    ];
    List<BoxShadow> sunk(PureTheme theme) => [
      for (final shadow in raised(theme))
        BoxShadow(color: shadow.color, blurRadius: shadow.blurRadius, offset: -shadow.offset),
    ];
    return _ShellVisual(
      pane: (theme, body) => Padding(
        padding: const EdgeInsets.all(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colors.bgContainer,
            borderRadius: BorderRadius.circular(PureRadii.md),
            boxShadow: raised(theme),
          ),
          child: body,
        ),
      ),
      rowsStacked: false,
      minPaneWidth: 154,
      inset: 8,
      rowHeight: 40,
      rowRadius: BorderRadius.circular(PureRadii.pill),
      rowFill: (theme, {required active}) => BoxDecoration(
        color: active ? theme.colors.primaryBg : theme.colors.fillQuaternary,
        boxShadow: active ? sunk(theme) : null,
      ),
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      content: (theme, {required selected, required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (selected) {
          return theme.colors.primary;
        }
        if (pressed || hovered) {
          return theme.colors.text;
        }
        return theme.colors.textSecondary;
      },
      selectedBold: false,
      separator: false,
    );
  }

  /// Wind: the quiet Harmony rows. A flat surfaceless column — the pane takes
  /// the window colour and asks for no border and no hairline — with a wide
  /// rounded chip on the selected row and the label taking the bold weight a
  /// Harmony sidebar uses to say "you are here" without an accent fill.
  factory quietRows() {
    return _ShellVisual(
      pane: (theme, body) => ColoredBox(color: theme.colors.bgLayout, child: body),
      rowsStacked: false,
      minPaneWidth: 176,
      inset: 12,
      rowHeight: 44,
      rowRadius: BorderRadius.circular(PureRadii.md),
      rowFill: (theme, {required active}) => BoxDecoration(color: active ? theme.colors.fill : theme.colors.fillQuaternary),
      hoverTint: (theme) => theme.colors.fillTertiary,
      pressedTint: (theme) => theme.colors.fillSecondary,
      content: (theme, {required selected, required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (selected) {
          return theme.colors.primaryText;
        }
        return theme.colors.text;
      },
      selectedBold: true,
      separator: false,
    );
  }

  /// Wraps the row column: the pane's surface, border, blur, shadow — whatever
  /// the language puts under the rows.
  final Widget Function(PureTheme theme, Widget body) pane;

  /// Whether the cell stacks icon-over-label (the M3 rail) or lays them side
  /// by side (every source-list grammar).
  final bool rowsStacked;

  /// The narrowest this language's pane will be: the caller's rail metric
  /// decides the form, this decides that a row never gets squeezed out of its
  /// grammar.
  final double minPaneWidth;

  /// The pane's own inset: head and foot padding and the list's horizontal
  /// padding, so the rows and the slots share one margin.
  final double inset;

  /// The row's minimum height.
  final double rowHeight;

  /// The corner radius of a row's fill, tint and focus ring.
  final BorderRadius rowRadius;

  /// The selected row's decoration; the `active` flag separates the live
  /// selection from the grey one an inert shell (or a disabled selection)
  /// shows.
  final BoxDecoration Function(PureTheme theme, {required bool active}) rowFill;

  /// The tint behind a hovered, unselected row.
  final Color? Function(PureTheme theme) hoverTint;

  /// The tint behind a pressed row.
  final Color? Function(PureTheme theme) pressedTint;

  /// The content colour in each state.
  final Color Function(
    PureTheme theme, {
    required bool selected,
    required bool hovered,
    required bool pressed,
    required bool enabled,
  })
  content;

  /// Whether the selected row's label takes the bold weight.
  final bool selectedBold;

  /// Whether rows are divided by the grouped-list hairline — Cupertino's
  /// `CupertinoListSection` answer, painted from `borderSecondary`.
  final bool separator;

  /// The widget painted at a selected row's start edge (the Fluent accent
  /// pill); null for the grammars that carry no indicator.
  final Widget Function(PureTheme theme)? indicator;

  /// Whether this language trades the inline pane for an overlay drawer below
  /// the mobile breakpoint (only Fluent — the NavigationView grammar).
  final bool overlayWhenNarrow;

  /// The overlay drawer's width for [overlayWhenNarrow] languages: the
  /// NavigationView's expanded pane.
  double get drawerWidth => 240;

  /// The pane's width for a requested rail width.
  double widen(double requested) => requested < minPaneWidth ? minPaneWidth : requested;

  /// The content colours the filled-chip grammars share: knocked out on the
  /// fill, the text roles elsewhere, quaternary when the row is disabled.
  static Color contentOnChip(
    PureTheme theme, {
    required bool selected,
    required bool hovered,
    required bool pressed,
    required bool enabled,
  }) {
    if (!enabled) {
      return theme.colors.textQuaternary;
    }
    if (selected) {
      return theme.colors.textLightSolid;
    }
    if (pressed || hovered) {
      return theme.colors.text;
    }
    return theme.colors.textSecondary;
  }

  /// The content colours the indicator-led grammar uses: the row never
  /// changes colour when selected — the accent pill says it instead.
  static Color plainContent(
    PureTheme theme, {
    required bool selected,
    required bool hovered,
    required bool pressed,
    required bool enabled,
  }) {
    if (!enabled) {
      return theme.colors.textQuaternary;
    }
    if (pressed || hovered) {
      return theme.colors.text;
    }
    return theme.colors.textSecondary;
  }
}

/// The pane's destination list with the keyboard contract: vertical traversal
/// that skips disabled destinations, Enter/Space/Select activation, and focus
/// nodes that outlive a rebuild only until the frame's end. Mirrors
/// `pure_tab_bar.dart`'s `_SlidingTabBar` state, because every interactive
/// chrome in the kit answers to one keyboard and remote contract.
class _ShellRail extends StatefulWidget {
  const new({
    required this.destinations,
    required this.selectedId,
    required this.select,
    required this.visual,
    required this.theme,
    required this.iconSize,
  });

  final List<PureShellDestination> destinations;

  final String? selectedId;

  final ValueChanged<String>? select;

  final _ShellVisual visual;

  final PureTheme theme;

  final double iconSize;

  @override
  State<_ShellRail> createState() => _ShellRailState();
}

class _ShellRailState extends State<_ShellRail> {
  List<FocusNode> _focusNodes = const [];

  @override
  void initState() {
    super.initState();
    _rebuildNodes();
  }

  @override
  void didUpdateWidget(covariant _ShellRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destinations.length != widget.destinations.length) {
      _rebuildNodes();
    }
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _rebuildNodes() {
    // The old nodes are still attached until this rebuild lands, so their
    // disposal waits for the frame's end — the tab bar's own answer.
    final retired = _focusNodes;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final node in retired) {
        node.dispose();
      }
    });
    _focusNodes = [
      for (final destination in widget.destinations) FocusNode(debugLabel: 'PureAppShell.row.${destination.id}'),
    ];
  }

  /// Whether the shell is live at all; a shell with no callback draws grey
  /// selections and refuses traversal.
  bool get _active => widget.select != null;

  /// Focuses the nearest enabled row in [direction]; reports whether one was
  /// found, so a pane at its edge hands the key back to the window.
  bool _moveFocus(int from, int direction) {
    if (!_active) {
      return false;
    }
    var next = from + direction;
    while (next >= 0 && next < widget.destinations.length) {
      if (widget.destinations[next].enabled) {
        _focusNodes[next].requestFocus();
        return true;
      }
      next += direction;
    }
    return false;
  }

  KeyEventResult _handleKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      return _moveFocus(index, -1) ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      return _moveFocus(index, 1) ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    final activate = {
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.gameButtonA,
    };
    if (activate.contains(event.logicalKey)) {
      // A disabled destination must never be activated through a keyboard or
      // TV remote, even if focus was retained while it became disabled.
      final destination = widget.destinations[index];
      if (_active && destination.enabled) {
        widget.select?.call(destination.id);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final visual = widget.visual;
    final theme = widget.theme;
    final count = widget.destinations.length;
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: visual.inset, vertical: visual.inset),
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0 && visual.separator)
            // The inset-grouped hairline: it starts where the glyph ends, the
            // way iOS divides a sidebar's rows, on the token's own line width.
            Container(
              height: theme.token.motion.lineWidth,
              color: theme.colors.borderSecondary,
              margin: EdgeInsetsDirectional.only(start: visual.inset + widget.iconSize + 18),
            ),
          _ShellCell(
            key: ValueKey('PureAppShell.row.${widget.destinations[i].id}'),
            destination: widget.destinations[i],
            selected: widget.destinations[i].id == widget.selectedId && _active,
            shellActive: _active,
            visual: visual,
            theme: theme,
            iconSize: widget.iconSize,
            focusNode: _focusNodes[i],
            onKeyEvent: (node, event) => _handleKey(i, event),
            onTap: () => widget.select?.call(widget.destinations[i].id),
          ),
        ],
      ],
    );
  }
}

/// One destination row: interaction states (hover, pressed, focus, disabled),
/// the language's fill and indicator, and the semantics that name it for a
/// screen reader. Shared by all nine grammars — only [_ShellVisual] differs.
class _ShellCell extends StatefulWidget {
  const new({
    required this.destination,
    required this.selected,
    required this.shellActive,
    required this.visual,
    required this.theme,
    required this.iconSize,
    required this.focusNode,
    required this.onKeyEvent,
    required this.onTap,
    super.key,
  });

  final PureShellDestination destination;

  final bool selected;

  /// Whether the shell has a callback at all; an inert shell greys every row.
  final bool shellActive;

  final _ShellVisual visual;

  final PureTheme theme;

  final double iconSize;

  final FocusNode focusNode;

  final KeyEventResult Function(FocusNode node, KeyEvent event) onKeyEvent;

  final VoidCallback onTap;

  @override
  State<_ShellCell> createState() => _ShellCellState();
}

class _ShellCellState extends State<_ShellCell> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.destination.enabled && widget.shellActive;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final visual = widget.visual;
    final destination = widget.destination;
    final enabled = _enabled;
    final selected = widget.selected;
    final color = visual.content(
      theme,
      selected: selected,
      hovered: _hovered,
      pressed: _pressed,
      enabled: enabled,
    );
    final tint = !selected && enabled
        ? (_pressed
              ? visual.pressedTint(theme)
              : _hovered
              ? visual.hoverTint(theme)
              : null)
        : null;
    // The row's live decoration: the language's selection when chosen, the
    // interaction tint otherwise. The radius is applied here so a factory's
    // fill never has to remember it.
    final decoration = (selected
            ? visual.rowFill(theme, active: enabled)
            : BoxDecoration(color: tint)).copyWith(borderRadius: visual.rowRadius);

    final label = Text(
      destination.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.text.bodySmall.copyWith(
        color: color,
        fontWeight: selected && visual.selectedBold ? FontWeight.w600 : FontWeight.w400,
      ),
    );
    final icon = Icon(destination.icon, size: visual.rowsStacked ? 24 : widget.iconSize, color: color);

    final Widget row;
    if (visual.rowsStacked) {
      // The M3 rail cell: the pill rides behind the glyph alone and the label
      // sits under the whole cell.
      row = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: theme.duration,
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: decoration,
            child: icon,
          ),
          const SizedBox(height: 4),
          label,
        ],
      );
    } else {
      final indicator = visual.indicator;
      row = AnimatedContainer(
        duration: theme.duration,
        curve: Curves.easeOut,
        constraints: BoxConstraints(minHeight: visual.rowHeight),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: decoration,
        child: Row(
          children: [
            // The indicator slot holds its width whether filled or not, so a
            // row never shifts when its neighbour becomes the selection.
            if (indicator != null)
              SizedBox(
                width: 12,
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: theme.duration,
                  curve: Curves.easeOut,
                  child: indicator(theme),
                ),
              ),
            icon,
            const SizedBox(width: 8),
            Flexible(child: label),
          ],
        ),
      );
    }

    return Focus(
      focusNode: widget.focusNode,
      canRequestFocus: enabled,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (node, event) => widget.onKeyEvent(node, event),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled
              ? (_) {
                  widget.focusNode.requestFocus();
                  setState(() => _pressed = true);
                }
              : null,
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: enabled ? widget.onTap : null,
          child: Semantics(
            button: true,
            selected: selected,
            enabled: enabled,
            label: destination.label,
            child: ExcludeSemantics(
              child: AnimatedScale(
                // The TV answer: the focused row grows a touch, and the ring
                // below names it for keyboard and remote users alike.
                scale: _focused ? 1.02 : 1,
                duration: theme.duration,
                curve: Curves.easeOut,
                child: DecoratedBox(
                  // The focus ring is a *static* foreground: AnimatedContainer
                  // tweens `foregroundDecoration` through an illegal lerp when
                  // a hairline trades places with a ring and throws
                  // mid-flight — the pitfall `pure_tab_bar.dart` documents for
                  // every interactive chrome in the house.
                  decoration: _focused
                      ? BoxDecoration(
                          borderRadius: visual.rowRadius,
                          border: Border.fromBorderSide(
                            BorderSide(color: theme.colors.primary, width: theme.token.motion.lineWidthFocus),
                          ),
                        )
                      : const BoxDecoration(),
                  position: DecorationPosition.foreground,
                  child: row,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Fluent selection indicator: the accent pill at the row's start edge,
/// 3 logical pixels wide and 16 tall under WinUI's own proportions. The
/// selected state rides on the caller's opacity tween.
class _FluentEdgePill extends StatelessWidget {
  const new({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 16,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1.5)),
    );
  }
}

/// The narrow form's hamburger: the caption button the overlay drawer answers
/// to, with the same hover/pressed tints every interactive chrome in the kit
/// keeps — painted, not borrowed from fluent_2.
class _DrawerButton extends StatefulWidget {
  const new({required this.onPressed, required this.semanticLabel, required this.theme, super.key});

  final VoidCallback onPressed;

  final String semanticLabel;

  final PureTheme theme;

  @override
  State<_DrawerButton> createState() => _DrawerButtonState();
}

class _DrawerButtonState extends State<_DrawerButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final tint = _pressed ? theme.colors.fillSecondary : _hovered ? theme.colors.fill : null;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: ExcludeSemantics(
            child: AnimatedContainer(
              duration: theme.duration,
              curve: Curves.easeOut,
              width: 36,
              height: 32,
              alignment: AlignmentDirectional.center,
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(PureRadii.xs)),
              child: Icon(Icons.menu, size: 16, color: theme.colors.text),
            ),
          ),
        ),
      ),
    );
  }
}
