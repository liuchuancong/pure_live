import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_wind/src/theme/wind_theme_builder.dart';

/// Installs the mapped Wind theme around [child] via [wind.WindTheme] (§8.2).
class WindThemeScope extends StatelessWidget {
  /// A Wind theme scope for [token] around [child].
  const new({required this.token, required this.child, super.key});

  /// The resolved design token to derive the Wind theme from.
  final DesignToken token;

  /// The subtree the theme applies to.
  final Widget child;

  @override
  Widget build(BuildContext context) => wind.WindTheme(data: WindThemeBuilder.build(token), child: child);
}
