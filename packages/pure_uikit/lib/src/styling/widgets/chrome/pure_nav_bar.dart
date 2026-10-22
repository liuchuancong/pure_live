import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pure_uikit/src/scales/radii.dart';
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

/// The kit's bottom navigation bar, all of it painted here.
///
/// A shell passes its destinations here instead of a platform bar. The bar
/// draws WinUI's NavigationView footer: two-line compact cells on the chrome
/// surface under a hairline, the chosen one in the accent with the 6x3 pill
/// at the bar's top edge — the bar the Store and Media Player draw. The
/// libraries ship no bar that can slide a selection between cells — several
/// ship no bar at all — and the point of this widget is the one selection
/// that travels between cells, so nothing is delegated; colours, radii,
/// motion and text come from [PureTheme], so a dark switch still comes out
/// right. The config's `language` names the bar's identity key only — a
/// non-fluent value keeps compiling and simply draws this footer.
///
/// Every visual answers to the same interaction contract: hover and pressed
/// tints, an inert bar (a null [onChanged] or `enabled: false`) that answers
/// nothing and greys its selection, disabled destinations, focus rings and
/// Left/Right traversal with Enter/Space selection for keyboards and remotes,
/// screen-reader traits on every cell (each reads as a button that is or is
/// not selected) inside a container, and a mark that slides to the chosen
/// destination over the theme's motion duration. The bar fills the width it is
/// given and carries its own height — give a call site only a width, and it
/// splits that width into equal cells.
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

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = PureTheme.of(context);
    // A null callback is the inert state, so folding `enabled` into it once
    // gives the bar a single verdict.
    final select = enabled ? onChanged : null;
    final bar = _NavBarBody(
      items: items,
      index: index,
      select: select,
      languageName: theme.config.language.name,
      visual: _NavVisual.fluentFooter(),
    );
    // The strip is one container of destinations, not loose buttons; the
    // container role lets a screen reader announce the whole bar.
    return Semantics(container: true, child: bar);
  }
}

/// How the bar is painted: its height and surface, the sliding mark, the
/// interaction tints, and the colour of a cell's content in each state. The
/// sizes are absolute pixels — a platform bar keeps its height whatever the
/// tokens say — while colours, radii and text ride the theme.
@immutable
final class _NavVisual {
  const new({
    required this.height,
    required this.inset,
    required this.iconSize,
    required this.fontSize,
    required this.cellRadius,
    required this.track,
    required this.indicator,
    required this.hoverTint,
    required this.pressedTint,
    required this.content,
    required this.markSize,
  });

  /// WinUI's NavigationView footer: two-line compact cells on the chrome
  /// surface under a hairline, the chosen one in the accent with the 6x3 pill
  /// at the bar's top edge — the bar the Store and Media Player draw.
  factory fluentFooter() {
    return _NavVisual(
      height: 48,
      inset: EdgeInsets.zero,
      iconSize: 16,
      fontSize: 12,
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
      markSize: const Size(6, 3),
    );
  }

  /// The bar's own height, absolute pixels: 48 for the Windows footer — the
  /// tier the platform strip keeps whatever the tokens say about colour.
  final double height;

  /// The padding the frame puts around the strip (and so around the mark).
  final EdgeInsets inset;

  /// The glyph size inside a cell.
  final double iconSize;

  /// The label size, before the theme's font scale.
  final double fontSize;

  /// The corner radius of a cell's hover tint and focus ring.
  final BorderRadius cellRadius;

  /// Wraps the framed strip: surface colour, hairline, safe area — whatever
  /// the bar puts around the cells.
  final Widget Function(PureTheme theme, Widget frame) track;

  /// The decoration of the sliding mark, with the `active` flag telling the
  /// accent's chosen colour apart from the grey one an inert bar shows.
  final Decoration Function(PureTheme theme, {required bool active}) indicator;

  /// The mark's fixed size: the 6x3 dash on the bar's top edge.
  final Size markSize;

  /// The tint behind a hovered, unselected cell; null draws none.
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

/// The sliding mark and the cells: it measures the chosen cell after layout,
/// slides the mark there, moves focus with the arrow keys and keeps an inert
/// bar greyed.
class _NavBarBody extends StatefulWidget {
  const new({
    required this.items,
    required this.index,
    required this.select,
    required this.languageName,
    required this.visual,
  });

  final List<PureNavBarItem> items;

  final int index;

  final ValueChanged<int>? select;

  /// The active design language's name — kept only to name the branch key, so
  /// tests and diagnostics can address the shape a bar is wearing.
  final String languageName;

  final _NavVisual visual;

  @override
  State<_NavBarBody> createState() => _NavBarBodyState();
}

class _NavBarBodyState extends State<_NavBarBody> {
  static const Key _markKey = ValueKey('PureNavBar.mark');
  final GlobalKey _stripKey = GlobalKey();
  List<GlobalKey> _cellKeys = const [];
  List<FocusNode> _focusNodes = const [];
  Rect? _cellRect;

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
    _focusNodes = [for (var i = 0; i < widget.items.length; i++) FocusNode(debugLabel: 'PureNavBar.cell.$i')];
    _markPlaced = false;
    _cellRect = null;
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
    if (cell != _cellRect) {
      setState(() {
        _cellRect = cell;
        _markPlaced = true;
      });
    }
  }

  /// The mark's rect inside the strip: the dash centred on the chosen cell's
  /// top edge, at the visual's own size.
  Rect? _markRect(_NavVisual visual) {
    final cell = _cellRect;
    if (cell == null) {
      return null;
    }
    return Rect.fromLTWH(
      cell.center.dx - visual.markSize.width / 2,
      cell.top,
      visual.markSize.width,
      visual.markSize.height,
    );
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
    final bar = KeyedSubtree(key: ValueKey('PureNavBar.${widget.languageName}'), child: visual.track(theme, frame));
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
        Icon(widget.item.icon, size: widget.iconSize, color: color),
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
