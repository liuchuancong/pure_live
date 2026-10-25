import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/widgets.dart';

/// Scrolls the nearest scrollable so the focused control stays in view.
///
/// Flutter moves keyboard/D-pad focus by geometry but never scrolls a
/// focus target into view by itself. A remote can therefore focus a row
/// below the viewport with no way to see where it is. Wrapped once around
/// the app, this listens to the primary focus and reveals each new stop in
/// the scrollable that holds it — sidebars, settings columns, platform
/// rows, dialogs — without touching the layouts themselves.
///
/// It only moves when the target is actually out of view: a stop already
/// on screen is left where it is.
final class FocusAutoScroll extends StatefulWidget {
  /// Reveals focus that moves inside [child].
  const FocusAutoScroll({required this.child, super.key});

  /// The app (or a page) whose focus changes it follows.
  final Widget child;

  @override
  State<FocusAutoScroll> createState() => _FocusAutoScrollState();
}

final class _FocusAutoScrollState extends State<FocusAutoScroll> {
  /// How close to the viewport's edge a stop may sit before it is scrolled.
  static const double _margin = 24;

  FocusNode? _last;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) {
      _last = null;
      return;
    }
    if (identical(focus, _last)) return;
    _last = focus;
    final context = focus.context;
    if (context == null) return;
    // Focus in an overlay route is still in the app; focus in a detached
    // tree is not. Only this subtree's stops are ours to reveal.
    if (context.findAncestorStateOfType<_FocusAutoScrollState>() != this) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || FocusManager.instance.primaryFocus != focus) return;
      final context = focus.context;
      if (context != null) _reveal(context);
    });
  }

  /// Jumps [context]'s nearest scrollable just far enough to show it.
  void _reveal(BuildContext context) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;
    final position = scrollable.position;
    if (!position.hasContentDimensions || !position.hasViewportDimension) return;
    final object = context.findRenderObject();
    if (object is! RenderBox || !object.attached || !object.hasSize) return;
    final viewport = RenderAbstractViewport.of(object);
    final start = viewport.getOffsetToReveal(object, 0).offset;
    final extent = position.axis == Axis.vertical ? object.size.height : object.size.width;
    final end = start + extent;
    var target = position.pixels;
    if (start < target + _margin) {
      target = start - _margin;
    } else if (end > target + position.viewportDimension - _margin) {
      target = end + _margin - position.viewportDimension;
    }
    target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() > 0.5) position.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
