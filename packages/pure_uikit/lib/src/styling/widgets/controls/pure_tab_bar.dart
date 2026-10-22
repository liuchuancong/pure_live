import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pure_uikit/src/scales/radii.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// A count or marker drawn over a [PureTabBarItem]'s icon corner — the tab
/// bar's badge grammar. A [count] renders as a pill capped at [max] with a
/// `max+` tail, a [dot] renders as the bare marker dot, and a [label] renders
/// as a short text tag.
@immutable
final class PureTabBarBadge {
  /// A badge.
  const new({this.count, this.label, this.dot = false, this.max = 99});

  /// The unread count; `max+` past [max]. Null hides the count.
  final int? count;

  /// A short text tag shown when [count] is null.
  final String? label;

  /// Whether to draw the bare dot instead of any text.
  final bool dot;

  /// The count ceiling before it collapses to `max+`.
  final int max;

  /// The text this badge draws, after the [max] cap and the [dot] fold.
  String? get text {
    if (dot) {
      return null;
    }
    final count = this.count;
    if (count != null) {
      return count > max ? '$max+' : '$count';
    }
    return label;
  }

  @override
  bool operator ==(Object other) =>
      other is PureTabBarBadge && other.count == count && other.label == label && other.dot == dot && other.max == max;

  @override
  int get hashCode => Object.hash(count, label, dot, max);
}

/// One tab of a [PureTabBar]: an icon, a label, or both. The icon-only and
/// label-only cells are the design sheet's two compact variants; a cell with
/// neither is a mistake, so the constructor asserts one exists.
@immutable
final class PureTabBarItem {
  /// A tab.
  const new({this.icon, this.label, this.badge, this.semanticLabel, this.enabled = true})
    : assert(icon != null || (label != null && label != ''), 'A PureTabBarItem carries an icon, a label, or both.');

  /// The glyph; null on a text-only cell.
  final IconData? icon;

  /// The text; null on an icon-only cell, which should carry a
  /// [semanticLabel] so screen readers can name it.
  final String? label;

  /// The marker over the icon's corner.
  final PureTabBarBadge? badge;

  /// The name read aloud for an icon-only cell; a labelled cell reads
  /// [label] and ignores this.
  final String? semanticLabel;

  /// Whether the cell responds to input; a disabled cell greys out and is
  /// skipped by keyboard traversal.
  final bool enabled;

  /// The name used for semantics.
  String get semanticsText => label ?? semanticLabel ?? '';

  @override
  bool operator ==(Object other) =>
      other is PureTabBarItem &&
      other.icon == icon &&
      other.label == label &&
      other.badge == badge &&
      other.semanticLabel == semanticLabel &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(icon, label, badge, semanticLabel, enabled);
}

/// The semantic role of a tab bar.
///
/// The role is intentionally independent from the active design language: a
/// page tab should remain a page tab when the app switches from Fluent to
/// Material, while a segmented control keeps its contained selection surface.
enum PureTabBarVariant {
  /// Page-level navigation, normally indicated by an underline.
  page,

  /// A compact, mutually-exclusive choice such as list/grid or source/playlist.
  segmented,

  /// Content categories such as channels, genres, or site sections.
  category,
}

/// The bar's three height tiers, the design sheet's 40 / 48 / 56.
enum PureTabBarSize {
  /// 40 — dense strips inside an app bar.
  small,

  /// 48 — the default.
  standard,

  /// 56 — TV layouts and touch-first shells.
  large,
}

/// The geometry a [PureTabBarSize] lays out: absolute pixels, so a tier keeps
/// its height whatever the design language makes of it.
extension PureTabBarSizeMetrics on PureTabBarSize {
  /// The bar's height.
  double get height => switch (this) {
    PureTabBarSize.small => 40,
    PureTabBarSize.standard => 48,
    PureTabBarSize.large => 56,
  };

  /// The glyph size inside a cell.
  double get iconSize => switch (this) {
    PureTabBarSize.small => 16,
    PureTabBarSize.standard => 20,
    PureTabBarSize.large => 24,
  };

  /// The label size, before the theme's font scale.
  double get fontSize => switch (this) {
    PureTabBarSize.small => 11,
    PureTabBarSize.standard => 12,
    PureTabBarSize.large => 13,
  };

  /// The padding on either side of a cell's content.
  double get horizontalPadding => switch (this) {
    PureTabBarSize.small => 12,
    PureTabBarSize.standard => 14,
    PureTabBarSize.large => 16,
  };

  /// The gap between a cell's icon and its label.
  double get iconLabelGap => switch (this) {
    PureTabBarSize.small => 6,
    PureTabBarSize.standard => 7,
    PureTabBarSize.large => 8,
  };

  /// The track's padding around the cells (and so around the sliding pill).
  double get inset => switch (this) {
    PureTabBarSize.small => 3,
    PureTabBarSize.standard => 4,
    PureTabBarSize.large => 4,
  };
}

/// The design sheet's pill tab bar: one navigation strip for page switching
/// and channel categories, drawn in every design language.
///
/// Where `PureTabs` hands a page's strip to the active library's own tab
/// widget, this component is the pill bar itself — an accent-filled pill on
/// Windows (Fluent), a floating white thumb on iOS and macOS (Cupertino), an
/// ink underline on Android (Material) and the wind and forui tracks that
/// share its grammar, a rounder pill under Yaru, a frosted stadium under
/// glass, and a raised track with a pressed-in pill under neumorphic. All of
/// it is painted here, because a pill that slides is exactly what the
/// libraries do not ship; the colours, radii, motion and text come from the
/// tokens, so a language re-skin and a dark switch still come out right.
///
/// Every visual answers to the same interaction contract: hover and pressed
/// tints, a disabled bar and disabled cells, a badge over the icon, the three
/// [PureTabBarSize] tiers, focus rings and arrow-key traversal for keyboards
/// and remotes (Enter, Space and the select keys choose), screen-reader
/// traits on every cell, and a strip that scrolls when the tabs outgrow it.
class PureTabBar extends StatelessWidget {
  /// A tab bar over [items] with [index] selected.
  const new({
    required this.items,
    required this.index,
    required this.onChanged,
    this.size = PureTabBarSize.standard,
    this.variant = PureTabBarVariant.page,
    this.expand = false,
    this.isScrollable = false,
    this.enabled = true,
    super.key,
  });

  /// The tabs, in order.
  final List<PureTabBarItem> items;

  /// The selected tab.
  final int index;

  /// Called with a tab's index when it is chosen; null renders the bar inert.
  final ValueChanged<int>? onChanged;

  /// The height tier.
  final PureTabBarSize size;

  /// The semantic role, independent of the active design language.
  final PureTabBarVariant variant;

  /// Whether the cells share the full width equally instead of hugging their
  /// content. Ignored when [isScrollable] is set — a scrolling strip has no
  /// width to share.
  final bool expand;

  /// Whether a long strip scrolls instead of squeezing its cells.
  final bool isScrollable;

  /// Whether the bar responds to input; false greys every cell out.
  final bool enabled;

  _BarVisual _resolveVisual(PureTheme theme) {
    final language = theme.config.language;

    // Glass and neumorphic are intentionally distinctive design languages.
    // Other languages choose their geometry from the tab bar's semantic role.
    if (language == PureDesignLanguage.glass) {
      return _BarVisual.glass();
    }
    if (language == PureDesignLanguage.neumorphic) {
      return _BarVisual.neumorphic();
    }

    if (variant == PureTabBarVariant.segmented) {
      return switch (language) {
        PureDesignLanguage.fluent => _BarVisual.accentPill(trackRadius: theme.token.scale.radii.base),
        PureDesignLanguage.yaru => _BarVisual.accentPill(trackRadius: theme.token.scale.radii.lg),
        PureDesignLanguage.cupertino || PureDesignLanguage.macos => _BarVisual.thumb(),
        PureDesignLanguage.material ||
        PureDesignLanguage.wind ||
        PureDesignLanguage.forui => _BarVisual.accentPill(trackRadius: theme.token.scale.radii.base),
        PureDesignLanguage.glass || PureDesignLanguage.neumorphic => throw StateError('Handled above.'),
      };
    }

    // Page and category tabs use a lightweight indicator instead of turning
    // every selected tab into a filled button.
    return _BarVisual.underline();
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = PureTheme.of(context);
    final select = enabled ? onChanged : null;
    final bar = _SlidingTabBar(
      items: items,
      index: index,
      select: select,
      size: size,
      // A scrolling strip lays its cells out end to end; there is no width to
      // share, so the two flags never apply together.
      expand: expand && !isScrollable,
      visual: _resolveVisual(theme),
    );
    if (!isScrollable) {
      return bar;
    }
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: bar);
  }
}

/// How one design language paints the bar: the track it sits on, the sliding
/// indicator behind the selected cell, the interaction tints, and the colour
/// of a cell's content in each state.
@immutable
final class _BarVisual {
  const new({
    required this.track,
    required this.stackAlignment,
    required this.cellRadius,
    required this.indicator,
    required this.indicatorHeight,
    required this.hoverTint,
    required this.pressedTint,
    required this.content,
  });

  /// Windows Fluent and Linux Yaru: an accent-filled pill slides behind the
  /// selected cell on a card track. Yaru asks for the rounder container.
  factory accentPill({required double trackRadius}) {
    return _BarVisual(
      track: (theme, strip, inset) => DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.bgContainer,
          borderRadius: BorderRadius.circular(trackRadius),
          border: Border.all(color: theme.colors.borderSecondary),
        ),
        child: Padding(padding: inset, child: strip),
      ),
      stackAlignment: AlignmentDirectional.center,
      cellRadius: BorderRadius.circular(PureRadii.pill),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.colors.primary : theme.colors.fillSecondary,
        borderRadius: BorderRadius.circular(PureRadii.pill),
      ),
      indicatorHeight: null,
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      content: contentOnPill,
    );
  }

  /// iOS and macOS: a floating white thumb on a grey stadium track, the
  /// selected cell in the accent — the sliding control's own grammar, drawn
  /// long.
  factory thumb() {
    return _BarVisual(
      track: (theme, strip, inset) => Padding(
        padding: inset,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colors.fillSecondary,
            borderRadius: BorderRadius.circular(PureRadii.pill),
          ),
          child: strip,
        ),
      ),
      stackAlignment: AlignmentDirectional.center,
      cellRadius: BorderRadius.circular(PureRadii.pill),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.colors.bgElevated : theme.colors.fillTertiary,
        borderRadius: BorderRadius.circular(PureRadii.pill),
        boxShadow: active
            ? [BoxShadow(color: theme.colors.shadowBase, blurRadius: 6, offset: const Offset(0, 1.5))]
            : const [],
      ),
      indicatorHeight: null,
      hoverTint: (_) => null,
      pressedTint: (_) => null,
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

  /// Android Material and the wind and forui tracks that share its grammar:
  /// no track at all, the selected cell in the accent over an ink bar pinned
  /// to the strip's bottom edge.
  factory underline() {
    return _BarVisual(
      track: (theme, strip, inset) => strip,
      stackAlignment: AlignmentDirectional.bottomCenter,
      cellRadius: BorderRadius.circular(PureRadii.sm),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.tabs.inkBarColor : theme.colors.fillTertiary,
        borderRadius: BorderRadius.circular(1.5),
      ),
      indicatorHeight: 3,
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      content: (theme, {required selected, required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (selected || pressed) {
          return theme.tabs.itemSelectedColor;
        }
        if (hovered) {
          return theme.tabs.itemHoverColor;
        }
        return theme.tabs.itemColor;
      },
    );
  }

  /// The glass language: a frosted stadium track (real backdrop blur when the
  /// device can afford it) with a gradient accent pill.
  factory glass() {
    Color tint(PureTheme theme, double alpha) =>
        theme.isDark ? Colors.white.withValues(alpha: alpha) : Colors.black.withValues(alpha: alpha);
    return _BarVisual(
      track: (theme, strip, inset) {
        final filled = DecoratedBox(
          decoration: BoxDecoration(
            color: theme.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(PureRadii.pill),
            border: Border.all(
              color: theme.isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.7),
            ),
          ),
          child: Padding(padding: inset, child: strip),
        );
        if (!theme.canBlur) {
          return filled;
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(PureRadii.pill),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: filled),
        );
      },
      stackAlignment: AlignmentDirectional.center,
      cellRadius: BorderRadius.circular(PureRadii.pill),
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
      indicatorHeight: null,
      hoverTint: (theme) => tint(theme, 0.06),
      pressedTint: (theme) => tint(theme, 0.1),
      content: contentOnPill,
    );
  }

  /// The neumorphic language: a raised track (light from the top left, shadow
  /// from the bottom right) and a pressed-in pill under the selected cell.
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
    return _BarVisual(
      track: (theme, strip, inset) => DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.bgContainer,
          borderRadius: BorderRadius.circular(theme.token.scale.radii.lg),
          boxShadow: raised(theme),
        ),
        child: Padding(padding: inset, child: strip),
      ),
      stackAlignment: AlignmentDirectional.center,
      cellRadius: BorderRadius.circular(PureRadii.pill),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.colors.primaryBg : theme.colors.fill,
        borderRadius: BorderRadius.circular(PureRadii.pill),
        boxShadow: active ? sunk(theme) : null,
      ),
      indicatorHeight: null,
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

  /// Wraps the strip: decoration, blur, padding — whatever the language puts
  /// around the cells. The `inset` argument is the tier's track padding.
  final Widget Function(PureTheme theme, Widget strip, EdgeInsets inset) track;

  /// Where the strip sits inside the bar's fixed height; the underline
  /// languages pin it to the bottom edge so the ink bar touches it.
  final AlignmentDirectional stackAlignment;

  /// The corner radius of a cell's hover tint and focus ring.
  final BorderRadius cellRadius;

  /// The decoration of the sliding indicator behind the selected cell, with
  /// the `active` flag telling the language's chosen colour apart from the
  /// grey one an inert bar shows.
  final Decoration Function(PureTheme theme, {required bool active}) indicator;

  /// The indicator's height; null fills the measured cell from top to bottom
  /// (the pill), a value pins a strip of that height to the bottom (the ink
  /// bar).
  final double? indicatorHeight;

  /// The tint behind a hovered, unselected cell; null is the languages that
  /// answer a hover in the text colour alone.
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

  /// The content colours the filled-pill languages share: white on the pill,
  /// the text roles elsewhere.
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
}

/// The sliding indicator and the cells, shared by every language: it measures
/// the selected cell after layout, slides the indicator there, moves focus
/// with the arrow keys and keeps the selection visible in a scrolled strip.
class _SlidingTabBar extends StatefulWidget {
  const new({
    required this.items,
    required this.index,
    required this.select,
    required this.size,
    required this.expand,
    required this.visual,
  });

  final List<PureTabBarItem> items;

  final int index;

  final ValueChanged<int>? select;

  final PureTabBarSize size;

  final bool expand;

  final _BarVisual visual;

  @override
  State<_SlidingTabBar> createState() => _SlidingTabBarState();
}

class _SlidingTabBarState extends State<_SlidingTabBar> {
  final GlobalKey _stripKey = GlobalKey();
  List<GlobalKey> _cellKeys = const [];
  List<FocusNode> _focusNodes = const [];
  Rect? _indicatorRect;

  /// False until the first measurement lands, so the indicator appears on the
  /// selected cell without sliding in from nowhere.
  bool _indicatorPlaced = false;
  bool _revealPending = false;

  @override
  void initState() {
    super.initState();
    _rebuildCells();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant _SlidingTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _rebuildCells();
    }
    if (oldWidget.index != widget.index) {
      _revealPending = true;
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

  /// Whether the selection may draw as chosen: an inert bar, or a bar whose
  /// selected cell is itself disabled, shows the grey selection.
  bool get _selectionLive => _active && widget.items[_selectedIndex].enabled;

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
    _focusNodes = [for (var i = 0; i < widget.items.length; i++) FocusNode(debugLabel: 'PureTabBar.cell.$i')];
    _indicatorPlaced = false;
    _indicatorRect = null;
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  /// Places the indicator over the selected cell, wherever layout put it —
  /// this runs after every build, so a font-scale change or a tier switch
  /// re-seats it too.
  void _measure() {
    if (!mounted) {
      return;
    }
    final stripBox = _stripKey.currentContext?.findRenderObject();
    final cellBox = _cellKeys[_selectedIndex].currentContext?.findRenderObject();
    if (stripBox is! RenderBox || cellBox is! RenderBox || !cellBox.hasSize) {
      return;
    }
    final rect = cellBox.localToGlobal(Offset.zero, ancestor: stripBox) & cellBox.size;
    final reveal = _revealPending;
    _revealPending = false;
    if (rect != _indicatorRect) {
      setState(() {
        _indicatorRect = rect;
        _indicatorPlaced = true;
      });
    }
    if (reveal) {
      _reveal(_selectedIndex);
    }
  }

  /// Scrolls the strip so cell [index] is in view; a no-op when the bar is
  /// not inside a scroll view.
  void _reveal(int index) {
    final cellContext = _cellKeys[index].currentContext;
    if (cellContext != null) {
      Scrollable.ensureVisible(cellContext, duration: context.themeFor.duration, alignment: 0.5);
    }
  }

  /// Focuses the nearest enabled cell in [direction]; reports whether one was
  /// found, so a strip at its edge hands the key back to the shell.
  bool _moveFocus(int from, int direction) {
    if (!_active) {
      return false;
    }
    var next = from + direction;
    while (next >= 0 && next < widget.items.length) {
      if (widget.items[next].enabled) {
        _focusNodes[next].requestFocus();
        _reveal(next);
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
      // A disabled item must never be activated through a keyboard or TV
      // remote, even if focus was retained while the item became disabled.
      if (_active && widget.items[index].enabled) {
        widget.select?.call(index);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.themeFor;
    final visual = widget.visual;
    final metrics = widget.size;
    // The label size rides the theme's font scale, so the user's small-text
    // preference grows the tab labels with the rest of the chrome.
    final fontRatio = theme.text.caption.fontSize! / theme.token.type.fontSizeSM;
    final labelStyle = theme.text.caption.copyWith(fontSize: metrics.fontSize * fontRatio);
    final inset = EdgeInsets.symmetric(horizontal: metrics.inset, vertical: metrics.inset);
    final row = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.items.length; i++)
          if (widget.expand)
            Expanded(
              child: _cell(index: i, metrics: metrics, visual: visual, labelStyle: labelStyle),
            )
          else
            _cell(index: i, metrics: metrics, visual: visual, labelStyle: labelStyle),
      ],
    );
    final strip = Stack(
      key: _stripKey,
      clipBehavior: Clip.none,
      children: [
        if (_indicatorPlaced && _indicatorRect != null) _indicator(theme, visual: visual),
        row,
      ],
    );
    final bar = SizedBox(height: metrics.height, child: visual.track(theme, strip, inset));
    if (_active) {
      return bar;
    }
    return IgnorePointer(child: bar);
  }

  Widget _indicator(PureTheme theme, {required _BarVisual visual}) {
    final rect = _indicatorRect!;
    final child = DecoratedBox(decoration: visual.indicator(theme, active: _selectionLive));
    // The first placement snaps; every later one slides.
    final duration = context.themeFor.duration;
    if (visual.indicatorHeight case final height?) {
      // The ink bar: a strip of its own height pinned to the strip's bottom
      // edge, as wide as the selected cell.
      if (_indicatorPlaced) {
        return AnimatedPositioned(
          left: rect.left,
          width: rect.width,
          bottom: 0,
          height: height,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: child,
        );
      }
      return Positioned(left: rect.left, width: rect.width, bottom: 0, height: height, child: child);
    }
    if (_indicatorPlaced) {
      return AnimatedPositioned.fromRect(rect: rect, duration: duration, curve: Curves.easeOutCubic, child: child);
    }
    return Positioned.fromRect(rect: rect, child: child);
  }

  Widget _cell({
    required int index,
    required PureTabBarSize metrics,
    required _BarVisual visual,
    required TextStyle labelStyle,
  }) {
    return _TabCell(
      key: _cellKeys[index],
      item: widget.items[index],
      selected: index == _selectedIndex,
      barActive: _active,
      metrics: metrics,
      visual: visual,
      labelStyle: labelStyle,
      focusNode: _focusNodes[index],
      onKeyEvent: (node, event) => _handleKey(index, event),
      onSelect: () {
        _reveal(index);
        widget.select?.call(index);
      },
    );
  }
}

extension on BuildContext {
  /// The resolved theme, read the way every component here does.
  PureTheme get themeFor => PureTheme.of(this);
}

/// One cell: interaction states (hover, pressed, focus, disabled), the badge
/// over the icon, and the semantics that name it for a screen reader.
class _TabCell extends StatefulWidget {
  const new({
    required this.item,
    required this.selected,
    required this.barActive,
    required this.metrics,
    required this.visual,
    required this.labelStyle,
    required this.focusNode,
    required this.onKeyEvent,
    required this.onSelect,
    super.key,
  });

  final PureTabBarItem item;

  final bool selected;

  /// Whether the bar is live; an inert bar greys every cell out.
  final bool barActive;

  final PureTabBarSize metrics;

  final _BarVisual visual;

  final TextStyle labelStyle;

  final FocusNode focusNode;

  final KeyEventResult Function(FocusNode node, KeyEvent event) onKeyEvent;

  final VoidCallback onSelect;

  @override
  State<_TabCell> createState() => _TabCellState();
}

class _TabCellState extends State<_TabCell> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.barActive && widget.item.enabled;

  @override
  Widget build(BuildContext context) {
    final theme = context.themeFor;
    final visual = widget.visual;
    final metrics = widget.metrics;
    final item = widget.item;
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

    final Widget content;
    if (item.icon == null) {
      content = Text(
        item.label!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: widget.labelStyle.copyWith(color: color),
      );
    } else {
      final icon = Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(item.icon, size: metrics.iconSize, color: color),
          if (item.badge != null) Positioned(top: -5, right: -7, child: _badge(theme, item.badge!)),
        ],
      );
      if (item.label == null) {
        content = icon;
      } else {
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            SizedBox(width: metrics.iconLabelGap),
            Flexible(
              child: Text(
                item.label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: widget.labelStyle.copyWith(color: color),
              ),
            ),
          ],
        );
      }
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
          onTap: enabled ? widget.onSelect : null,
          child: Semantics(
            button: true,
            selected: widget.selected,
            enabled: enabled,
            label: item.semanticsText.isEmpty ? null : item.semanticsText,
            child: ExcludeSemantics(
              child: AnimatedScale(
                // The TV answer: the focused cell grows a touch, and the ring
                // below names it for keyboard and remote users alike.
                scale: _focused ? 1.05 : 1,
                duration: theme.duration,
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: theme.duration,
                  curve: Curves.easeOut,
                  padding: EdgeInsets.symmetric(horizontal: metrics.horizontalPadding),
                  decoration: BoxDecoration(color: tint, borderRadius: visual.cellRadius),
                  foregroundDecoration: _focused
                      ? BoxDecoration(
                          borderRadius: visual.cellRadius,
                          border: Border.fromBorderSide(BorderSide(color: theme.colors.primary, width: 2)),
                        )
                      : null,
                  constraints: BoxConstraints(minHeight: metrics.height - 2 * metrics.inset),
                  alignment: AlignmentDirectional.center,
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(PureTheme theme, PureTabBarBadge badge) {
    final bt = theme.badge;
    if (badge.dot) {
      return Container(
        width: bt.dotSize,
        height: bt.dotSize,
        decoration: BoxDecoration(color: bt.background, shape: BoxShape.circle),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: BoxDecoration(color: bt.background, borderRadius: BorderRadius.circular(PureRadii.pill)),
      alignment: AlignmentDirectional.center,
      child: Text(
        badge.text ?? '',
        maxLines: 1,
        style: TextStyle(fontSize: 10, height: 1, fontWeight: FontWeight.w600, color: bt.foreground),
      ),
    );
  }
}
