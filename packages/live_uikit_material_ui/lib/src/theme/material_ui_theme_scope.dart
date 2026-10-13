import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_material_ui/src/theme/material_ui_theme_builder.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Installs the mapped Material UI theme around [child] via [mu.Theme] (§8.2) —
/// a theme scope, not a nested `MaterialApp`. Data from [MaterialUiThemeBuilder].
class MaterialUiThemeScope extends StatelessWidget {
  /// A Material UI theme scope for [token] around [child].
  const new({required this.token, required this.child, super.key});

  /// The resolved design token to derive the theme from.
  final DesignToken token;

  /// The subtree the theme applies to.
  final Widget child;

  @override
  Widget build(BuildContext context) => mu.Theme(data: MaterialUiThemeBuilder.build(token), child: child);
}
