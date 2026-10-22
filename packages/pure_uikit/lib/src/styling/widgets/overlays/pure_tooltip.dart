import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// A hover/focus/long-press tooltip — a word of help dropped over the widget it
/// belongs to.
///
/// Where the earlier kit handed the bubble to each library's own tooltip widget,
/// this is the bubble drawn here, one shape per design language from the tokens —
/// Material 3's inverse pill, the iOS dark bubble, macOS's grey help tag with the
/// characteristic point that aims it at its control, WinUI's bordered flyout,
/// Ubuntu's dark bubble, the shadcn inverse plate under ForUI, the frosted card
/// under glass, the raised plate under neumorphic and the crisp bordered hint
/// under wind. The colours, radii, shadows, blur, motion and text all come from
/// the tokens, so a language re-skin and a dark switch still come out right — a
/// bubble is exactly the surface no anchor library drops into a
/// `PureConfigProvider` that sits above the [Navigator], which is why it is
/// painted here rather than borrowed.
///
/// Every shape answers to the same interaction contract: the pointer resting on
/// the trigger for [waitDuration] drops the bubble, leaving the trigger lifts it
/// again, a long press on touch pins it until the next tap anywhere, and a
/// trigger that takes keyboard focus shows it the way Flutter's own `Tooltip`
/// does. The bubble is mounted only while it is open — it is not in the tree
/// while the trigger is at rest, so a page's semantics and layout are untouched.
class PureTooltip extends StatelessWidget {
  /// A tooltip around [child].
  const new({
    required this.message,
    required this.child,
    this.waitDuration = const Duration(milliseconds: 400),
    super.key,
  });

  /// The text to reveal.
  final String message;

  /// The hovered widget.
  final Widget child;

  /// How long the pointer must rest before the bubble appears.
  final Duration waitDuration;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return _TooltipHost(
      message: message,
      waitDuration: waitDuration,
      theme: theme,
      visual: _tooltipVisual(theme),
      child: child,
    );
  }
}

/// How one design language shapes the bubble: the plate it is painted on, the air
/// inside it, the distance it keeps from its trigger, whether it aims a point at
/// that trigger, and the entrance it grows in through.
@immutable
final class _TipVisual {
  const new({
    required this.bubble,
    required this.padding,
    required this.gap,
    required this.maxWidth,
    required this.estimatedHeight,
    required this.tail,
    required this.tailColor,
    required this.content,
    required this.beginScale,
    required this.curve,
  });




  /// Windows's flyout: the bordered card WinUI drops under a hovered control, at
  /// Fluent's corner with its hairline edge and its soft elevation.
  factory fluent() => _TipVisual(
    bubble: (theme, body) => _card(
      theme,
      body,
      radius: 8,
      fill: theme.colors.surfaceElevated,
      border: theme.colors.borderSecondary,
      elevation: 8,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    gap: 6,
    maxWidth: 320,
    estimatedHeight: 38,
    tail: false,
    tailColor: (_) => null,
    content: (theme) => theme.colors.text,
    beginScale: 0.88,
    curve: Curves.easeOutBack,
  );






  /// Wraps the message in whatever the language paints behind it: the fill, the
  /// blur, the border, the shadow.
  final Widget Function(PureTheme theme, Widget body) bubble;

  /// The inset around the message.
  final EdgeInsets padding;

  /// The gap the bubble keeps from its trigger, on the side the trigger is.
  final double gap;

  /// The widest the bubble gets before the message wraps.
  final double maxWidth;

  /// The height the placement assumes before the bubble is measured — how far
  /// above a trigger the bubble has to be for there still to be room for it.
  final double estimatedHeight;

  /// Whether the language aims a point at its trigger, and the colour of that
  /// point. macOS alone does.
  final bool tail;
  final Color? Function(PureTheme theme) tailColor;

  /// The colour of the message on this plate.
  final Color Function(PureTheme theme) content;

  /// The scale the bubble grows from and the curve of the entrance — the WinUI
  /// flyout pops, the iOS bubble barely moves.
  final double beginScale;
  final Curve curve;

}

/// The plain plate: a fill, an optional hairline, and an optional elevation
/// shadow. A zero elevation asks for no shadow at all, which is how shadcn's
/// ring-only tooltip is drawn.
Widget _card(
  PureTheme theme,
  Widget body, {
  required double radius,
  required Color fill,
  Color? border,
  double elevation = 0,
}) => DecoratedBox(
  decoration: BoxDecoration(
    color: fill,
    borderRadius: BorderRadius.circular(radius),
    border: border == null ? null : Border.all(color: border),
    boxShadow: elevation <= 0 ? null : _elevation(theme, elevation),
  ),
  child: body,
);


/// The elevation shadow a floating bubble is lifted on.
List<BoxShadow> _elevation(PureTheme theme, double blur) => [
  BoxShadow(
    color: theme.colors.shadowBase.withValues(alpha: theme.isDark ? 0.5 : 0.2),
    blurRadius: blur,
    offset: Offset(0, blur / 5),
  ),
];

/// The neumorphic pair: light from the top left, shade from the bottom right.

/// The tooltip for the active design language.
_TipVisual _tooltipVisual(PureTheme theme) => _TipVisual.fluent();

/// The trigger's side of the contract: it owns the hover timer, the long-press
/// pin, the focus answer and the single [OverlayEntry] the bubble lives in while
/// it is open.
class _TooltipHost extends StatefulWidget {
  const new({
    required this.message,
    required this.waitDuration,
    required this.theme,
    required this.visual,
    required this.child,
  });

  final String message;
  final Duration waitDuration;
  final PureTheme theme;
  final _TipVisual visual;
  final Widget child;

  @override
  State<_TooltipHost> createState() => _TooltipHostState();
}

class _TooltipHostState extends State<_TooltipHost> {
  /// Where the trigger is on screen; read when the bubble opens, because the
  /// entry the bubble goes into is a subtree of the root [Overlay] and cannot
  /// look back up at this widget.
  final GlobalKey _anchorKey = GlobalKey();

  /// The signal the overlay watches: flipped false to take the bubble away
  /// through its own exit, and the entry removed only once that has run.
  final ValueNotifier<bool> _open = ValueNotifier<bool>(false);

  Timer? _timer;
  OverlayEntry? _entry;
  bool _pinned = false;
  bool _closing = false;

  @override
  void dispose() {
    _timer?.cancel();
    _entry?.remove();
    _entry = null;
    _open.dispose();
    super.dispose();
  }

  /// Whether a bubble is up. The entry outlives the bubble itself while it fades
  /// away, so this is not the same question as `an entry exists`.
  bool get _shown => _entry != null && !_closing;

  /// The trigger's box in overlay coordinates, or null while it has none.
  Rect? _anchorRect() {
    final box = _anchorKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _showAfterWait() {
    _timer?.cancel();
    if (_shown) {
      return;
    }
    _timer = Timer(widget.waitDuration, () => _show(pinned: false));
  }

  void _show({required bool pinned}) {
    _timer?.cancel();
    if (_shown) {
      return;
    }
    // Re-entered while the last bubble was still fading: that one is taken down
    // now rather than left to swallow this one, because both watch the same
    // signal. Its state goes with it, so its own exit never reports back.
    if (_closing) {
      _retire();
    }
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final anchor = _anchorRect();
    if (overlay == null || anchor == null) {
      return;
    }
    // Which side of the trigger the bubble goes on is decided here, before the
    // entry exists: a bubble aims at its trigger, and only macOS draws that aim,
    // so the side has to be known while the plate is being built rather than
    // after the bubble has been measured.
    final below = anchor.top < widget.visual.estimatedHeight + widget.visual.gap * 2;
    _pinned = pinned;
    _open.value = true;
    final entry = OverlayEntry(
      builder: (_) => _TipOverlay(
        theme: widget.theme,
        visual: widget.visual,
        message: widget.message,
        anchor: anchor,
        below: below,
        pinned: pinned,
        open: _open,
        onGone: _retire,
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  void _hide() {
    _timer?.cancel();
    _pinned = false;
    if (_entry == null || _closing) {
      return;
    }
    _closing = true;
    _open.value = false;
  }

  /// Drops the entry, once the exit has run (or the moment a re-show decides it
  /// has had its say).
  void _retire() {
    _closing = false;
    _entry?.remove();
    _entry = null;
  }

  /// The tap that lifts a pinned bubble. A long press is how touch answers a
  /// hover, so its answer lives until the next tap anywhere.
  void _tapWhilePinned() {
    if (_pinned && _shown) {
      _hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _showAfterWait(),
      onExit: (_) => _hide(),
      child: GestureDetector(
        // Translucent, not opaque: a tooltip around a live control must leave the
        // control answering, and a bare glyph gives a long press nothing of its
        // own to hit.
        behavior: HitTestBehavior.translucent,
        onLongPress: () => _show(pinned: true),
        onTap: _tapWhilePinned,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (focused) {
            if (focused) {
              _showAfterWait();
            } else {
              _hide();
            }
          },
          // The trigger keeps its own semantics; the bubble adds its word to it
          // the way Flutter's `Tooltip` does, so a reader hears the help without
          // having to open the bubble.
          child: Semantics(
            key: const Key('PureTooltip.trigger'),
            tooltip: widget.message,
            child: KeyedSubtree(key: _anchorKey, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// The bubble on the overlay: the fade-and-scale entrance, the placement that
/// centres it on its trigger and flips it below when the top is short, the tap
/// layer that lifts a pinned bubble, and the semantics that name it.
class _TipOverlay extends StatefulWidget {
  const new({
    required this.theme,
    required this.visual,
    required this.message,
    required this.anchor,
    required this.below,
    required this.pinned,
    required this.open,
    required this.onGone,
  });

  final PureTheme theme;
  final _TipVisual visual;
  final String message;
  final Rect anchor;
  final bool below;
  final bool pinned;
  final ValueNotifier<bool> open;
  final VoidCallback onGone;

  @override
  State<_TipOverlay> createState() => _TipOverlayState();
}

class _TipOverlayState extends State<_TipOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.theme.duration);
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: widget.visual.curve);
  late final Animation<double> _scale = Tween<double>(
    begin: widget.visual.beginScale,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: widget.visual.curve));

  @override
  void initState() {
    super.initState();
    widget.open.addListener(_onOpenChanged);
    if (widget.open.value) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    widget.open.removeListener(_onOpenChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onOpenChanged() {
    if (widget.open.value) {
      _controller.forward();
      return;
    }
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onGone();
      }
    }).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final visual = widget.visual;
    final margin = theme.token.scale.sizes.sm;
    final tail = visual.tail ? visual.tailColor(theme) : null;

    final plate = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: visual.maxWidth),
      child: IgnorePointer(
        child: visual.bubble(
          theme,
          Padding(
            padding: visual.padding,
            child: Text(
              widget.message,
              textAlign: TextAlign.start,
              style: theme.text.bodySmall.copyWith(color: visual.content(theme)),
            ),
          ),
        ),
      ),
    );

    // macOS's point is a flat triangle on the side its trigger is, painted in
    // the plate's own fill so plate and point read as one shape. It is part of
    // the bubble's layout rather than an overflow, so the placement measures it
    // and the gap it leaves against the trigger stays the language's own.
    final bubble = tail == null
        ? plate
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.below) ...[_tail(tail), plate],
              if (!widget.below) ...[plate, _tail(tail)],
            ],
          );

    return Stack(
      children: [
        if (widget.pinned)
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => widget.open.value = false),
          ),
        Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: _TipPositionDelegate(anchor: widget.anchor, below: widget.below, margin: margin, gap: visual.gap),
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                alignment: widget.below ? Alignment.topCenter : Alignment.bottomCenter,
                child: Semantics(
                  // The branch a language draws is its identity in tests and
                  // diagnostics. The bubble itself is not a semantics role
                  // Flutter has settled on yet (`SemanticsRole.tooltip` is still
                  // a TODO upstream), so it reads as the labelled group it is.
                  key: ValueKey('PureTooltip.${theme.config.language.name}'),
                  container: true,
                  label: widget.message,
                  child: bubble,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The point, aimed up or down at the trigger.
  Widget _tail(Color color) => ExcludeSemantics(
    child: CustomPaint(
      size: const Size(_TipTail.width, _TipTail.height),
      painter: _TipTailPainter(color: color, pointsDown: !widget.below),
    ),
  );
}

/// The macOS help tag's point: 12 wide, 6 tall.
abstract final class _TipTail {
  /// The width of the base.
  static const double width = 12;

  /// How far the point reaches towards the trigger.
  static const double height = 6;
}

/// The triangle itself, in the plate's own fill.
class _TipTailPainter extends CustomPainter {
  new({required this.color, required this.pointsDown});

  final Color color;
  final bool pointsDown;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(pointsDown ? size.width : 0, 0)
      ..lineTo(size.width / 2, pointsDown ? size.height : 0)
      ..lineTo(pointsDown ? 0 : size.width, pointsDown ? 0 : size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TipTailPainter oldDelegate) => oldDelegate.color != color || oldDelegate.pointsDown != pointsDown;
}

/// Places the bubble centred on its trigger, above it as macOS, Windows and the
/// desktop languages do, flipping below when the top of the screen is short, and
/// clamping the whole bubble inside the viewport.
class _TipPositionDelegate extends SingleChildLayoutDelegate {
  new({required this.anchor, required this.below, required this.margin, required this.gap});

  final Rect anchor;
  final bool below;
  final double margin;
  final double gap;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final above = anchor.top - gap - childSize.height;
    final top = below
        ? (anchor.bottom + gap).clamp(margin, _max(margin, size.height - margin - childSize.height))
        : (above > margin ? above : anchor.bottom + gap).clamp(
            margin,
            _max(margin, size.height - margin - childSize.height),
          );
    final centre = anchor.center.dx - childSize.width / 2;
    return Offset(centre.clamp(margin, _max(margin, size.width - margin - childSize.width)), top);
  }

  static double _max(double a, double b) => a > b ? a : b;

  @override
  bool shouldRelayout(_TipPositionDelegate oldDelegate) =>
      oldDelegate.anchor != anchor ||
      oldDelegate.below != below ||
      oldDelegate.margin != margin ||
      oldDelegate.gap != gap;
}
