import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_neumorphic/src/theme/neumorphic_theme_builder.dart';

/// Installs the mapped Neumorphic theme around [child] via [neu.NeuTheme]
/// (§8.2). Data comes from [NeumorphicThemeBuilder], rebuilt when [token] changes.
class NeumorphicThemeScope extends StatelessWidget {
  /// A Neumorphic theme scope for [token] around [child].
  const new({required this.token, required this.child, super.key});

  /// The resolved design token to derive the Neumorphic theme from.
  final DesignToken token;

  /// The subtree the theme applies to.
  final Widget child;

  @override
  Widget build(BuildContext context) => neu.NeuTheme(data: NeumorphicThemeBuilder.build(token), child: child);
}
