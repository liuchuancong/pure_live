import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';

/// Builds a native Wind switch from a [LanguageSwitchSpec] (§9 Switch). Fully
/// controlled — value, callback and disabled flag come straight from the spec,
/// and a null `onChanged` disables the switch just as `enabled: false` does, so
/// the flag the fork paints from never disagrees with the callback it has.
abstract final class WindSwitchBuilder {
  /// Builds the switch for [spec].
  static Widget build(BuildContext context, LanguageSwitchSpec spec) {
    final onChanged = spec.enabled ? spec.onChanged : null;
    return wind.WSwitch(value: spec.value, onChanged: onChanged, disabled: onChanged == null);
  }
}
