import 'package:flutter/widgets.dart';

/// A section [title] in [style]: a heading node of its own for screen
/// readers. Internal.
Widget sectionTitle(Widget title, {required TextStyle style}) => Semantics(
  container: true,
  header: true,
  child: DefaultTextStyle(style: style, child: title),
);

/// The [sectionTitle] inside [padding]. Internal.
Widget sectionHeader({
  required Widget title,
  required EdgeInsetsGeometry padding,
  required TextStyle style,
}) => Padding(
  padding: padding,
  child: sectionTitle(title, style: style),
);
