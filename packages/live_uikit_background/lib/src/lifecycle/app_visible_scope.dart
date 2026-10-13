/// Optional lifecycle helper for callers that want to pause animated
/// backgrounds when the app is not visible.
///
/// The background rendering pipeline does **not** read this scope on
/// its own; `LiveBackground.paused` is a caller-supplied signal. Use
/// [AppVisibilityObserver] if you want a subtree to receive a
/// `WidgetsBindingObserver`-driven value without writing your own
/// state, then wire the result into `LiveBackground.paused`.
///
/// [AppVisibleScope.isVisibleOf] returns `true` when no observer wraps
/// the tree, so unobserved subtrees keep running: the default is
/// "background is active", which is the safer behaviour for a page
/// that has not opted into observation yet.
library;

import 'package:flutter/widgets.dart';

/// Inherited flag telling descendants whether the app is currently in a
/// state where animated backgrounds should keep running.
///
/// Purely informational — the rendering pipeline does not consult it.
/// Read it from a parent widget and pass the value into
/// `LiveBackground.paused`.
class AppVisibleScope extends InheritedWidget {
  /// Publishes [visible] to descendants until the next rebuild.
  const new({required this.visible, required super.child, super.key});

  /// Whether the app is in `resumed` state and the subtree is on-screen.
  final bool visible;

  /// Reads the nearest [AppVisibleScope]; returns `true` when the
  /// subtree is not wrapped by an observer so the caller's default is
  /// "keep running".
  static bool isVisibleOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppVisibleScope>();
    return scope?.visible ?? true;
  }

  @override
  bool updateShouldNotify(AppVisibleScope oldWidget) => visible != oldWidget.visible;
}

/// Wraps a subtree and republishes the app lifecycle as an
/// [AppVisibleScope].
///
/// The observer intentionally does not attempt to detect off-screen
/// routes — that requires route-aware hooks owned by the navigation
/// layer. Route visibility can be plugged in later by pushing
/// `false` through a controller without changing descendants.
class AppVisibilityObserver extends StatefulWidget {
  /// Observes app lifecycle for [child].
  const new({required this.child, super.key});

  /// The subtree that receives the visibility signal.
  final Widget child;

  @override
  State<AppVisibilityObserver> createState() => _AppVisibilityObserverState();
}

class _AppVisibilityObserverState extends State<AppVisibilityObserver> with WidgetsBindingObserver {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _visible = state != AppLifecycleState.hidden && state != AppLifecycleState.paused;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final next = state != AppLifecycleState.hidden && state != AppLifecycleState.paused;
    if (next != _visible) {
      setState(() => _visible = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppVisibleScope(visible: _visible, child: widget.child);
  }
}
