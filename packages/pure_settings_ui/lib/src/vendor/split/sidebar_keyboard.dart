import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Moves the keyboard focus to the sidebar row above or below. Internal.
class SidebarMoveFocusIntent extends Intent {
  const SidebarMoveFocusIntent(this.direction);

  final TraversalDirection direction;
}

/// Selects the focused sidebar row, if it opens a page. Sidebar rows
/// handle it; [SettingsSidebarKeyboard] sends it after an arrow key when
/// the selection follows the focus. Internal.
class SidebarSelectIntent extends Intent {
  const SidebarSelectIntent();
}

/// Keyboard navigation in a sidebar of the macOS, Windows or GNOME style.
/// Internal.
///
/// Tab and Shift+Tab move through the rows (each row takes the focus), and
/// Enter or Space selects the focused one, as everywhere. Up and down move
/// the focus to the row above or below, and stop at the first and last
/// rows, like `NSTableView`, `NavigationView` and `GtkListBox`; on the web,
/// where the arrow keys scroll by default, too. With
/// [selectionFollowsFocus] (the macOS sidebar, an `NSTableView`) they also
/// select that row, like the arrow keys in System Settings.
class SettingsSidebarKeyboard extends StatefulWidget {
  const SettingsSidebarKeyboard({
    super.key,
    this.enabled = true,
    this.selectionFollowsFocus = false,
    required this.child,
  });

  /// False keeps the widget (so the tree below keeps its shape) without
  /// the arrow keys.
  final bool enabled;
  final bool selectionFollowsFocus;
  final Widget child;

  @override
  State<SettingsSidebarKeyboard> createState() =>
      _SettingsSidebarKeyboardState();
}

class _SettingsSidebarKeyboardState extends State<SettingsSidebarKeyboard> {
  static const Map<ShortcutActivator, Intent> _shortcuts =
      <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowUp): SidebarMoveFocusIntent(
          TraversalDirection.up,
        ),
        SingleActivator(LogicalKeyboardKey.arrowDown): SidebarMoveFocusIntent(
          TraversalDirection.down,
        ),
      };

  /// Around the sidebar: the arrow keys only move between its rows.
  final FocusNode _sidebar = FocusNode(
    debugLabel: 'Sidebar',
    skipTraversal: true,
    canRequestFocus: false,
  );

  late final _MoveFocusAction _moveFocus = _MoveFocusAction(this);

  @override
  void dispose() {
    _sidebar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: widget.enabled
          ? _shortcuts
          : const <ShortcutActivator, Intent>{},
      child: Actions(
        actions: <Type, Action<Intent>>{SidebarMoveFocusIntent: _moveFocus},
        child: Focus(
          focusNode: _sidebar,
          skipTraversal: true,
          canRequestFocus: false,
          child: FocusTraversalGroup(child: widget.child),
        ),
      ),
    );
  }
}

class _MoveFocusAction extends Action<SidebarMoveFocusIntent> {
  _MoveFocusAction(this.sidebar);

  final _SettingsSidebarKeyboardState sidebar;

  @override
  Object? invoke(SidebarMoveFocusIntent intent) {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || focus.context == null) return null;
    final down = intent.direction == TraversalDirection.down;
    final target = _nearest(focus, down: down);
    // Nothing above the first row or below the last: stay there.
    if (target == null) return null;
    FocusTraversalPolicy.defaultTraversalRequestFocusCallback(
      target,
      alignmentPolicy: down
          ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
          : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
    if (sidebar.widget.selectionFollowsFocus) {
      // The focus moves in a microtask; select once it has.
      scheduleMicrotask(() {
        final context = FocusManager.instance.primaryFocus?.context;
        if (context != null && context.mounted) {
          Actions.maybeInvoke(context, const SidebarSelectIntent());
        }
      });
    }
    return null;
  }

  /// The sidebar's focusable node closest above or below [focus],
  /// preferring the ones in the same column.
  FocusNode? _nearest(FocusNode focus, {required bool down}) {
    final from = focus.rect;
    FocusNode? best;
    var bestInColumn = false;
    var bestDistance = double.infinity;
    for (final node in sidebar._sidebar.traversalDescendants) {
      final context = node.context;
      if (node == focus ||
          context == null ||
          !context.mounted ||
          !node.canRequestFocus ||
          context.findRenderObject()?.attached != true) {
        continue;
      }
      final rect = node.rect;
      final beyond = down
          ? rect.center.dy > from.center.dy + 0.5
          : rect.center.dy < from.center.dy - 0.5;
      if (!beyond) continue;
      final inColumn = rect.left < from.right && rect.right > from.left;
      final distance = (rect.center.dy - from.center.dy).abs();
      if (best == null ||
          (inColumn && !bestInColumn) ||
          (inColumn == bestInColumn && distance < bestDistance)) {
        best = node;
        bestInColumn = inColumn;
        bestDistance = distance;
      }
    }
    return best;
  }
}
