import 'package:flutter/widgets.dart';
import 'package:pure_uikit/src/icons/api/pure_icon_style.dart';

/// Theme-wide icon defaults a subtree can impose (a dense toolbar, a TV
/// screen drawing everything larger).
class PureIconThemeData {
  /// Builds the data; null fields inherit further up or from the tokens.
  const new({this.size, this.role});

  /// The subtree's default draw size.
  final double? size;

  /// The subtree's default palette role.
  final PureIconColorRole? role;
}

/// Scopes [PureIconThemeData] to a widget subtree.
class PureIconTheme extends InheritedWidget {
  /// Wraps [child] with the icon defaults.
  const new({required this.data, required super.child, super.key});

  /// The defaults this scope carries.
  final PureIconThemeData data;

  /// The nearest scope's data, or null at the root.
  static PureIconThemeData? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PureIconTheme>()?.data;

  @override
  bool updateShouldNotify(PureIconTheme oldWidget) => data != oldWidget.data;
}
