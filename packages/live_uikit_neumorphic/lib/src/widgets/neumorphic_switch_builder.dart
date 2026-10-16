import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Neumorphic switch from a [LanguageSwitchSpec] (§9 Switch), fully
/// controlled by the spec.
abstract final class NeumorphicSwitchBuilder {
  /// Builds the switch for [spec].
  static Widget build(BuildContext context, LanguageSwitchSpec spec) =>
      neu.NeuSwitch(value: spec.value, onChanged: spec.enabled ? spec.onChanged : null);
}
