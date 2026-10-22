import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pure_uikit/src/scales/radii.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The kit's segmented control: one row of mutually-exclusive choices.
///
/// Where `PureTabBar` is the page-navigation strip — a pill or an ink bar that
/// names *where you are* — this is the compact picker that names *what you
/// chose*: list or grid, playlist or stream, fit or fill. The grammar is the
/// WinUI `SelectionBar`: the chosen cell sits under a pill that slides behind
/// it on a contained, bordered track. All of it is painted here, because the
/// sliding selection is exactly what the libraries ship inconsistently; the
/// colours, radii, motion and text come from the tokens, so a dark switch
/// still comes out right.
///
/// Every visual answers to one interaction contract: hover and pressed tints on
/// the unselected cells, a whole-bar disabled state and per-cell disabled
/// segments, focus rings and Left/Right traversal with Enter/Space selection for
/// keyboards and remotes, screen-reader traits on every cell (each reads as a
/// button that is or is not selected) inside a container, and a selection that
/// slides between cells over the theme's motion duration.
class PureSegmented extends StatelessWidget {
  /// A segmented control over [labels] with [index] chosen.
  const new({
    required this.labels,
    required this.index,
    required this.onChanged,
    this.expand = false,
    this.enabled = true,
    this.disabledIndexes = const <int>{},
    super.key,
  });

  /// The segment labels, in order.
  final List<String> labels;

  /// The selected segment.
  final int index;

  /// Called with a segment's index when it is chosen; null renders the control
  /// inert.
  final ValueChanged<int>? onChanged;

  /// Whether the segments share the full width equally instead of hugging their
  /// labels.
  final bool expand;

  /// Whether the control responds to input; false greys every segment out.
  final bool enabled;

  /// The segments that are individually disabled: greyed, inert to taps, and
  /// skipped by keyboard traversal. A whole-bar disabled control ignores this —
  /// every segment is already off.
  final Set<int> disabledIndexes;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = PureTheme.of(context);
    // A null callback is the inert state, so folding `enabled` into it once
    // gives the bar a single verdict.
    final select = enabled ? onChanged : null;
    final bar = _SegmentedBar(
      labels: labels,
      index: index,
      select: select,
      expand: expand,
      disabled: disabledIndexes,
      visual: _SegmentVisual.accentPill(trackRadius: theme.token.scale.radii.base),
    );
    // A segmented control is one container of buttons, not a bare stack of them;
    // the container role lets a screen reader announce the whole choice.
    return Semantics(container: true, child: bar);
  }
}

/// The geometry a segmented bar lays out: absolute pixels, so the control keeps
/// its compact height. Text still rides the theme's font scale, and colour and
/// radius come from tokens.
abstract final class _SegmentedMetrics {
  /// 32 — the control's height, the segmented bar's own tier (the tab bar is
  /// taller because it carries icons and badges; this carries one label).
  static const double height = 32;

  /// 3 — the track's padding around the cells, and so around the sliding pill.
  static const double inset = 3;

  /// 14 — the padding on either side of a cell's label.
  static const double horizontalPadding = 14;

  /// 13 — the label size before the theme's font scale.
  static const double fontSize = 13;

  /// 2 — the focus ring's width.
  static const double focusWidth = 2;
}

/// How the segmented bar is painted: the track it sits on, the
/// sliding selection behind the chosen cell, the interaction tints, and the
/// colour and weight of a cell's label in each state.
@immutable
final class _SegmentVisual {
  const new({
    required this.track,
    required this.cellRadius,
    required this.indicator,
    required this.hoverTint,
    required this.pressedTint,
    required this.content,
  });

  /// WinUI's `SelectionBar`: the chosen cell sits under a pill that slides
  /// behind it on a contained, bordered track — segmented keeps its own
  /// surface rather than dissolving into the page.
  factory accentPill({required double trackRadius}) {
    final pill = BorderRadius.circular(PureRadii.pill);
    return _SegmentVisual(
      cellRadius: pill,
      track: (theme, strip, inset) => DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.bgContainer,
          borderRadius: BorderRadius.circular(trackRadius),
          border: Border.all(color: theme.colors.borderSecondary),
        ),
        child: Padding(padding: inset, child: strip),
      ),
      indicator: (theme, {required active}) =>
          BoxDecoration(color: active ? theme.colors.primary : theme.colors.fillSecondary, borderRadius: pill),
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      content: contentOnPill,
    );
  }

  /// Wraps the strip: decoration and padding around the cells. The `inset`
  /// argument is the track padding.
  final Widget Function(PureTheme theme, Widget strip, EdgeInsets inset) track;

  /// The corner radius of a cell's hover tint and focus ring.
  final BorderRadius cellRadius;

  /// The decoration of the sliding selection behind the chosen cell, with the
  /// `active` flag telling the chosen colour apart from the grey one
  /// an inert bar shows.
  final Decoration Function(PureTheme theme, {required bool active}) indicator;

  /// The tint behind a hovered, unselected cell.
  final Color? Function(PureTheme theme) hoverTint;

  /// The tint behind a pressed cell.
  final Color? Function(PureTheme theme) pressedTint;

  /// The label colour in each state.
  final Color Function(
    PureTheme theme, {
    required bool selected,
    required bool hovered,
    required bool pressed,
    required bool enabled,
  })
  content;

  /// The label colours the filled-pill language shares: solid white on the
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
}

/// The sliding selection and the cells: it measures
/// the chosen cell after layout, slides the selection there, moves focus with
/// the arrow keys and keeps an inert bar greyed.
class _SegmentedBar extends StatefulWidget {
  const new({
    required this.labels,
    required this.index,
    required this.select,
    required this.expand,
    required this.disabled,
    required this.visual,
  });

  final List<String> labels;

  final int index;

  final ValueChanged<int>? select;

  final bool expand;

  final Set<int> disabled;

  final _SegmentVisual visual;

  @override
  State<_SegmentedBar> createState() => _SegmentedBarState();
}

class _SegmentedBarState extends State<_SegmentedBar> {
  final GlobalKey _stripKey = GlobalKey();
  List<GlobalKey> _cellKeys = const [];
  List<FocusNode> _focusNodes = const [];
  Rect? _indicatorRect;

  /// False until the first measurement lands, so the selection appears on the
  /// chosen cell without sliding in from nowhere.
  bool _indicatorPlaced = false;

  @override
  void initState() {
    super.initState();
    _rebuildCells();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant _SegmentedBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.labels.length != widget.labels.length) {
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

  int get _selectedIndex => widget.index.clamp(0, widget.labels.length - 1);

  /// Whether a segment responds to input: a whole-bar disabled control, or an
  /// individually disabled segment, does not.
  bool _cellEnabled(int index) => _active && !widget.disabled.contains(index);

  /// Whether the selection may draw as chosen: an inert bar, or a bar whose
  /// chosen segment is itself disabled, shows the grey selection.
  bool get _selectionLive => _cellEnabled(_selectedIndex);

  void _rebuildCells() {
    // The old nodes are still attached until this rebuild lands, so their
    // disposal waits for the frame's end.
    final retired = _focusNodes;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final node in retired) {
        node.dispose();
      }
    });
    _cellKeys = [for (var i = 0; i < widget.labels.length; i++) GlobalKey()];
    _focusNodes = [for (var i = 0; i < widget.labels.length; i++) FocusNode(debugLabel: 'PureSegmented.cell.$i')];
    _indicatorPlaced = false;
    _indicatorRect = null;
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  /// Places the selection over the chosen cell, wherever layout put it — this
  /// runs after every build, so a font-scale change or a language switch
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
    if (rect != _indicatorRect) {
      setState(() {
        _indicatorRect = rect;
        _indicatorPlaced = true;
      });
    }
  }

  /// Focuses the nearest enabled segment in [direction]; reports whether one was
  /// found, so a bar at its edge hands the key back to the shell.
  bool _moveFocus(int from, int direction) {
    if (!_active) {
      return false;
    }
    var next = from + direction;
    while (next >= 0 && next < widget.labels.length) {
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
      // A disabled segment must never be activated through a keyboard or TV
      // remote, even if focus was retained while the segment became disabled.
      if (_cellEnabled(index)) {
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
    // The label size rides the theme's font scale, so the user's small-text
    // preference grows the segment labels with the rest of the chrome.
    final fontRatio = theme.text.caption.fontSize! / theme.token.type.fontSizeSM;
    final labelStyle = theme.text.caption.copyWith(
      fontSize: _SegmentedMetrics.fontSize * fontRatio,
      fontWeight: FontWeight.w500,
    );
    const inset = EdgeInsets.symmetric(horizontal: _SegmentedMetrics.inset, vertical: _SegmentedMetrics.inset);
    const cellHeight = _SegmentedMetrics.height - 2 * _SegmentedMetrics.inset;
    final row = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.labels.length; i++)
          if (widget.expand)
            Expanded(child: _cell(i, visual, labelStyle, cellHeight))
          else
            _cell(i, visual, labelStyle, cellHeight),
      ],
    );
    final strip = Stack(
      key: _stripKey,
      clipBehavior: Clip.none,
      children: [if (_indicatorPlaced && _indicatorRect != null) _indicator(theme, visual), row],
    );
    final bar = SizedBox(height: _SegmentedMetrics.height, child: visual.track(theme, strip, inset));
    if (_active) {
      return bar;
    }
    return IgnorePointer(child: bar);
  }

  Widget _indicator(PureTheme theme, _SegmentVisual visual) {
    final rect = _indicatorRect!;
    final child = DecoratedBox(decoration: visual.indicator(theme, active: _selectionLive));
    // The first placement snaps; every later one slides.
    if (_indicatorPlaced) {
      return AnimatedPositioned.fromRect(
        rect: rect,
        duration: context.themeFor.duration,
        curve: Curves.easeOutCubic,
        child: child,
      );
    }
    return Positioned.fromRect(rect: rect, child: child);
  }

  Widget _cell(int index, _SegmentVisual visual, TextStyle labelStyle, double cellHeight) {
    return _SegmentedCell(
      key: _cellKeys[index],
      label: widget.labels[index],
      selected: index == _selectedIndex,
      barActive: _active,
      enabled: _cellEnabled(index),
      visual: visual,
      labelStyle: labelStyle,
      cellHeight: cellHeight,
      focusNode: _focusNodes[index],
      onKeyEvent: (node, event) => _handleKey(index, event),
      onSelect: () => widget.select?.call(index),
    );
  }
}

extension on BuildContext {
  /// The resolved theme, read the way every component here does.
  PureTheme get themeFor => PureTheme.of(this);
}

/// One cell: interaction states (hover, pressed, focus, disabled), and the
/// semantics that name it for a screen reader.
class _SegmentedCell extends StatefulWidget {
  const new({
    required this.label,
    required this.selected,
    required this.barActive,
    required this.enabled,
    required this.visual,
    required this.labelStyle,
    required this.cellHeight,
    required this.focusNode,
    required this.onKeyEvent,
    required this.onSelect,
    super.key,
  });

  final String label;

  final bool selected;

  /// Whether the bar is live; an inert bar greys every cell out.
  final bool barActive;

  /// Whether this cell responds to input (the bar is live and it is not itself
  /// disabled).
  final bool enabled;

  final _SegmentVisual visual;

  final TextStyle labelStyle;

  /// The cell's minimum height: the control height less the track's inset.
  final double cellHeight;

  final FocusNode focusNode;

  final KeyEventResult Function(FocusNode node, KeyEvent event) onKeyEvent;

  final VoidCallback onSelect;

  @override
  State<_SegmentedCell> createState() => _SegmentedCellState();
}

class _SegmentedCellState extends State<_SegmentedCell> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.themeFor;
    final visual = widget.visual;
    final enabled = widget.enabled;
    final selected = widget.selected && widget.barActive;
    final color = visual.content(theme, selected: selected, hovered: _hovered, pressed: _pressed, enabled: enabled);
    final tint = !selected && enabled
        ? (_pressed
              ? visual.pressedTint(theme)
              : _hovered
              ? visual.hoverTint(theme)
              : null)
        : null;

    final style = widget.labelStyle.copyWith(color: color);
    final text = Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);

    // The focus ring (all sides, so it may round) is painted through a static
    // [DecoratedBox] rather than the container's `foregroundDecoration`,
    // because the container would *tween* it — and lerping a hairline into a
    // rounded ring passes through a non-uniform border with a radius, which
    // Flutter refuses to paint. The background tint still animates on the
    // container itself.
    final foreground = _focused
        ? BoxDecoration(
            borderRadius: visual.cellRadius,
            border: Border.fromBorderSide(BorderSide(color: theme.colors.primary, width: _SegmentedMetrics.focusWidth)),
          )
        : null;

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
            label: widget.label,
            child: DecoratedBox(
              decoration: foreground ?? const BoxDecoration(),
              position: DecorationPosition.foreground,
              child: AnimatedContainer(
                duration: theme.duration,
                curve: Curves.easeOut,
                alignment: AlignmentDirectional.center,
                padding: const EdgeInsets.symmetric(horizontal: _SegmentedMetrics.horizontalPadding),
                constraints: BoxConstraints(minHeight: widget.cellHeight),
                decoration: BoxDecoration(color: tint, borderRadius: visual.cellRadius),
                child: text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
