import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';

/// Builds a native Cupertino UI switch from a [LanguageSwitchSpec] (§9 Switch),
/// fully controlled by the spec.
abstract final class CupertinoSwitchBuilder {
  /// Builds the switch for [spec].
  static Widget build(BuildContext context, LanguageSwitchSpec spec) =>
      cu.CupertinoSwitch(value: spec.value, onChanged: spec.enabled ? spec.onChanged : null);
}
