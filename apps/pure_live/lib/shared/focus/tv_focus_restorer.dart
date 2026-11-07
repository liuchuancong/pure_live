import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/routing/navigation/route_observer.dart' show routeObserverProvider;

/// Restores focus to the item the viewer acted on when a route pushed above
/// this subtree pops away (a settings subpage, a dialog).
///
/// A covered page keeps its widgets laid out, so the dpad root's own fallback
/// restore — which runs during the pop transition and picks the top-left-most
/// node of the whole tree — usually lands on the outgoing page, and when that
/// page disposes the highlight dies with it. Here the focused item at push
/// time is remembered and handed focus back after the pop, which is what a
/// remote expects.
final class TvFocusRestorer extends ConsumerStatefulWidget {
  /// Watches [child]'s route and restores its last item.
  const TvFocusRestorer({required this.child, this.onRestoreTarget, super.key});

  /// The subtree whose focus comes back.
  final Widget child;

  /// Reports the node this subtree's restore aims at — the item the viewer
  /// last acted on while the route was current — or null while there is none.
  ///
  /// The enclosing page shell uses it to tell "the viewer's item is still
  /// here, leave the keyboard alone" from "nothing holds it, claim the
  /// opening node". Reading FocusManager.primaryFocus cannot answer that at
  /// claim time: a focus request is applied in a microtask, so the shell saw
  /// the keyboard as unset and dragged the highlight onto its opening node on
  /// top of the restore that had just been requested.
  final ValueChanged<FocusNode?>? onRestoreTarget;

  @override
  ConsumerState<TvFocusRestorer> createState() => _TvFocusRestorerState();
}

final class _TvFocusRestorerState extends ConsumerState<TvFocusRestorer> with RouteAware {
  /// How many frames the page-local restore keeps asserting itself: enough to
  /// outlast the dpad root's fallback, short enough never to fight the viewer.
  static const int _maxRestoreAttempts = 3;

  RouteObserver<ModalRoute<void>>? _observer;
  FocusNode? _focusWhenCovered;

  /// The last node of this route that held the keyboard while the route was
  /// current, so a focus death after the bounded restore can still be
  /// corrected.
  FocusNode? _lastInsideRoute;

  /// Records where the keyboard is, for the restore and for the page shell.
  void _remember(FocusNode node) {
    _lastInsideRoute = node;
    widget.onRestoreTarget?.call(node);
  }

  @override
  void initState() {
    super.initState();
    // Cached while the state is alive: the observer is gone from `ref` by the
    // time dispose runs.
    _observer = ref.read(routeObserverProvider);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) _observer?.subscribe(this, route);
    // didChangeDependencies can run again on dependency changes; remove first
    // so the listener never accumulates.
    FocusManager.instance.removeListener(_handleFocusChange);
    FocusManager.instance.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _observer?.unsubscribe(this);
    FocusManager.instance.removeListener(_handleFocusChange);
    super.dispose();
  }

  @override
  void didPushNext() {
    // Another route is covering this page. The dpad layer has not moved focus
    // yet, so whatever holds focus now is the item the viewer acted on.
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary is! FocusScopeNode) {
      _focusWhenCovered = primary;
      _remember(primary);
      return;
    }
    // The keyboard was already nowhere real by the time the observer ran: a
    // route pushed through the router updates the route stack first, and the
    // rebuild that follows can drop the keyboard before this callback sees
    // it. The last node of this route that held it usually survives the push
    // (it is only excluded while covered), so the pop can still land back on
    // the item the viewer acted on.
    _focusWhenCovered = _lastInsideRoute;
  }

  @override
  void didPopNext() {
    final node = _focusWhenCovered ?? _lastInsideRoute;
    _focusWhenCovered = null;
    if (node == null) return;
    _restore(node);
  }

  bool _restoreScheduled = false;

  /// Watches for focus deaths while this route is on top.
  ///
  /// A dialog's focus tree disposes only when its exit transition ends — long
  /// after the bounded [_restore] above has finished. When those nodes die,
  /// the dpad layer answers the death itself and lands on the top-most
  /// focusable it finds, which is not the row the viewer acted on.
  /// Re-asserting the last known in-route node covers exactly that window; a
  /// focus that moved to another node of this route is left alone (the viewer
  /// is navigating).
  ///
  /// The decision is deferred by one frame, because a focus that moves into
  /// another route's scope also reports a bare FocusScopeNode for an instant,
  /// and restoring on that instant pulled the highlight back on every
  /// up/down round trip. One frame later the focus is either on something
  /// real (nothing to do) or genuinely gone (restore).
  void _handleFocusChange() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;

    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && _isInsideRoute(primary, route)) {
      if (primary is! FocusScopeNode) _remember(primary);
      return;
    }

    if (_restoreScheduled) return;
    _restoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScheduled = false;
      if (!mounted) return;
      final settled = FocusManager.instance.primaryFocus;
      // Something real has the keyboard: the focus moved, it did not die.
      if (settled != null && settled is! FocusScopeNode) return;
      final node = _lastInsideRoute;
      if (node == null) return;
      _restore(node);
    });
  }

  bool _isInsideRoute(FocusNode node, ModalRoute<dynamic> route) {
    final nodeContext = node.context;
    if (nodeContext == null || !nodeContext.mounted) return false;
    return identical(ModalRoute.of(nodeContext), route);
  }

  /// Hands focus back to [node], and keeps asserting it for a few frames.
  ///
  /// The dpad root runs its own fallback restore in a post-frame callback
  /// plus a microtask, so the two restores race; re-asserting for a couple of
  /// frames makes the page-local restore win without fighting the viewer
  /// beyond that. Post-frame, never a microtask: a microtask can run between
  /// the build and layout phases of one frame, and requesting focus there
  /// sets state in an open layout build scope — the "wrong build scope"
  /// assertion cascade.
  void _restore(FocusNode node) {
    var attempts = 0;
    void attempt() {
      if (!mounted || attempts >= _maxRestoreAttempts) return;
      attempts++;
      if (FocusManager.instance.primaryFocus == node) return; // Settled.
      final usable = node.parent != null && node.context?.mounted == true && node.canRequestFocus;
      if (!usable) return;
      node.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
