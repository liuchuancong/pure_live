import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_cupertino/src/theme/cupertino_theme_builder.dart';

/// Installs the mapped Cupertino UI theme around [child] via [cu.CupertinoTheme]
/// (§8.2). Data comes from [CupertinoThemeBuilder].
class CupertinoThemeScope extends StatelessWidget {
  /// A Cupertino UI theme scope for [token] around [child].
  const new({required this.token, required this.child, super.key});

  /// The resolved design token to derive the theme from.
  final DesignToken token;

  /// The subtree the theme applies to.
  final Widget child;

  @override
  Widget build(BuildContext context) => cu.CupertinoTheme(data: CupertinoThemeBuilder.build(token), child: child);
}
