import 'package:flutter/widgets.dart';

/// Route events for the focus restorer.
///
/// A `RouteObserver` only calls its subscribers when the navigator knows
/// about it, so the application registers this one in its `MaterialApp` /
/// `CupertinoApp` / router `observers` list. Without that registration the
/// restorer silently degrades to focus-death recovery only — which is why it
/// is a named object rather than a restorer-private one: there is exactly
/// one to register, and this is it.
final RouteObserver<ModalRoute<void>> liveRouteObserver = RouteObserver<ModalRoute<void>>();

/// Hands focus back to the item the user acted on when a route above this
/// subtree pops away.
///
/// The problem, straight from the TV implementation this is adapted from: a
/// pushed route (a settings sub-page, a dialog) takes focus with it; when it
/// pops, the focus system's own fallback picks the first focusable of the
/// whole tree — usually the returned-to page's back button — or the covered
/// page's node dies with the outgoing route and leaves the remote looking
/// dead. This widget remembers the node that held the keyboard when the push
/// happened and re-asserts it across a few frames, which is what makes the
/// "open, step back, continue where you were" loop work.
///
/// Three details are load-bearing, each learned the hard way in the TV
/// project and kept here:
///
/// * The restore is re-asserted for a bounded number of frames, because the
///   focus system's fallback also runs post-frame and would otherwise win
///   the race.
/// * Re-assertion uses post-frame callbacks, never microtasks: a microtask
///   can run between a frame's build and layout phases, and requesting focus
///   there sets state inside an open build scope.
/// * Focus *death* (the outgoing route disposes its nodes a few hundred
///   milliseconds after the pop) is handled separately, one frame later, so
///   a focus that merely moved — including a momentary bare scope node — is
///   never yanked back.
class LiveFocusRestorer extends StatefulWidget {
  /// A restorer around [child], usually one per page shell.
  const new({required this.child, this.onRestoreTarget, this.maxRestoreAttempts = 3, super.key});

  /// The subtree whose focus is restored.
  final Widget child;

  /// Reports the node the restore aims at, so a page shell can tell "the
  /// user's item is still here" from "nothing holds the keyboard".
  final ValueChanged<FocusNode?>? onRestoreTarget;

  /// How many frames the restore keeps asserting itself.
  final int maxRestoreAttempts;

  @override
  State<LiveFocusRestorer> createState() => _LiveFocusRestorerState();
}

class _LiveFocusRestorerState extends State<LiveFocusRestorer> with RouteAware {
  FocusNode? _focusWhenCovered;
  FocusNode? _lastInsideRoute;
  bool _restoreScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      liveRouteObserver.subscribe(this, route);
    }
    FocusManager.instance.removeListener(_onFocusChange);
    FocusManager.instance.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    liveRouteObserver.unsubscribe(this);
    FocusManager.instance.removeListener(_onFocusChange);
    super.dispose();
  }

  void _remember(FocusNode node) {
    _lastInsideRoute = node;
    widget.onRestoreTarget?.call(node);
  }

  @override
  void didPushNext() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary is! FocusScopeNode) {
      _focusWhenCovered = primary;
      _remember(primary);
      return;
    }
    // The keyboard was already nowhere real: the route push updates the
    // stack and the rebuild can drop focus before this callback runs, so the
    // last in-route node is the best return target — the node itself usually
    // survives the push and the pop can still land on it.
    _focusWhenCovered = _lastInsideRoute;
  }

  @override
  void didPopNext() {
    final node = _focusWhenCovered ?? _lastInsideRoute;
    _focusWhenCovered = null;
    if (node != null) {
      _restore(node);
    }
  }

  void _onFocusChange() {
    if (!mounted) {
      return;
    }
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) {
      return;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && _isInsideRoute(primary, route)) {
      if (primary is! FocusScopeNode) {
        _remember(primary);
      }
      return;
    }
    if (_restoreScheduled) {
      return;
    }
    _restoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScheduled = false;
      if (!mounted) {
        return;
      }
      final settled = FocusManager.instance.primaryFocus;
      // Something real holds the keyboard: focus moved, it did not die.
      if (settled != null && settled is! FocusScopeNode) {
        return;
      }
      final node = _lastInsideRoute;
      if (node != null) {
        _restore(node);
      }
    });
  }

  bool _isInsideRoute(FocusNode node, ModalRoute<dynamic> route) {
    final context = node.context;
    if (context == null || !context.mounted) {
      return false;
    }
    return identical(ModalRoute.of(context), route);
  }

  void _restore(FocusNode node) {
    var attempts = 0;
    void attempt() {
      if (!mounted || attempts >= widget.maxRestoreAttempts) {
        return;
      }
      attempts += 1;
      if (identical(FocusManager.instance.primaryFocus, node)) {
        return;
      }
      final context = node.context;
      final usable = node.parent != null && context != null && context.mounted && node.canRequestFocus;
      if (!usable) {
        return;
      }
      node.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
