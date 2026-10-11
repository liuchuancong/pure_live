import 'package:flutter/widgets.dart';

/// Remembers the focus inside a page, so leaving and returning to it does
/// not lose the user's place.
///
/// The pattern this exists for: a TV user navigates to a row twelve cards
/// deep, opens a room, comes back, and expects the highlight on the card
/// they left — not on the page's first control. Flutter's own focus scope
/// restores only within one route, so this widget keeps the last focused
/// node of its subtree and can put focus back on demand.
///
/// Recording is automatic while [remember] is true; `restore` is called by
/// whichever layer owns the "you are back" moment (the page shell, or
/// `LiveFocusRestorer` when the trip was a route push).
class LiveFocusScope extends StatefulWidget {
  /// A focus scope around [child].
  const new({required this.child, this.remember = true, this.initialFocusNode, super.key});

  /// The subtree whose focus is remembered.
  final Widget child;

  /// Whether the scope records the focus of its subtree. False is for
  /// scopes that only need to *hand back* focus, such as a page that must
  /// not steal it while a dialog is up.
  final bool remember;

  /// The node to focus when [LiveFocusScopeController.restore] runs and
  /// nothing was ever remembered.
  final FocusNode? initialFocusNode;

  /// The controller of the nearest scope above [context], or null.
  static LiveFocusScopeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_LiveFocusScopeMarker>()?.controller;

  /// The controller of the nearest scope above [context].
  ///
  /// Throws when there is none — a page that asks for a scope it did not
  /// install is a wiring bug, and silently doing nothing there would look
  /// like a broken remote.
  static LiveFocusScopeController of(BuildContext context) {
    final controller = maybeOf(context);
    if (controller == null) {
      throw FlutterError.fromParts([
        ErrorSummary('No LiveFocusScope found above this widget.'),
        ErrorDescription(
          'Wrap the page (or the subtree that owns the focus) in a LiveFocusScope before using its controller.',
        ),
      ]);
    }
    return controller;
  }

  @override
  State<LiveFocusScope> createState() => _LiveFocusScopeState();
}

class _LiveFocusScopeState extends State<LiveFocusScope> {
  late final FocusScopeNode _scope = FocusScopeNode(debugLabel: 'live-uikit page scope');
  final LiveFocusScopeController _controller = LiveFocusScopeController();
  FocusManager? _manager;
  FocusNode? _last;

  @override
  void initState() {
    super.initState();
    _controller._state = this;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _manager?.removeListener(_onFocusChange);
    _manager = FocusManager.instance;
    _manager?.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _manager?.removeListener(_onFocusChange);
    _controller._state = null;
    _scope.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!widget.remember || !mounted) {
      return;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || primary is FocusScopeNode) {
      return;
    }
    if (_isInside(primary)) {
      _last = primary;
    }
  }

  bool _isInside(FocusNode node) {
    if (identical(node, _scope)) {
      return true;
    }
    for (final ancestor in node.ancestors) {
      if (identical(ancestor, _scope)) {
        return true;
      }
    }
    return false;
  }

  /// The node this scope would focus on [LiveFocusScopeController.restore].
  FocusNode? get _target => _last ?? widget.initialFocusNode;

  @override
  Widget build(BuildContext context) => _LiveFocusScopeMarker(
    controller: _controller,
    child: FocusScope(node: _scope, child: widget.child),
  );
}

/// The handle a page uses to read and restore its remembered focus.
class LiveFocusScopeController {
  /// The scope's state while it is mounted; private to this library.
  _LiveFocusScopeState? _state;

  /// The node the scope would focus next, or null when nothing was ever
  /// remembered.
  FocusNode? get rememberedNode => _state?._target;

  /// Whether [node] (or the primary focus) sits inside this scope.
  bool contains(FocusNode? node) {
    final state = _state;
    if (state == null || node == null) {
      return false;
    }
    return state._isInside(node);
  }

  /// Puts focus back on the remembered node.
  ///
  /// Returns false when there is nothing to restore or the node cannot take
  /// focus any more (its row was removed by a refresh, its page was
  /// rebuilt).
  bool restore() {
    final node = _state?._target;
    if (node == null || !node.canRequestFocus) {
      return false;
    }
    final context = node.context;
    if (context == null || !context.mounted) {
      return false;
    }
    node.requestFocus();
    return true;
  }
}

/// The inherited marker that hands the controller down the tree.
class _LiveFocusScopeMarker extends InheritedWidget {
  const new({required this.controller, required super.child});

  final LiveFocusScopeController controller;

  @override
  bool updateShouldNotify(_LiveFocusScopeMarker oldWidget) => !identical(controller, oldWidget.controller);
}
