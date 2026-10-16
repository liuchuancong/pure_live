import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_fluent/src/theme/fluent_theme_builder.dart';

/// Installs the mapped Fluent theme around [child] via [fluent.FluentTheme]
/// (§8.2 theme scope) — deliberately *not* a nested `FluentApp`, which would
/// bring competing navigation and localization. The data comes from
/// [FluentThemeBuilder], rebuilt whenever the resolved [token] changes (§8.3).
class FluentThemeScope extends StatelessWidget {
  /// A Fluent theme scope for [token] around [child].
  const new({required this.token, required this.child, super.key});

  /// The resolved design token to derive the Fluent theme from.
  final DesignToken token;

  /// The subtree the theme applies to.
  final Widget child;

  @override
  Widget build(BuildContext context) => fluent.FluentTheme(data: FluentThemeBuilder.build(token), child: child);
}
