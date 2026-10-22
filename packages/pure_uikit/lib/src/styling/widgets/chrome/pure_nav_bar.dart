import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pure_uikit/src/scales/radii.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// One destination of a bottom navigation bar: what it is called and the glyph
/// that says so. A label is required — an icon-only bar asks a user to memorise
/// five glyphs, which is why the platform bars carry text by default.
///
/// [enabled] is the per-destination answer the shell asks for: a destination
/// that no longer applies greys out, swallows taps and is skipped by keyboard
/// traversal, while the rest of the bar stays live.
@immutable
final class PureNavBarItem {
  /// A destination labelled [label] with [icon].
  const new({required this.label, required this.icon, this.enabled = true});

  /// The destination's name.
  final String label;

  /// The destination's glyph.
  final IconData icon;

  /// Whether the destination responds to input; a disabled destination greys
  /// out, ignores taps and keys, and is skipped by arrow traversal.
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is PureNavBarItem && other.label == label && other.icon == icon && other.enabled == enabled;

  @override
  int get hashCode => Object.hash(label, icon, enabled);
}

/// The kit's bottom navigation bar: one widget, every design language, all of
/// it painted here.
///
/// A shell passes its destinations here instead of a platform bar, so the
/// bottom of the screen re-skins with the rest of it. Every language draws its
/// own real grammar from the tokens: iOS 18's translucent tab bar (a blurred
/// strip over a hairline, the chosen glyph and label in the tint, no shape
/// behind them), macOS's toolbar-adjacent strip (even icon-over-label cells,
/// the chosen one on a soft accent chip like the sidebar rows it shares),
/// WinUI's NavigationView footer (compact two-line cells under the 6x3 accent
/// pill at the bar's top edge), Material 3's NavigationBar (a tonal pill behind
/// the chosen icon on an 80dp surface), Yaru's flat Ubuntu strip (a rounded
/// highlight behind the accent glyph, no gradient anywhere), shadcn/forui's
/// muted rail (a subdued strip, the chosen icon in an accent circle), a
/// frosted glass bar with a gradient pill, a raised neumorphic rail whose
/// chosen cell presses into it, and a crisp wind strip with a hairline accent
/// dash on the bottom edge. The libraries ship no bar that can slide between
/// grammars — several ship no bar at all — and the point of this widget is the
/// one selection that travels between cells under every skin, so nothing is
/// delegated; colours, radii, motion and text come from [PureTheme], so a
/// language re-skin and a dark switch still come out right.
///
/// Every visual answers to the same interaction contract: hover and pressed
/// tints, an inert bar (a null [onChanged] or `enabled: false`) that answers
/// nothing and greys its selection, disabled destinations, focus rings and
/// Left/Right traversal with Enter/Space selection for keyboards and remotes,
/// screen-reader traits on every cell (each reads as a button that is or is
/// not selected) inside a container, and a mark that slides to the chosen
/// destination over the theme's motion duration. The bar fills the width it is
/// given and carries its own height per language — give a call site only a
/// width, and it splits that width into equal cells.
class PureNavBar extends StatelessWidget {
  /// A bar over [items] with [index] selected.
  const new({required this.items, required this.index, this.onChanged, this.enabled = true, super.key});

  /// The destinations, in order.
  final List<PureNavBarItem> items;

  /// The selected destination. An index outside the list is clamped into it,
  /// so a shell whose selection has not landed yet still draws a bar.
  final int index;

  /// Called with a destination's index when it is chosen; null renders the bar
  /// inert.
  final ValueChanged<int>? onChanged;

  /// Whether the bar responds to input; false greys every cell out.
  final bool enabled;

  /// The design language's reading of the bar, resolved once from the theme so
  /// every state below sees the same value a rebuild would re-derive anyway.
  _NavVisual _resolveVisual(PureTheme theme) => switch (theme.config.language) {
    // Material 3's own NavigationBar grammar: the tonal pill behind the icon.
    PureDesignLanguage.material => _NavVisual.material3(),
    // iOS 18: translucent strip, tinted glyph, no shape at all.
    PureDesignLanguage.cupertino => _NavVisual.ios(),
    // macOS: the sidebar-row chip under the chosen icon on a chrome strip.
    PureDesignLanguage.macos => _NavVisual.macosRail(),
    // WinUI's footer items: the 6x3 pill at the bar's top edge.
    PureDesignLanguage.fluent => _NavVisual.fluentFooter(),
    // Ubuntu's flat strip: a rounded highlight, no glow.
    PureDesignLanguage.yaru => _NavVisual.yaruFlat(),
    // shadcn's muted rail: an accent circle behind the chosen icon.
    PureDesignLanguage.forui => _NavVisual.shadcnRail(),
    PureDesignLanguage.glass => _NavVisual.glass(),
    PureDesignLanguage.neumorphic => _NavVisual.neumorphic(),
    // Huawei's crisp strip: a hairline accent dash on the bottom edge.
    PureDesignLanguage.wind => _NavVisual.windCrisp(),
  };

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = PureTheme.of(context);
    // A null callback is every platform's inert state, so folding `enabled`
    // into it once serves every language.
    final select = enabled ? onChanged : null;
    final bar = _NavBarBody(
      items: items,
      index: index,
      select: select,
      language: theme.config.language,
      visual: _resolveVisual(theme),
    );
    // The strip is one container of destinations, not loose buttons; the
    // container role lets a screen reader announce the whole bar.
    return Semantics(container: true, child: bar);
  }
}

/// Where the language's selection mark sits relative to the measured cell:
/// behind the whole cell, behind just the icon, on the bar's top or bottom
/// edge, or nowhere at all (the tint is iOS's only answer).
enum _NavMark { none, cell, icon, topEdge, bottomEdge }

/// How one design language paints the bar: its own height and surface, the
/// sliding mark, the interaction tints, and the colour of a cell's content in
/// each state. The sizes are absolute pixels — a platform bar keeps its height
/// whatever the tokens say — while colours, radii and text ride the theme.
@immutable
final class _NavVisual {
  const new({
    required this.height,
    required this.inset,
    required this.iconSize,
    required this.fontSize,
    required this.mark,
    required this.cellRadius,
    required this.track,
    required this.indicator,
    required this.hoverTint,
    required this.pressedTint,
    required this.content,
    this.markInset = EdgeInsets.zero,
    this.markSize = Size.zero,
  });

  /// Material 3's `NavigationBar`: an 80dp elevated strip over a hairline with
  /// a tonal pill behind the chosen icon — the one shape M3 navigation answers
  /// selection with.
  factory material3() {
    return _NavVisual(
      height: 80,
      inset: EdgeInsets.zero,
      iconSize: 24,
      fontSize: 12,
      mark: _NavMark.icon,
      markInset: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      cellRadius: BorderRadius.circular(PureRadii.md),
      track: (theme, frame) => _NavVisual.surface(theme, frame, color: theme.colors.bgElevated),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.colors.primaryBg : theme.colors.fillTertiary,
        borderRadius: BorderRadius.circular(PureRadii.pill),
      ),
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      content: (theme, {required selected, required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (selected) {
          return theme.colors.primaryText;
        }
        if (pressed || hovered) {
          return theme.colors.text;
        }
        return theme.colors.textSecondary;
      },
    );
  }

  /// iOS 18's tab bar: a translucent strip — a real backdrop blur when the
  /// device can afford it — under a hairline separator, the chosen glyph and
  /// label in the tint and nothing else. The mark enum is [_NavMark.none]:
  /// iOS answers selection with colour alone, and an invented pill would say
  /// Android.
  factory ios() {
    return _NavVisual(
      height: 49,
      inset: EdgeInsets.zero,
      iconSize: 26,
      fontSize: 10,
      mark: _NavMark.none,
      cellRadius: BorderRadius.circular(PureRadii.sm),
      track: (theme, frame) {
        final frost = DecoratedBox(
          decoration: BoxDecoration(
            color: theme.isDark
                ? theme.colors.bgElevated.withValues(alpha: 0.72)
                : Colors.white.withValues(alpha: 0.72),
            border: Border(top: BorderSide(color: theme.colors.borderSecondary)),
          ),
          child: SafeArea(top: false, left: false, right: false, child: frame),
        );
        if (!theme.canBlur) {
          return frost;
        }
        return ClipRect(
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24), child: frost),
        );
      },
      indicator: (_, {required active}) => const BoxDecoration(),
      // The strip answers a hover in the tint alone, as iOS does.
      hoverTint: (_) => null,
      pressedTint: (_) => null,
      content: (theme, {required selected, required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (selected) {
          return theme.colors.primary;
        }
        return theme.colors.textTertiary;
      },
    );
  }

  /// macOS's toolbar-adjacent strip: the chrome surface under a hairline, even
  /// compact cells, and the chosen glyph on a soft accent chip — the same
  /// answer the library's sidebar rows give, sized for the 52pt bar the widget
  /// drew before.
  factory macosRail() {
    return _NavVisual(
      height: 52,
      inset: EdgeInsets.zero,
      iconSize: 16,
      fontSize: 10.5,
      mark: _NavMark.icon,
      markInset: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      cellRadius: BorderRadius.circular(PureRadii.sm),
      track: (theme, frame) => _NavVisual.surface(theme, frame, color: theme.colors.bgElevated),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.colors.primaryBg : theme.colors.fillTertiary,
        borderRadius: BorderRadius.circular(PureRadii.sm),
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
    );
  }

  /// WinUI's NavigationView footer: two-line compact cells on the chrome
  /// surface under a hairline, the chosen one in the accent with the 6x3 pill
  /// at the bar's top edge — the bar the Store and Media Player draw, and the
  /// one this widget drew before, now with the pill sliding between cells.
  factory fluentFooter() {
    return _NavVisual(
      height: 48,
      inset: EdgeInsets.zero,
      iconSize: 16,
      fontSize: 12,
      mark: _NavMark.topEdge,
      markSize: const Size(6, 3),
      cellRadius: BorderRadius.circular(PureRadii.xs),
      track: (theme, frame) => _NavVisual.surface(theme, frame, color: theme.colors.bgElevated),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.colors.primary : theme.colors.fillTertiary,
        borderRadius: BorderRadius.circular(1.5),
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
    );
  }

  /// Ubuntu's flat strip: the container surface under a hairline, no gradient
  /// and no glow, and a rounded highlight behind the chosen glyph — the
  /// checked-button answer Yaru gives a selected tab, with the same rounder
  /// container the tab bar's Yaru branch asks for.
  factory yaruFlat() {
    return _NavVisual(
      height: 56,
      inset: EdgeInsets.zero,
      iconSize: 22,
      fontSize: 11,
      mark: _NavMark.icon,
      markInset: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      cellRadius: BorderRadius.circular(PureRadii.sm),
      track: (theme, frame) => _NavVisual.surface(theme, frame, color: theme.colors.bgContainer),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.colors.fill : theme.colors.fillTertiary,
        borderRadius: BorderRadius.circular(theme.token.scale.radii.lg),
      ),
      hoverTint: (theme) => theme.colors.fillSecondary,
      pressedTint: (theme) => theme.colors.fillTertiary,
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
    );
  }

  /// shadcn's muted rail: the container surface under a hairline and the
  /// chosen glyph in an accent circle — the `bg-primary text-primary` pill the
  /// library's own bottom-navigation recipe draws, kept muted on the rail.
  factory shadcnRail() {
    return _NavVisual(
      height: 64,
      inset: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      iconSize: 20,
      fontSize: 12,
      mark: _NavMark.icon,
      markInset: const EdgeInsets.all(9),
      cellRadius: BorderRadius.circular(PureRadii.sm),
      track: (theme, frame) => _NavVisual.surface(theme, frame, color: theme.colors.bgContainer),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.colors.primaryBg : theme.colors.fillTertiary,
        borderRadius: BorderRadius.circular(PureRadii.pill),
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
    );
  }

  /// The glass language: a frosted strip (a real backdrop blur when the device
  /// can afford it) under a light edge, with a gradient accent pill sliding
  /// behind the chosen cell.
  factory glass() {
    Color tint(PureTheme theme, double alpha) =>
        theme.isDark ? Colors.white.withValues(alpha: alpha) : Colors.black.withValues(alpha: alpha);
    return _NavVisual(
      height: 64,
      inset: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      iconSize: 22,
      fontSize: 11,
      mark: _NavMark.cell,
      markInset: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      cellRadius: BorderRadius.circular(PureRadii.pill),
      track: (theme, frame) {
        final frost = DecoratedBox(
          decoration: BoxDecoration(
            color: theme.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.55),
            border: Border(
              top: BorderSide(
                color: theme.isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
          child: SafeArea(top: false, left: false, right: false, child: frame),
        );
        if (!theme.canBlur) {
          return frost;
        }
        return ClipRect(
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: frost),
        );
      },
      indicator: (theme, {required active}) {
        if (!active) {
          return BoxDecoration(color: theme.colors.fill, borderRadius: BorderRadius.circular(PureRadii.pill));
        }
        return BoxDecoration(
          borderRadius: BorderRadius.circular(PureRadii.pill),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [theme.colors.primary, Color.lerp(theme.colors.primary, theme.colors.link, 0.35)!],
          ),
          boxShadow: [
            BoxShadow(color: theme.colors.primary.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        );
      },
      hoverTint: (theme) => tint(theme, 0.06),
      pressedTint: (theme) => tint(theme, 0.1),
      content: contentOnPill,
    );
  }

  /// The neumorphic language: a raised rail (light from the top left, shadow
  /// from the bottom right) whose chosen cell presses into it — the reversed
  /// shadows the sliding control's track gives its thumb.
  factory neumorphic() {
    List<BoxShadow> raised(PureTheme theme) => [
      BoxShadow(color: theme.colors.shadowBase, blurRadius: 6, offset: const Offset(3, 3)),
      BoxShadow(
        color: theme.colors.white.withValues(alpha: theme.isDark ? 0.04 : 0.8),
        blurRadius: 6,
        offset: const Offset(-3, -3),
      ),
    ];
    List<BoxShadow> sunk(PureTheme theme) => [
      for (final shadow in raised(theme))
        BoxShadow(color: shadow.color, blurRadius: shadow.blurRadius, offset: -shadow.offset),
    ];
    return _NavVisual(
      height: 64,
      inset: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      iconSize: 22,
      fontSize: 11,
      mark: _NavMark.cell,
      cellRadius: BorderRadius.circular(PureRadii.pill),
      track: (theme, frame) => DecoratedBox(
        decoration: BoxDecoration(color: theme.colors.bgContainer, boxShadow: raised(theme)),
        child: SafeArea(top: false, left: false, right: false, child: frame),
      ),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.colors.bgLayout : theme.colors.fillTertiary,
        borderRadius: BorderRadius.circular(theme.token.scale.radii.lg),
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
    );
  }

  /// The wind answer: a crisp elevated strip under a hairline and a slim
  /// accent dash on the bar's bottom edge under the chosen cell — Huawei's
  /// tab grammar, the bottom-edge sibling of the fluent top pill.
  factory windCrisp() {
    return _NavVisual(
      height: 56,
      inset: EdgeInsets.zero,
      iconSize: 22,
      fontSize: 11,
      mark: _NavMark.bottomEdge,
      markSize: const Size(24, 3),
      cellRadius: BorderRadius.circular(PureRadii.sm),
      track: (theme, frame) => _NavVisual.surface(theme, frame, color: theme.colors.bgElevated),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.colors.primary : theme.colors.fillTertiary,
        borderRadius: BorderRadius.circular(1.5),
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
    );
  }

  /// The bar's own height, absolute pixels: 49 for iOS, 48 for the Windows
  /// footer, 80 for Material 3, and so on — the tiers the platform strips keep
  /// whatever the tokens say about colour.
  final double height;

  /// The padding the frame puts around the strip (and so around the mark).
  final EdgeInsets inset;

  /// The glyph size inside a cell.
  final double iconSize;

  /// The label size, before the theme's font scale.
  final double fontSize;

  /// Where the selection mark sits relative to the measured cell.
  final _NavMark mark;

  /// The corner radius of a cell's hover tint and focus ring.
  final BorderRadius cellRadius;

  /// Wraps the framed strip: surface colour, hairline, blur, safe area —
  /// whatever the language puts around the cells.
  final Widget Function(PureTheme theme, Widget frame) track;

  /// The decoration of the sliding mark, with the `active` flag telling the
  /// language's chosen colour apart from the grey one an inert bar shows.
  final Decoration Function(PureTheme theme, {required bool active}) indicator;

  /// The mark's padding when [mark] is [_NavMark.icon] (inflation around the
  /// measured glyph) or its deflation when it is [_NavMark.cell].
  final EdgeInsets markInset;

  /// The mark's fixed size when it is an edge dash ([_NavMark.topEdge] or
  /// [_NavMark.bottomEdge]).
  final Size markSize;

  /// The tint behind a hovered, unselected cell; null is the languages that
  /// answer a hover in the tint colour alone.
  final Color? Function(PureTheme theme) hoverTint;

  /// The tint behind a pressed cell.
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

  /// The content colours the filled-pill languages share: solid white on the
  /// accent pill, the text roles elsewhere.
  static Color contentOnPill(
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

  /// The shared surface frame: an opaque strip under the hairline that
  /// separates it from the page, its cells above the bottom safe area and the
  /// fill extending through it. The hairline rides the *background* box and is
  /// never animated: a foreground that tweened between a bare border and a
  /// rounded ring would lerp through a non-uniform bordered radius, which
  /// Flutter refuses to paint.
  static Widget surface(PureTheme theme, Widget frame, {required Color color}) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      border: Border(top: BorderSide(color: theme.colors.borderSecondary)),
    ),
    child: SafeArea(top: false, left: false, right: false, child: frame),
  );
}

/// The sliding mark and the cells, shared by every language: it measures the
/// chosen cell after layout, slides the mark there, moves focus with the
/// arrow keys and keeps an inert bar greyed.
class _NavBarBody extends StatefulWidget {
  const new({
    required this.items,
    required this.index,
    required this.select,
    required this.language,
    required this.visual,
  });

  final List<PureNavBarItem> items;

  final int index;

  final ValueChanged<int>? select;

  /// The language being drawn — kept only to name the branch key, so tests
  /// and diagnostics can address the shape a bar is wearing.
  final PureDesignLanguage language;

  final _NavVisual visual;

  @override
  State<_NavBarBody> createState() => _NavBarBodyState();
}

class _NavBarBodyState extends State<_NavBarBody> {
  static const Key _markKey = ValueKey('PureNavBar.mark');
  final GlobalKey _stripKey = GlobalKey();
  List<GlobalKey> _cellKeys = const [];
  List<GlobalKey> _iconKeys = const [];
  List<FocusNode> _focusNodes = const [];
  Rect? _cellRect;
  Rect? _iconRect;

  /// False until the first measurement lands, so the mark appears on the
  /// chosen cell without sliding in from nowhere.
  bool _markPlaced = false;

  @override
  void initState() {
    super.initState();
    _rebuildCells();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant _NavBarBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _rebuildCells();
    }
    _scheduleMeasure();
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// Whether the bar is live.
  bool get _active => widget.select != null;

  int get _selectedIndex => widget.index.clamp(0, widget.items.length - 1);

  /// Whether a destination responds to input: a whole-bar disabled strip, or
  /// an individually disabled destination, does not.
  bool _cellEnabled(int index) => _active && widget.items[index].enabled;

  /// Whether the mark may draw as chosen: an inert bar, or a bar whose chosen
  /// destination is itself disabled, shows the grey selection.
  bool get _markLive => _cellEnabled(_selectedIndex);

  void _rebuildCells() {
    // The old nodes are still attached until this rebuild lands, so their
    // disposal waits for the frame's end.
    final retired = _focusNodes;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final node in retired) {
        node.dispose();
      }
    });
    _cellKeys = [for (var i = 0; i < widget.items.length; i++) GlobalKey()];
    _iconKeys = [for (var i = 0; i < widget.items.length; i++) GlobalKey()];
    _focusNodes = [for (var i = 0; i < widget.items.length; i++) FocusNode(debugLabel: 'PureNavBar.cell.$i')];
    _markPlaced = false;
    _cellRect = null;
    _iconRect = null;
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  /// Places the mark over the chosen cell, wherever layout put it — this runs
  /// after every build, so a font-scale change, a language switch or a width
  /// change re-seats it too.
  void _measure() {
    if (!mounted) {
      return;
    }
    final stripBox = _stripKey.currentContext?.findRenderObject();
    final cellBox = _cellKeys[_selectedIndex].currentContext?.findRenderObject();
    if (stripBox is! RenderBox || cellBox is! RenderBox || !cellBox.hasSize) {
      return;
    }
    final cell = cellBox.localToGlobal(Offset.zero, ancestor: stripBox) & cellBox.size;
    Rect? icon;
    if (widget.visual.mark == _NavMark.icon) {
      final iconBox = _iconKeys[_selectedIndex].currentContext?.findRenderObject();
      if (iconBox is! RenderBox || !iconBox.hasSize) {
        return;
      }
      icon = iconBox.localToGlobal(Offset.zero, ancestor: stripBox) & iconBox.size;
    }
    if (cell != _cellRect || icon != _iconRect) {
      setState(() {
        _cellRect = cell;
        _iconRect = icon;
        _markPlaced = true;
      });
    }
  }

  /// The mark's rect inside the strip, from the measured geometry and the
  /// language's placement rule.
  Rect? _markRect(_NavVisual visual) {
    final cell = _cellRect;
    if (cell == null) {
      return null;
    }
    return switch (visual.mark) {
      _NavMark.none => null,
      _NavMark.cell => visual.markInset.deflateRect(cell),
      _NavMark.icon => _iconRect == null ? null : visual.markInset.inflateRect(_iconRect!),
      _NavMark.topEdge => Rect.fromLTWH(
        cell.center.dx - visual.markSize.width / 2,
        cell.top,
        visual.markSize.width,
        visual.markSize.height,
      ),
      _NavMark.bottomEdge => Rect.fromLTWH(
        cell.center.dx - visual.markSize.width / 2,
        cell.bottom - visual.markSize.height,
        visual.markSize.width,
        visual.markSize.height,
      ),
    };
  }

  /// Focuses the nearest enabled destination in [direction]; reports whether
  /// one was found, so a strip at its edge hands the key back to the shell.
  bool _moveFocus(int from, int direction) {
    if (!_active) {
      return false;
    }
    var next = from + direction;
    while (next >= 0 && next < widget.items.length) {
      if (_cellEnabled(next)) {
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
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      return _moveFocus(index, -1) ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
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
      if (_cellEnabled(index)) {
        widget.select?.call(index);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final visual = widget.visual;
    // The label size rides the theme's font scale, so the user's small-text
    // preference grows the destination labels with the rest of the chrome.
    final fontRatio = theme.text.caption.fontSize! / theme.token.type.fontSizeSM;
    final labelStyle = theme.text.caption.copyWith(fontSize: visual.fontSize * fontRatio);
    final cellHeight = visual.height - visual.inset.vertical;
    final row = Row(
      children: [
        for (var i = 0; i < widget.items.length; i++)
          Expanded(
            child: _NavCell(
              key: _cellKeys[i],
              item: widget.items[i],
              selected: i == _selectedIndex,
              barActive: _active,
              visual: visual,
              iconKey: _iconKeys[i],
              iconSize: visual.iconSize,
              cellHeight: cellHeight,
              labelStyle: labelStyle,
              focusNode: _focusNodes[i],
              onKeyEvent: (node, event) => _handleKey(i, event),
              onSelect: () => widget.select?.call(i),
            ),
          ),
      ],
    );
    final strip = Stack(
      key: _stripKey,
      clipBehavior: Clip.none,
      children: [if (_markPlaced && _markRect(visual) != null) _mark(theme, visual), row],
    );
    final frame = SizedBox(
      height: visual.height,
      child: Padding(padding: visual.inset, child: strip),
    );
    final bar = KeyedSubtree(key: ValueKey('PureNavBar.${widget.language.name}'), child: visual.track(theme, frame));
    if (_active) {
      return bar;
    }
    return IgnorePointer(child: bar);
  }

  Widget _mark(PureTheme theme, _NavVisual visual) {
    final rect = _markRect(visual)!;
    final child = DecoratedBox(decoration: visual.indicator(theme, active: _markLive));
    // The first placement snaps; every later one slides.
    if (_markPlaced) {
      return AnimatedPositioned.fromRect(
        key: _markKey,
        rect: rect,
        duration: theme.duration,
        curve: Curves.easeOutCubic,
        child: child,
      );
    }
    return Positioned.fromRect(key: _markKey, rect: rect, child: child);
  }
}

/// One destination cell: interaction states (hover, pressed, focus, disabled),
/// the icon-over-label stack every platform bar draws, and the semantics that
/// name it for a screen reader.
class _NavCell extends StatefulWidget {
  const new({
    required this.item,
    required this.selected,
    required this.barActive,
    required this.visual,
    required this.iconKey,
    required this.iconSize,
    required this.cellHeight,
    required this.labelStyle,
    required this.focusNode,
    required this.onKeyEvent,
    required this.onSelect,
    super.key,
  });

  final PureNavBarItem item;

  final bool selected;

  /// Whether the bar is live; an inert bar greys every cell out.
  final bool barActive;

  final _NavVisual visual;

  /// The key the parent measures to seat an icon-shaped mark; the glyph itself
  /// sits under it whatever else the cell grows around it.
  final GlobalKey iconKey;

  final double iconSize;

  /// The cell's minimum height: the bar's own content height less the track's
  /// vertical inset, so the tint and the ring span the full strip.
  final double cellHeight;

  final TextStyle labelStyle;

  final FocusNode focusNode;

  final KeyEventResult Function(FocusNode node, KeyEvent event) onKeyEvent;

  final VoidCallback onSelect;

  @override
  State<_NavCell> createState() => _NavCellState();
}

class _NavCellState extends State<_NavCell> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.barActive && widget.item.enabled;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final visual = widget.visual;
    final enabled = _enabled;
    final selected = widget.selected && widget.barActive;
    final color = visual.content(theme, selected: selected, hovered: _hovered, pressed: _pressed, enabled: enabled);
    final tint = !selected && enabled
        ? (_pressed
              ? visual.pressedTint(theme)
              : _hovered
              ? visual.hoverTint(theme)
              : null)
        : null;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(widget.item.icon, key: widget.iconKey, size: widget.iconSize, color: color),
        const SizedBox(height: 4),
        Flexible(
          child: Text(
            widget.item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: widget.labelStyle.copyWith(color: color),
          ),
        ),
      ],
    );

    // The focus ring is painted through a static [DecoratedBox] rather than
    // the container's `foregroundDecoration`, because the container would
    // *tween* it — and lerping a hairline into a rounded ring passes through
    // a non-uniform border with a radius, which Flutter refuses to paint.
    // The background tint still animates on the container itself.
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
          onTap: enabled ? widget.onSelect : null,
          child: Semantics(
            button: true,
            selected: widget.selected,
            enabled: enabled,
            label: widget.item.label,
            child: ExcludeSemantics(
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: _focused
                    ? BoxDecoration(
                        borderRadius: visual.cellRadius,
                        border: Border.fromBorderSide(BorderSide(color: theme.colors.primary, width: 2)),
                      )
                    : const BoxDecoration(),
                child: AnimatedContainer(
                  duration: theme.duration,
                  curve: Curves.easeOut,
                  alignment: AlignmentDirectional.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: BoxConstraints(minHeight: widget.cellHeight),
                  decoration: BoxDecoration(color: tint, borderRadius: visual.cellRadius),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
