import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:flutter/widgets.dart';
import 'package:pure_live/l10n/translations.dart';

/// The back-to-top / back-to-bottom pair every scrolling page carries.
///
/// The shell wraps its content area in this one widget, so the pair belongs
/// to what the viewer is looking at rather than to each page: the feed
/// grids, the history list, the channel browser, the settings pane and the
/// tools all get the same two buttons over the same corner, and a page adds
/// nothing to get them.
///
/// The pair stays in place while the shown page scrolls at all — it does not
/// wait for the viewer to disappear down the list — and the button whose end
/// the viewer already sits at is drawn disabled: at the head there is no top
/// to return to, at the end no bottom to reach. A page that fits its window
/// shows neither, because neither would do anything there.
///
/// The tracked scroll is the page's own vertical one: a horizontal strip
/// inside a card, or a list nested under the page's scroll, is skipped. The
/// shell keeps its other tabs alive off screen, so [pageIdentity] names what
/// is shown and the pair re-attaches when that changes.
///
/// The buttons are a keyed layer of a [Stack] built once around the content:
/// showing or hiding them never changes what occupies the content slot, so a
/// page's scroll position is never torn down and re-attached at the head.
final class ScrollEdgeControls extends StatefulWidget {
  /// Wraps [child], the scrolling page. [pageIdentity] names what the shell
  /// shows; a new one re-reads the page.
  const ScrollEdgeControls({required this.child, this.pageIdentity, this.showControls = true, super.key});

  /// The page being scrolled.
  final Widget child;

  /// What the shell is showing.
  final Object? pageIdentity;

  /// Whether the pair draws at all. A module whose corner is a playing
  /// picture — the IPTV browser's embedded player — turns it off: the two
  /// floating circles would stand between the viewer and the channel, and
  /// the lists that scroll beside it need no jump to their ends.
  final bool showControls;

  @override
  State<ScrollEdgeControls> createState() => _ScrollEdgeControlsState();
}

final class _ScrollEdgeControlsState extends State<ScrollEdgeControls> {
  /// How far from the content's bottom-trailing corner the pair sits.
  static const double _inset = DsSpace.s20;

  /// How far from either edge counts as being there: a page a pixel off its
  /// end reads as sitting at it.
  static const double _epsilon = 1;

  /// The scroll the pair drives.
  ScrollPosition? _position;

  /// Where that scroll stands, so a rebuild can answer "at which end?"
  /// without touching a position that has since detached.
  double _pixels = 0;
  double _min = 0;
  double _max = 0;

  /// The three answers the pair shows, kept as flags: the notification stream
  /// fires every frame while the viewer scrolls, and only one of these
  /// actually moving is worth a rebuild.
  bool _scrollable = false;
  bool _atTop = true;
  bool _atEnd = false;

  @override
  void initState() {
    super.initState();
    _rescan();
  }

  @override
  void didUpdateWidget(ScrollEdgeControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A tab, a pushed page, a popped one: the shown scroll is another one
    // now, and nothing scrolls to say so — go and look for it. The switch
    // that hides the pair re-reads too, so it detaches on the way down.
    if (oldWidget.pageIdentity != widget.pageIdentity || oldWidget.showControls != widget.showControls) {
      _rescan();
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_onScrollChanged);
    super.dispose();
  }

  /// Finds the shown page's scroll after a frame: the walk needs it laid out,
  /// which it is not while this build is still running. A hidden pair tracks
  /// nothing — it detaches instead, and the buttons leave with it.
  void _rescan() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _attach(widget.showControls ? _visibleScroll(context) : null);
    });
  }

  /// Points the pair at [position], following it from then on.
  void _attach(ScrollPosition? position) {
    if (position == null) {
      _position?.removeListener(_onScrollChanged);
      _position = null;
      _publish(scrollable: false);
      return;
    }
    if (!identical(_position, position)) {
      _position?.removeListener(_onScrollChanged);
      _position = position;
      position.addListener(_onScrollChanged);
    }
    _read();
  }

  void _onScrollChanged() => _read();

  /// Re-reads the tracked scroll and rebuilds only when an answer moved.
  void _read() {
    final position = _position;
    if (position == null || !position.hasPixels || !position.hasContentDimensions) return;
    _pixels = position.pixels;
    _min = position.minScrollExtent;
    _max = position.maxScrollExtent;
    _publish(scrollable: _max - _min > _epsilon, atTop: _pixels <= _min + _epsilon, atEnd: _pixels >= _max - _epsilon);
  }

  void _publish({required bool scrollable, bool? atTop, bool? atEnd}) {
    final nextTop = atTop ?? _atTop;
    final nextEnd = atEnd ?? _atEnd;
    if (scrollable == _scrollable && nextTop == _atTop && nextEnd == _atEnd) return;
    _scrollable = scrollable;
    _atTop = nextTop;
    _atEnd = nextEnd;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      // A scroll whose extent changed is reported during layout, where
      // marking this element dirty is not allowed; the next frame shows it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  /// Follows the page's own vertical scroll: a horizontal strip inside a card,
  /// or a list nested under the page's scroll, is not what these are for.
  bool _onNotification(ScrollNotification notification) {
    if (!widget.showControls) return false;
    if (notification.depth != 0) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    final position = _positionOf(notification.context);
    if (position == null) return false;
    _attach(position);
    return false;
  }

  /// A page that grew or shrank, or a skeleton that was replaced by its
  /// loaded grid, says so with a metrics notification while it lays out.
  /// Attach after the frame, where adding a listener and rebuilding belongs.
  bool _onMetrics(ScrollMetricsNotification notification) {
    if (!widget.showControls) return false;
    if (notification.depth != 0) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    final position = _positionOf(notification.context);
    if (position == null) return false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _attach(position);
    });
    return false;
  }

  /// The position a notification came from: the notification's context sits
  /// inside the scrollable's gesture detector, so the state is found through
  /// the nearest vertical [Scrollable], not by assuming the context itself is
  /// the scrollable.
  ScrollPosition? _positionOf(BuildContext? context) {
    if (context == null) return null;
    return Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
  }

  /// The shown page's outermost vertical scroll: the first one a walk down
  /// what is actually on screen reaches. The shell's branch stack and any
  /// off-stage page keep scrolls of their own; those are not the one shown.
  ScrollPosition? _visibleScroll(BuildContext root) {
    if (root is! Element) return null;
    ScrollPosition? found;
    void visit(Element element) {
      if (found != null) return;
      final widget = element.widget;
      if (widget is Offstage && widget.offstage) return;
      if (widget is IndexedStack) {
        var index = 0;
        final shown = widget.index;
        element.visitChildren((child) {
          if (index == shown) visit(child);
          index++;
        });
        return;
      }
      if (widget is Scrollable) {
        final state = element is StatefulElement ? element.state : null;
        if (state is ScrollableState && state.position.axis == Axis.vertical) found = state.position;
        return;
      }
      element.visitChildren(visit);
    }

    root.visitChildren(visit);
    return found;
  }

  void _jump({required bool toTop}) {
    final position = _position;
    if (position == null || !position.hasContentDimensions) return;
    unawaited(
      position.animateTo(toTop ? _min : _max, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onNotification,
        child: Stack(
          children: [
            Positioned.fill(key: const ValueKey('scrollEdgeContent'), child: widget.child),
            if (_scrollable && widget.showControls)
              Positioned(
                key: const ValueKey('scrollEdgeButtons'),
                right: _inset,
                bottom: _inset,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  spacing: DsSpace.s8,
                  children: [
                    _EdgeButton(
                      icon: DsIcons.arrowUp,
                      label: context.t.common.backToTop,
                      enabled: !_atTop,
                      onPressed: () => _jump(toTop: true),
                    ),
                    _EdgeButton(
                      icon: DsIcons.arrowDown,
                      label: context.t.common.backToBottom,
                      enabled: !_atEnd,
                      onPressed: () => _jump(toTop: false),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One button of the pair: the floating circle the feeds used to show, drawn
/// muted and inert when its end of the page is already where the viewer is.
final class _EdgeButton extends StatelessWidget {
  const _EdgeButton({required this.icon, required this.label, required this.enabled, required this.onPressed});

  final DsIconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DsTooltip(
      message: label,
      child: SizedBox(
        width: _edgeButtonSide,
        height: _edgeButtonSide,
        child: DsPressable(
          semanticLabel: label,
          onPressed: enabled ? onPressed : null,
          builder: (context, states, _) {
            final hovered = enabled && states.contains(WidgetState.hovered);
            return Container(
              alignment: Alignment.center,
              decoration: DsBoxDecoration(
                color: colors.overlay,
                borderRadius: BorderRadius.circular(_edgeButtonSide / 2),
                shadows: [...theme.shadows.overlay, if (hovered) ...theme.shadows.surfaceRaised],
              ),
              child: DsIcon(
                icon,
                size: 18,
                color: !enabled ? colors.textSubtle : (hovered ? colors.accent : colors.text),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The buttons' diameter.
const double _edgeButtonSide = 44;
