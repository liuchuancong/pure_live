import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_material/src/theme/material_theme_builder.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Installs the mapped Material UI theme around [child] via [mu.Theme] (§8.2) —
/// a theme scope, not a nested `MaterialApp`. Data from [MaterialThemeBuilder].
///
/// The transparent [mu.Material] under the theme is not a shell either: it is the
/// paint surface every fork ink widget looks for by type. A host `MaterialApp`
/// only supplies the SDK's `Material`, so without it a fork `TextField`, `Switch`
/// or `Card` throws "No Material widget found" — and a page must not have to
/// remember to add one.
class MaterialThemeScope extends StatelessWidget {
  /// A Material UI theme scope for [token] around [child].
  const new({required this.token, required this.child, super.key});

  /// The resolved design token to derive the theme from.
  final DesignToken token;

  /// The subtree the theme applies to.
  final Widget child;

  @override
  Widget build(BuildContext context) => mu.Theme(
    data: MaterialThemeBuilder.build(token),
    child: mu.Material(type: mu.MaterialType.transparency, child: child),
  );
}
