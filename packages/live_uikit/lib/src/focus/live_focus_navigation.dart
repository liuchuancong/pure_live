import 'package:flutter/widgets.dart';

/// A direction the d-pad can move focus in.
enum LiveFocusDirection {
  /// Towards the top of the screen.
  up,

  /// Towards the bottom.
  down,

  /// Towards the start edge.
  left,

  /// Towards the end edge.
  right;

  /// The Flutter traversal direction this maps to.
  TraversalDirection get traversal => switch (this) {
    LiveFocusDirection.up => TraversalDirection.up,
    LiveFocusDirection.down => TraversalDirection.down,
    LiveFocusDirection.left => TraversalDirection.left,
    LiveFocusDirection.right => TraversalDirection.right,
  };
}

/// Moves focus the way a remote control expects it to move.
///
/// Flutter's geometry-based traversal already does the hard part (it picks
/// the *next* focusable in the direction, not the next in the tree), so this
/// is a thin layer over `FocusNode.focusInDirection` that adds the two things
/// TV needs and desktop does not:
///
/// * **Wrapping.** On a horizontal row of rooms there is nothing to the right
///   of the last card, and a remote whose right key does nothing feels
///   broken; with `wrap` the focus returns to the row's first item instead of
///   leaving the list. Pages decide: a grid wraps, a form does not.
/// * **A result.** `false` from `move` means "nothing moved", which is what
///   lets a page treat the press as something else (open a menu on a
///   hold-to-the-right, or hand the key to the parent).
abstract final class LiveFocusNavigation {
  /// Moves focus in [direction] from [context]'s node.
  ///
  /// Returns whether anything took focus. With [wrap], a direction with no
  /// focusable under it falls back to the next focusable in reading order,
  /// which is the "go back to the start of the row" behaviour.
  static bool move(BuildContext context, LiveFocusDirection direction, {bool wrap = false}) {
    final node = Focus.of(context);
    if (node.focusInDirection(direction.traversal)) {
      return true;
    }
    if (!wrap) {
      return false;
    }
    return switch (direction) {
      LiveFocusDirection.down || LiveFocusDirection.right => node.nextFocus(),
      LiveFocusDirection.up || LiveFocusDirection.left => node.previousFocus(),
    };
  }

  /// Whether [context]'s node has focus.
  static bool isFocused(BuildContext context) => Focus.of(context).hasFocus;

  /// Gives focus to [node] when it can take it.
  ///
  /// Returns whether the request was made — the request itself may still be
  /// dropped by the focus system (a node that is not attached yet), which is
  /// why callers that must win a focus race re-assert across frames; the
  /// route-aware restorer does exactly that.
  static bool request(FocusNode? node) {
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
