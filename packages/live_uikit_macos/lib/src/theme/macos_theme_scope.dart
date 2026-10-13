import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_macos/src/theme/macos_theme_builder.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Installs the mapped macOS theme around [child] via [macos.MacosTheme]
/// (§8.2). Data comes from [MacosThemeBuilder], rebuilt when [token] changes.
class MacosThemeScope extends StatelessWidget {
  /// A macOS theme scope for [token] around [child].
  const new({required this.token, required this.child, super.key});

  /// The resolved design token to derive the macOS theme from.
  final DesignToken token;

  /// The subtree the theme applies to.
  final Widget child;

  @override
  Widget build(BuildContext context) => macos.MacosTheme(data: MacosThemeBuilder.build(token), child: child);
}
