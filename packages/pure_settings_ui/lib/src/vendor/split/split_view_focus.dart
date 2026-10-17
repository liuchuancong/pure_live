part of 'settings_split_view.dart';

/// The keyboard focus in a split view's panes: where it goes when the
/// layout changes, and how it reaches the list pane.
extension _PaneFocus on _SettingsSplitViewState {
  /// Whether [node] is the focus node of one of the view's navigators,
  /// which holds the focus until something in a pane takes it.
  bool _isNavigatorFocus(FocusNode node) =>
      node == _detailKey.currentState?.focusNode ||
      node == _stackKey.currentState?.focusNode;

  /// The layout is switching between one and two panes, which rebuilds the
  /// navigators around the panes: puts the keyboard focus back where it
  /// was once the new layout is built. A row the new layout draws as a card
  /// (macOS, Windows) gives it to that card; a page one pane doesn't show
  /// gives it to its tile.
  void _keepFocusAcrossLayouts() {
    final node = FocusManager.instance.primaryFocus;
    if (node == null) return;
    bool isIn(FocusNode? pane) =>
        pane != null && (node == pane || node.ancestors.contains(pane));
    final inList = isIn(_listFocusNode);
    final inDetail = !inList && isIn(_detailKey.currentState?.focusNode);
    if (!inList && !inDetail) return;
    // The detail navigator's own node: nothing in the page had the focus.
    final navigatorOnly = _isNavigatorFocus(node);
    final nodeContext = node.context;
    final tile = nodeContext != null && nodeContext.mounted
        ? nodeContext.findAncestorWidgetOfExactType<SettingsTile>()
        : null;
    final pageId = _shownId;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = node.context;
      final alive = context != null && context.mounted && node.canRequestFocus;
      final FocusNode? target;
      if (alive && !navigatorOnly && (inDetail || _listShown)) {
        target = node;
      } else if (!_listShown) {
        // One pane shows a page over the list: its route has the focus.
        return;
      } else if (inList && tile != null) {
        target =
            _listNodeWhere((candidate) => identical(candidate, tile)) ??
            _listNodeWhere(
              (candidate) =>
                  tile.destination != null &&
                  candidate.destination?.id == tile.destination!.id,
            );
      } else {
        // The page is gone (one pane shows the list), or had no focus.
        target = _listNodeWhere(
          (candidate) => pageId != null && candidate.destination?.id == pageId,
        );
      }
      if (target == null) {
        _focusListPane(first: true);
      } else if (!target.hasPrimaryFocus) {
        FocusTraversalPolicy.defaultTraversalRequestFocusCallback(
          target,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    }, debugLabel: 'SettingsSplitView.keepFocus');
  }

  /// The first focusable node in the list pane inside a tile that passes
  /// [test].
  FocusNode? _listNodeWhere(bool Function(SettingsTile tile) test) {
    for (final node in _listFocusNode.traversalDescendants) {
      final context = node.context;
      if (context == null || !context.mounted || !node.canRequestFocus) {
        continue;
      }
      final tile = context.findAncestorWidgetOfExactType<SettingsTile>();
      if (tile != null && test(tile)) return node;
    }
    return null;
  }

  /// Gives the keyboard focus to the first (or last) control of the list
  /// pane. Returns whether there was one.
  bool _focusListPane({required bool first}) {
    final nodes =
        _listFocusNode.traversalDescendants
            .where((node) => node.context != null && node.canRequestFocus)
            .toList()
          ..sort((a, b) {
            final byTop = a.rect.top.compareTo(b.rect.top);
            return byTop != 0 ? byTop : a.rect.left.compareTo(b.rect.left);
          });
    if (nodes.isEmpty) return false;
    (first ? nodes.first : nodes.last).requestFocus();
    return true;
  }
}

/// Tab and Shift+Tab in a split view. A page without any control leaves
/// its route's focus scope with nothing to move to, which would keep the
/// focus there: then the focus goes on to the list pane.
class _PaneFocusAction<T extends Intent> extends Action<T> {
  _PaneFocusAction(this.view, this.forward);

  final _SettingsSplitViewState view;
  final bool forward;

  @override
  Object? invoke(T intent) {
    final node = FocusManager.instance.primaryFocus;
    if (node == null) return null;
    // Nothing is focused yet: the detail navigator took the focus when it
    // was built (navigators autofocus). Start in the list pane, like the
    // platforms' settings apps, not after the navigator in the page.
    // In one pane, a page shown over the list hides it: stay in the page.
    final listShown = view._listShown;
    if (forward &&
        listShown &&
        view._isNavigatorFocus(node) &&
        view._focusListPane(first: true)) {
      return null;
    }
    final moved = forward ? node.nextFocus() : node.previousFocus();
    if (!moved && listShown) view._focusListPane(first: forward);
    return null;
  }
}
