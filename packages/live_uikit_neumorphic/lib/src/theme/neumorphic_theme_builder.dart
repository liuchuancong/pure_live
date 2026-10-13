import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/styling.dart';

/// Maps the core's resolved `DesignToken` into `NeuThemeData` (§8.1): the base
/// surface and accent come straight from the token, so a soft-embossed theme
/// still tracks the app's brightness and accent.
abstract final class NeumorphicThemeBuilder {
  /// Builds the Neumorphic theme data for [token].
  static neu.NeuThemeData build(DesignToken token) =>
      neu.NeuThemeData(baseColor: token.color.bgLayout, accentColor: token.color.primary);
}
