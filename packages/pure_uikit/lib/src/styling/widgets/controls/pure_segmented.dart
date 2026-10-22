import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pure_uikit/src/scales/radii.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The kit's segmented control: one row of mutually-exclusive choices, drawn
/// in every design language.
///
/// Where `PureTabBar` is the page-navigation strip — a pill or an ink bar that
/// names *where you are* — this is the compact picker that names *what you
/// chose*: list or grid, playlist or stream, fit or fill. Every language reads
/// that one-row grammar its own way: Material 3's outlined stadium with a
/// leading check on the chosen segment and hairline dividers between the rest,
/// iOS's grey track under a floating white thumb with the selected label
/// emphasised, macOS 13's contiguous bar tinting the chosen cell with the
/// accent, WinUI's SelectionBar pill sliding behind the selection on a
/// contained track, Yaru's linked buttons with rounded ends and a checked tint,
/// shadcn's bordered tabs list with a lifted filled cell, a frosted stadium
/// under glass, a raised track with the chosen cell pressed in under neumorphic,
/// and — following the tab bar's own wind branch — the accent pill again. All of
/// it is painted here, because the sliding selection is exactly what the
/// libraries ship inconsistently; the colours, radii, motion and text come from
/// the tokens, so a language re-skin and a dark switch still come out right.
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

  /// The design language's reading of a segmented pick, chosen from the resolved
  /// theme's tokens so a re-skin and a dark switch re-seat the geometry too.
  _SegmentVisual _resolveVisual(PureTheme theme) {
    final radii = theme.token.scale.radii;
    return switch (theme.config.language) {
      PureDesignLanguage.material => _SegmentVisual.checkedPill(),
      PureDesignLanguage.cupertino => _SegmentVisual.iosTrack(),
      PureDesignLanguage.macos => _SegmentVisual.linked(trackRadius: radii.base, accent: true),
      PureDesignLanguage.yaru => _SegmentVisual.linked(trackRadius: radii.lg, accent: false),
      PureDesignLanguage.fluent => _SegmentVisual.accentPill(trackRadius: radii.base),
      // The tab bar draws wind with the same contained accent pill it gives
      // fluent for a segmented pick; the segmented control follows suit.
      PureDesignLanguage.wind => _SegmentVisual.accentPill(trackRadius: radii.base),
      PureDesignLanguage.forui => _SegmentVisual.foruiTabs(),
      PureDesignLanguage.glass => _SegmentVisual.glass(),
      PureDesignLanguage.neumorphic => _SegmentVisual.neumorphic(),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = PureTheme.of(context);
    // A null callback is every library's inert state, so folding `enabled` into
    // it once serves every branch.
    final select = enabled ? onChanged : null;
    final bar = _SegmentedBar(
      labels: labels,
      index: index,
      select: select,
      expand: expand,
      disabled: disabledIndexes,
      visual: _resolveVisual(theme),
    );
    // A segmented control is one container of buttons, not a bare stack of them;
    // the container role lets a screen reader announce the whole choice.
    return Semantics(container: true, child: bar);
  }
}

/// The geometry a segmented bar lays out: absolute pixels, so the control keeps
/// its compact height whatever the design language makes of its colour. Text
/// still rides the theme's font scale, and colour and radius come from tokens.
abstract final class _SegmentedMetrics {
  /// 32 — the control's height, the segmented bar's own tier (the tab bar is
  /// taller because it carries icons and badges; this carries one label).
  static const double height = 32;

  /// 3 — the track's padding around the cells, and so around the sliding pill.
  static const double inset = 3;

  /// 14 — the padding on either side of a cell's label.
  static const double horizontalPadding = 14;

  /// 15 — the leading check a Material 3 chosen segment draws.
  static const double checkSize = 15;

  /// 6 — the gap between that check and the label.
  static const double checkGap = 6;

  /// 13 — the label size before the theme's font scale.
  static const double fontSize = 13;

  /// 2 — the focus ring's width.
  static const double focusWidth = 2;
}

/// How one design language paints the segmented bar: the track it sits on, the
/// sliding selection behind the chosen cell, the interaction tints, the hairline
/// dividers, and the colour and weight of a cell's label in each state.
@immutable
final class _SegmentVisual {
  const new({
    required this.track,
    required this.cellRadius,
    required this.indicator,
    required this.hoverTint,
    required this.pressedTint,
    required this.content,
    this.contiguous = false,
    this.dividers = false,
    this.checkIcon = false,
    this.selectedEmphasis = false,
  });

  /// Material 3's single-select `SegmentedButton`: an outlined stadium track with
  /// no fill, the chosen segment filled a soft secondary over a leading check,
  /// and hairline dividers between the segments that are not chosen.
  factory checkedPill() {
    final pill = BorderRadius.circular(PureRadii.pill);
    return _SegmentVisual(
      cellRadius: pill,
      dividers: true,
      checkIcon: true,
      track: (theme, strip, inset) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: pill,
          border: Border.all(color: theme.colors.border),
        ),
        child: Padding(padding: inset, child: strip),
      ),
      indicator: (theme, {required active}) =>
          BoxDecoration(color: active ? theme.colors.fill : theme.colors.fillTertiary, borderRadius: pill),
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      content: (theme, {required selected, required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (selected || pressed || hovered) {
          return theme.colors.text;
        }
        return theme.colors.textSecondary;
      },
    );
  }

  /// iOS's `UISegmentedControl`: a grey stadium track, a floating white thumb
  /// behind the chosen cell, its label emphasised, hairline separators between
  /// the cells the thumb does not cover. Hover and press answer in the text
  /// alone — the thumb is the whole affordance.
  factory iosTrack() {
    final pill = BorderRadius.circular(PureRadii.pill);
    return _SegmentVisual(
      cellRadius: pill,
      dividers: true,
      selectedEmphasis: true,
      track: (theme, strip, inset) => DecoratedBox(
        decoration: BoxDecoration(color: theme.colors.fillSecondary, borderRadius: pill),
        child: Padding(padding: inset, child: strip),
      ),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.colors.bgElevated : theme.colors.bgContainer,
        borderRadius: pill,
        boxShadow: [
          BoxShadow(
            color: theme.colors.shadowBase.withValues(alpha: theme.isDark ? 0.3 : 0.16),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      hoverTint: (_) => null,
      pressedTint: (_) => null,
      content: (theme, {required selected, required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (selected || pressed || hovered) {
          return theme.colors.text;
        }
        return theme.colors.textSecondary;
      },
    );
  }

  /// macOS's `NSSegmentedControl` and Yaru's linked buttons: one contiguous
  /// rounded bar whose cells are flush (the track clips the outer ends), thin
  /// separators between the unchosen cells, and a checked cell. macOS 13 tints
  /// that cell with the accent and sets its label in the accent; Yaru greys it
  /// and keeps the label where it was.
  factory linked({required double trackRadius, required bool accent}) {
    final radius = BorderRadius.circular(trackRadius);
    return _SegmentVisual(
      cellRadius: radius,
      contiguous: true,
      dividers: true,
      track: (theme, strip, inset) => DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.bgContainer,
          borderRadius: radius,
          border: Border.all(color: theme.colors.borderSecondary),
        ),
        child: ClipRRect(borderRadius: radius, child: strip),
      ),
      indicator: (theme, {required active}) => BoxDecoration(
        color: !active
            ? theme.colors.fillTertiary
            : accent
            ? theme.colors.primaryBg
            : theme.colors.fill,
        borderRadius: BorderRadius.circular(trackRadius / 2),
      ),
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      content: accent
          ? (theme, {required selected, required hovered, required pressed, required enabled}) {
              if (!enabled) {
                return theme.colors.textQuaternary;
              }
              if (selected) {
                return theme.colors.primary;
              }
              if (pressed || hovered) {
                return theme.colors.text;
              }
              return theme.colors.text;
            }
          : (theme, {required selected, required hovered, required pressed, required enabled}) {
              if (!enabled) {
                return theme.colors.textQuaternary;
              }
              if (selected || pressed || hovered) {
                return theme.colors.text;
              }
              return theme.colors.textSecondary;
            },
    );
  }

  /// WinUI's `SelectionBar` and the wind reading the tab bar shares with it: the
  /// chosen cell sits under a pill that slides behind it on a contained, bordered
  /// track — segmented keeps its own surface rather than dissolving into the
  /// page, the difference the tab bar's own note draws between the two.
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

  /// shadcn's tabs list: a bordered, muted track with the chosen cell lifted as
  /// an elevated, shadowed surface — the toggle a `TabsList` hands its active
  /// tab.
  factory foruiTabs() {
    final radius = BorderRadius.circular(PureRadii.sm);
    return _SegmentVisual(
      cellRadius: radius,
      selectedEmphasis: true,
      track: (theme, strip, inset) => DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.fillSecondary,
          borderRadius: radius,
          border: Border.all(color: theme.colors.borderSecondary),
        ),
        child: Padding(padding: inset, child: strip),
      ),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.colors.bgContainer : theme.colors.fillTertiary,
        borderRadius: radius,
        boxShadow: active
            ? [
                BoxShadow(
                  color: theme.colors.shadowBase.withValues(alpha: theme.isDark ? 0.3 : 0.08),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ]
            : const [],
      ),
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      content: (theme, {required selected, required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (selected || pressed || hovered) {
          return theme.colors.text;
        }
        return theme.colors.textSecondary;
      },
    );
  }

  /// The glass language: a frosted stadium track (real backdrop blur when the
  /// device can afford it) with a gradient accent pill sliding behind the chosen
  /// cell.
  factory glass() {
    Color tint(PureTheme theme, double alpha) =>
        theme.isDark ? Colors.white.withValues(alpha: alpha) : Colors.black.withValues(alpha: alpha);
    return _SegmentVisual(
      cellRadius: BorderRadius.circular(PureRadii.pill),
      track: (theme, strip, inset) {
        final radius = BorderRadius.circular(PureRadii.pill);
        final filled = DecoratedBox(
          decoration: BoxDecoration(
            color: theme.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.55),
            borderRadius: radius,
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
          borderRadius: radius,
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: filled),
        );
      },
      indicator: (theme, {required active}) {
        final radius = BorderRadius.circular(PureRadii.pill);
        if (!active) {
          return BoxDecoration(color: theme.colors.fill, borderRadius: radius);
        }
        return BoxDecoration(
          borderRadius: radius,
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

  /// The neumorphic language: a raised track (light from the top left, shadow
  /// from the bottom right) and the chosen cell pressed into it (the shadows
  /// reversed).
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
    final pill = BorderRadius.circular(PureRadii.pill);
    return _SegmentVisual(
      cellRadius: pill,
      track: (theme, strip, inset) => DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.bgContainer,
          borderRadius: BorderRadius.circular(theme.token.scale.radii.lg),
          boxShadow: raised(theme),
        ),
        child: Padding(padding: inset, child: strip),
      ),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.colors.primaryBg : theme.colors.fill,
        borderRadius: pill,
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

  /// Wraps the strip: decoration, clip, blur, padding — whatever the language
  /// puts around the cells. The `inset` argument is the track padding (zero for
  /// a [contiguous] language, whose cells are flush and clipped).
  final Widget Function(PureTheme theme, Widget strip, EdgeInsets inset) track;

  /// The corner radius of a cell's hover tint and focus ring.
  final BorderRadius cellRadius;

  /// The decoration of the sliding selection behind the chosen cell, with the
  /// `active` flag telling the language's chosen colour apart from the grey one
  /// an inert bar shows.
  final Decoration Function(PureTheme theme, {required bool active}) indicator;

  /// The tint behind a hovered, unselected cell; null is the languages that
  /// answer a hover in the text colour alone.
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

  /// Whether the cells are flush and clipped at the bar's ends (macOS, Yaru)
  /// rather than floating inside a padded track.
  final bool contiguous;

  /// Whether a hairline divider is drawn between two adjacent unselected cells.
  final bool dividers;

  /// Whether the chosen cell draws a leading check (Material 3).
  final bool checkIcon;

  /// Whether the chosen cell sets its label in a heavier weight (iOS, shadcn).
  final bool selectedEmphasis;

  /// The label colours the filled-pill languages share: solid white on the
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

/// The sliding selection and the cells, shared by every language: it measures
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
    final inset = visual.contiguous
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: _SegmentedMetrics.inset, vertical: _SegmentedMetrics.inset);
    final cellHeight = _SegmentedMetrics.height - 2 * (visual.contiguous ? 0 : _SegmentedMetrics.inset);
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

  /// Whether a hairline divider belongs on [index]'s trailing edge: between two
  /// adjacent cells, neither of which is the chosen one.
  bool _showsDivider(int index) {
    final visual = widget.visual;
    return visual.dividers &&
        index < widget.labels.length - 1 &&
        index != _selectedIndex &&
        index + 1 != _selectedIndex;
  }

  Widget _cell(int index, _SegmentVisual visual, TextStyle labelStyle, double cellHeight) {
    return _SegmentedCell(
      key: _cellKeys[index],
      label: widget.labels[index],
      selected: index == _selectedIndex,
      barActive: _active,
      enabled: _cellEnabled(index),
      showDivider: _showsDivider(index),
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

/// One cell: interaction states (hover, pressed, focus, disabled), the leading
/// check a Material 3 chosen cell draws, the hairline divider on its trailing
/// edge, and the semantics that name it for a screen reader.
class _SegmentedCell extends StatefulWidget {
  const new({
    required this.label,
    required this.selected,
    required this.barActive,
    required this.enabled,
    required this.showDivider,
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

  /// Whether a hairline divider sits on the cell's trailing edge.
  final bool showDivider;

  final _SegmentVisual visual;

  final TextStyle labelStyle;

  /// The cell's minimum height: the control height less the track's inset, so a
  /// contiguous bar's cells are flush and full.
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

    // The chosen cell of a Material 3 bar leads with a check; the emphasis the
    // iOS and shadcn bars ask for thickens the chosen label.
    final style = widget.labelStyle.copyWith(
      color: color,
      fontWeight: selected && visual.selectedEmphasis ? FontWeight.w600 : widget.labelStyle.fontWeight,
    );
    final text = Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    final content = visual.checkIcon && selected
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, size: _SegmentedMetrics.checkSize, color: color),
              const SizedBox(width: _SegmentedMetrics.checkGap),
              text,
            ],
          )
        : text;

    // The focus ring (all sides, so it may round) and the trailing hairline (one
    // side only, which Flutter will not let carry a radius) share one foreground
    // decoration. It is painted through a static [DecoratedBox] rather than the
    // container's `foregroundDecoration`, because the container would *tween* it
    // — and lerping a hairline into a rounded ring passes through a non-uniform
    // border with a radius, which Flutter refuses to paint. The background tint
    // still animates on the container itself.
    final foreground = _focused
        ? BoxDecoration(
            borderRadius: visual.cellRadius,
            border: Border.fromBorderSide(BorderSide(color: theme.colors.primary, width: _SegmentedMetrics.focusWidth)),
          )
        : widget.showDivider
        ? BoxDecoration(
            border: Border(right: BorderSide(color: theme.colors.borderSecondary)),
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
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
