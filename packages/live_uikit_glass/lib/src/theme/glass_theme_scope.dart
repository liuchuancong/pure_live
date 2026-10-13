import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_glass/src/theme/glass_theme_builder.dart';

/// Installs the mapped Glass theme around [child] via [glass.GlassTheme] (§8.2).
class GlassThemeScope extends StatelessWidget {
  /// A Glass theme scope for [token] around [child].
  const new({required this.token, required this.child, super.key});

  /// The resolved design token to derive the Glass theme from.
  final DesignToken token;

  /// The subtree the theme applies to.
  final Widget child;

  @override
  Widget build(BuildContext context) => glass.GlassTheme(data: GlassThemeBuilder.build(token), child: child);
}
