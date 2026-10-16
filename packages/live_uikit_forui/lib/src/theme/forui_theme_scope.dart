import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_forui/src/theme/forui_theme_builder.dart';

/// Installs the mapped forui theme around [child] via [forui.FTheme] (§8.2).
///
/// Every forui widget resolves its appearance from this scope (`context.theme`), so an
/// adapter that rendered a control without it would silently paint the library's stock
/// neutral palette instead of the app's tokens.
class ForuiThemeScope extends StatelessWidget {
  /// A forui theme scope for [token] around [child].
  const new({required this.token, required this.child, super.key});

  /// The resolved design token to derive the forui theme from.
  final DesignToken token;

  /// The subtree the theme applies to.
  final Widget child;

  @override
  Widget build(BuildContext context) => forui.FTheme(data: ForuiThemeBuilder.build(token), child: child);
}
