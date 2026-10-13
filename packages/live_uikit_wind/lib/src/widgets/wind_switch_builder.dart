import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/styling.dart';

/// Builds a native Wind switch from a [LanguageSwitchSpec] (§9 Switch). Fully
/// controlled — value, callback and disabled flag come straight from the spec.
abstract final class WindSwitchBuilder {
  /// Builds the switch for [spec].
  static Widget build(BuildContext context, LanguageSwitchSpec spec) =>
      wind.WSwitch(value: spec.value, onChanged: spec.enabled ? spec.onChanged : null, disabled: !spec.enabled);
}
