import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pure_uikit/src/scales/radii.dart';
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
/// The role decides the selection surface: a page tab keeps the lightweight
/// indicator, while a segmented control keeps its contained selection surface.
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
/// and channel categories.
///
/// Where `PureTabs` hands a page's strip to the host's own tab widget, this
/// component is the pill bar itself — the accent-filled pill slides behind the
/// selected cell for a segmented pick, and page and category tabs ride the
/// lightweight ink underline. All of it is painted here, because a pill that
/// slides is exactly what the libraries do not ship; the colours, radii, motion
/// and text come from the tokens, so a dark switch still comes out right.
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
    // A segmented pick keeps the contained accent-pill selection surface; page
    // and category tabs use a lightweight indicator instead of turning every
    // selected tab into a filled button.
    if (variant == PureTabBarVariant.segmented) {
      return _BarVisual.accentPill(trackRadius: theme.token.scale.radii.base);
    }

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

/// How the bar is painted: the track it sits on, the sliding
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
    this.selectedTint,
  });

  /// Windows Fluent: an accent-filled pill slides behind the
  /// selected cell on a card track.
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

  /// The navigation row turned sideways — the pane row's own grammar at the
  /// strip's orientation: the selected cell on the pane's soft rounded fill,
  /// the accent bar riding the strip's bottom edge where the pane's pill
  /// stands on its start edge, hover and press fading the same fill in, and
  /// the bar travelling between cells with the pane indicator's stretch.
  factory underline() {
    return _BarVisual(
      track: (theme, strip, inset) => strip,
      stackAlignment: AlignmentDirectional.bottomCenter,
      cellRadius: BorderRadius.circular(PureRadii.sm),
      selectedTint: (theme) => theme.colors.fillSecondary,
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.tabs.inkBarColor : theme.colors.fillTertiary,
        borderRadius: BorderRadius.circular(1.5),
      ),
      indicatorHeight: 3,
      hoverTint: (theme) => theme.colors.fillTertiary,
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

  /// Wraps the strip: decoration and padding around the cells. The `inset`
  /// argument is the tier's track padding.
  final Widget Function(PureTheme theme, Widget strip, EdgeInsets inset) track;

  /// Where the strip sits inside the bar's fixed height; the underline
  /// pins it to the bottom edge so the ink bar touches it.
  final AlignmentDirectional stackAlignment;

  /// The corner radius of a cell's hover tint and focus ring.
  final BorderRadius cellRadius;

  /// The fill under the selected cell — the pane row's own soft rounded
  /// fill, the body of the selection the bar only marks. Null leaves the
  /// look to the sliding indicator alone.
  final Color? Function(PureTheme theme)? selectedTint;

  /// The decoration of the sliding indicator behind the selected cell, with
  /// the `active` flag telling the chosen colour apart from the
  /// grey one an inert bar shows.
  final Decoration Function(PureTheme theme, {required bool active}) indicator;

  /// The indicator's height; null fills the measured cell from top to bottom
  /// (the pill), a value pins a strip of that height to the bottom (the ink
  /// bar).
  final double? indicatorHeight;

  /// The tint behind a hovered, unselected cell; null when the hover is
  /// answered in the text colour alone.
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

  /// The content colours the filled-pill language shares: white on the pill,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // The strip stands its tier's height where the caller reserved it,
        // and shrinks to a slot that bounds it lower (a title row) rather
        // than overflowing it.
        final height = constraints.hasBoundedHeight ? math.min(metrics.height, constraints.maxHeight) : metrics.height;
        final row = Row(
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.items.length; i++)
              if (widget.expand)
                Expanded(
                  child: _cell(index: i, metrics: metrics, height: height, visual: visual, labelStyle: labelStyle),
                )
              else
                _cell(index: i, metrics: metrics, height: height, visual: visual, labelStyle: labelStyle),
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
        final bar = SizedBox(height: height, child: visual.track(theme, strip, inset));
        if (_active) {
          return bar;
        }
        return IgnorePointer(child: bar);
      },
    );
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
    required double height,
    required _BarVisual visual,
    required TextStyle labelStyle,
  }) {
    return _TabCell(
      key: _cellKeys[index],
      item: widget.items[index],
      selected: index == _selectedIndex,
      barActive: _active,
      metrics: metrics,
      stripHeight: height,
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
    required this.stripHeight,
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

  /// The strip's laid-out height — the cell's own floor, and for the ink
  /// strip the edge its hover bar rides.
  final double stripHeight;

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

  /// True from the moment a pointer takes the cell until focus leaves it: a
  /// click answers in the fill and the bar alone — the ring and the growth
  /// are the keyboard's and the remote's answer, never the mouse's.
  bool _pointerFocused = false;

  /// The ring and the touch of growth, only for a keyboard- or remote-driven
  /// focus.
  bool get _showsFocusLook => _focused && !_pointerFocused;

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
    // The selected cell carries the pane row's fill; hover and press fade
    // the same fill in — the navigation row's own answers, sideways.
    final tint = !enabled
        ? null
        : selected
        ? visual.selectedTint?.call(theme)
        : _pressed
        ? visual.pressedTint(theme)
        : _hovered
        ? visual.hoverTint(theme)
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
      onFocusChange: (focused) => setState(() {
        _focused = focused;
        // Focus leaving ends a pointer's claim: the next arrival — by
        // traversal or remote — is the keyboard's to answer.
        if (!focused) {
          _pointerFocused = false;
        }
      }),
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
                  setState(() {
                    _pressed = true;
                    _pointerFocused = true;
                  });
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
                // The TV answer: a focused cell grows a touch — no ring, the
                // fill and the bar are all the focus says here.
                scale: _showsFocusLook ? 1.05 : 1,
                duration: theme.duration,
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: theme.duration,
                  curve: Curves.easeOut,
                  padding: EdgeInsets.symmetric(horizontal: metrics.horizontalPadding),
                  decoration: BoxDecoration(color: tint, borderRadius: visual.cellRadius),
                  constraints: BoxConstraints(minHeight: math.max(0, widget.stripHeight - 2 * metrics.inset)),
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
