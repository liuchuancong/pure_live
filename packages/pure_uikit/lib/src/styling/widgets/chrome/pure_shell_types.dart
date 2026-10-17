import 'package:flutter/widgets.dart' show IconData;

/// One navigation destination a shell renders.
class PureShellDestination {
  /// A destination.
  const new({required this.id, required this.label, required this.icon, this.enabled = true});

  /// The stable identity the caller addresses navigation by. A library that keys
  /// its selection internally still reports the id it was given.
  final String id;

  /// The label.
  final String label;

  /// The glyph. `IconData` is a value, not a widget, so it crosses this boundary
  /// without dragging a widget library's build context with it.
  final IconData icon;

  /// Whether the destination can be taken; a disabled one stays visible so the
  /// layout does not shift when it becomes available.
  final bool enabled;
}

/// Where the shell's navigation sits.
enum PureShellPlacement {
  /// Let the language choose from the environment: a strip under the content on
  /// a phone, a rail beside it once there is room.
  adaptive,

  /// A vertical navigation column beside the content.
  rail,

  /// A horizontal strip under the content.
  bottom,

  /// No navigation: the shell is a frame around a full-screen page.
  none,
}
