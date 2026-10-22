import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pure_uikit/src/adaptive/adaptive_shell_sizes.dart';
import 'package:pure_uikit/src/adaptive/adaptive_surface_tokens.dart';
import 'package:pure_uikit/src/adaptive/navigation/adaptive_brand_mark.dart';
import 'package:pure_uikit/src/adaptive/navigation/navigation_item.dart';
import 'package:pure_uikit/src/scales/spacing.dart';

/// A compact, icon-over-label navigation rail for tablets and medium windows.
///
/// The rail keeps the navigation persistent without stealing content width.
/// It draws the same selection grammar as the expanded sidebar's pane — a
/// soft fill under the chosen destination and the accent pill riding its
/// start edge, which travels between destinations with the same stretch the
/// pane's indicator uses — at the rail's own icon-over-label scale.
class PureNavigationRail extends StatefulWidget {
  /// A rail [width] wide listing [destinations].
  const new({
    required this.destinations,
    required this.selectedId,
    required this.onDestinationSelected,
    this.width = AdaptiveShellSizes.compactRailWidth,
    this.header,
    this.footer,
    this.brand,
    this.onBrandTap,
    this.showBrand = true,
    this.backgroundColor,
    super.key,
  });

  /// The destinations, top to bottom.
  final List<PureNavDestination> destinations;

  /// The selected destination's id.
  final String selectedId;

  /// Called with the tapped destination.
  final ValueChanged<PureNavDestination> onDestinationSelected;

  /// The rail's width.
  final double width;

  /// Replaces the default brand header.
  final Widget? header;

  /// Optional content pinned below the destination list.
  final Widget? footer;

  /// The brand mark shown at the rail's head.
  final Widget? brand;

  /// The brand's tap handler (usually "go home").
  final VoidCallback? onBrandTap;

  /// Whether the brand header is shown.
  final bool showBrand;

  /// Overrides the rail's background.
  final Color? backgroundColor;

  @override
  State<PureNavigationRail> createState() => _PureNavigationRailState();
}

class _PureNavigationRailState extends State<PureNavigationRail>
    with SingleTickerProviderStateMixin {
  /// The selection pill's geometry, at the tile's start edge: the pane's
  /// indicator at the rail's own scale.
  static const double _pillWidth = 3;
  static const double _pillHeight = 18;
  static const double _pillInset = 4;

  final GlobalKey _stackKey = GlobalKey();
  List<GlobalKey> _cellKeys = const [];

  /// Where the pill stands now, and where it travels from — the previously
  /// selected destination — while [_slide] runs.
  Rect? _pillRect;
  Rect? _pillFrom;

  /// False until the first measurement lands, so the pill appears on the
  /// chosen destination without sliding in from nowhere.
  bool _placed = false;

  /// Set when the selection changed, so the next measurement travels from
  /// the old pill; a scroll or relayout re-seats it without an animation.
  bool _travelPending = false;

  /// The pill's travel driver: the leading edge moves first and the trailing
  /// one catches up, so the pill stretches on its way — the pane's
  /// selection-indicator motion.
  late final AnimationController _slide = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _rebuildCells();
    _scheduleMeasure();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSlideDuration();
  }

  @override
  void didUpdateWidget(covariant PureNavigationRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destinations.length != widget.destinations.length) {
      _rebuildCells();
    }
    if (oldWidget.selectedId != widget.selectedId) {
      _travelPending = true;
    }
    _scheduleMeasure();
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  /// Honours the theme's motion switch and the system's reduce-motion
  /// request: a zero duration snaps the pill to its place.
  void _syncSlideDuration() {
    final motionOff =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _slide.duration = motionOff ? Duration.zero : const Duration(milliseconds: 350);
  }

  int get _selectedIndex =>
      widget.destinations.indexWhere((d) => d.id == widget.selectedId);

  void _rebuildCells() {
    _cellKeys = [
      for (var i = 0; i < widget.destinations.length; i++) GlobalKey(),
    ];
    _placed = false;
    _pillRect = null;
    _pillFrom = null;
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  /// Places the pill over the chosen destination's start edge, wherever
  /// layout put it — this runs after every build and after every scroll
  /// tick, so the pill stays glued through both. A change of place from an
  /// already-placed pill is what starts the stretch-slide from the old one.
  void _measure() {
    if (!mounted) {
      return;
    }
    final stackBox = _stackKey.currentContext?.findRenderObject();
    final index = _selectedIndex;
    if (stackBox is! RenderBox || index < 0 || index >= _cellKeys.length) {
      return;
    }
    final cellBox = _cellKeys[index].currentContext?.findRenderObject();
    if (cellBox is! RenderBox || !cellBox.hasSize) {
      return;
    }
    final offset = cellBox.localToGlobal(Offset.zero, ancestor: stackBox);
    final rect = Rect.fromLTWH(
      offset.dx + _pillInset,
      offset.dy + (cellBox.size.height - _pillHeight) / 2,
      _pillWidth,
      _pillHeight,
    );
    if (rect == _pillRect) {
      return;
    }
    final from = _travelPending && _placed ? _pillRect : null;
    _travelPending = false;
    setState(() {
      _pillRect = rect;
      _placed = true;
      _pillFrom = from;
    });
    if (from != null) {
      _slide.forward(from: 0);
    }
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  Widget _pill({required AdaptiveSurfaceColors colors}) {
    final target = _pillRect!;
    final from = _pillFrom;
    final child = Container(
      width: _pillWidth,
      decoration: BoxDecoration(
        color: colors.brand,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
    // The first placement snaps; every later one travels — the leading edge
    // moves first and the trailing one catches up, so the pill stretches as
    // it goes, the way the pane's selection does.
    if (from == null || _slide.duration == Duration.zero) {
      return Positioned.fromRect(rect: target, child: child);
    }
    return AnimatedBuilder(
      animation: _slide,
      builder: (context, _) {
        final t = _slide.value;
        var rect = target;
        if (t < 1) {
          final movingDown = target.center.dy >= from.center.dy;
          final lead = Curves.easeOutCubic.transform((t / 0.65).clamp(0.0, 1.0));
          final trail = Curves.easeInOutCubic.transform(
            ((t - 0.25) / 0.75).clamp(0.0, 1.0),
          );
          final top = _lerp(from.top, target.top, movingDown ? lead : trail);
          final bottom = _lerp(
            from.bottom,
            target.bottom,
            movingDown ? trail : lead,
          );
          rect = Rect.fromLTRB(
            target.left,
            top,
            target.right,
            math.max(bottom, top + 2),
          );
        }
        return Positioned.fromRect(rect: rect, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdaptiveSurfaceColors.of(context);

    final resolvedHeader =
        widget.header ??
        (widget.showBrand
            ? Padding(
                padding: const EdgeInsets.fromLTRB(PureSpacing.sm, PureSpacing.lg, PureSpacing.sm, PureSpacing.lg),
                child: Center(
                  child: widget.brand ?? AdaptiveBrandMark(onTap: widget.onBrandTap, size: 32),
                ),
              )
            : null);

    final list = ListView(
      padding: const EdgeInsets.symmetric(horizontal: PureSpacing.xs, vertical: PureSpacing.xs),
      children: <Widget>[
        for (int index = 0; index < widget.destinations.length; index++) ...<Widget>[
          if (widget.destinations[index].startsGroup && index > 0)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PureSpacing.sm,
                vertical: PureSpacing.xs,
              ),
              child: Divider(height: 1, color: colors.border),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: PureNavigationTile(
              key: index < _cellKeys.length ? _cellKeys[index] : null,
              destination: widget.destinations[index],
              selected: widget.destinations[index].id == widget.selectedId,
              onTap: () => widget.onDestinationSelected(widget.destinations[index]),
              layout: PureNavigationTileLayout.vertical,
              // The compact pane: the icon alone, larger, named by its
              // tooltip — the label returns when the pane expands.
              iconSize: 22,
              height: 44,
              showLabel: false,
              showSelectedBar: false,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      container: true,
      label: 'Main navigation',
      child: Container(
        width: widget.width,
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? colors.sidebar,
          border: Border(right: BorderSide(color: colors.border)),
        ),
        child: SafeArea(
          right: false,
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ?resolvedHeader,
              Expanded(
                // The pill rides over the list, glued to the chosen
                // destination through scrolls and relayouts by the
                // post-frame measure above.
                child: Stack(
                  key: _stackKey,
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    NotificationListener<ScrollNotification>(
                      onNotification: (_) {
                        _scheduleMeasure();
                        return false;
                      },
                      child: list,
                    ),
                    if (_placed && _pillRect != null)
                      _pill(colors: colors),
                  ],
                ),
              ),
              if (widget.footer != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: PureSpacing.sm),
                  child: widget.footer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
