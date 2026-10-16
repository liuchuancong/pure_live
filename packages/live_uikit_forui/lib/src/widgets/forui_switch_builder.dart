import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';

/// Renders a [LanguageSwitchSpec] with `FSwitch` (§9 Switch).
abstract final class ForuiSwitchBuilder {
  /// Builds the switch for [spec].
  static Widget build(BuildContext context, LanguageSwitchSpec spec) => forui.FSwitch(
    value: spec.value,
    // Fully controlled: the fork reports the next value and never keeps state of its
    // own, and a null callback is passed on as null rather than as a no-op (§9).
    onChange: spec.enabled ? spec.onChanged : null,
    enabled: spec.enabled,
    focusNode: spec.focusNode,
    autofocus: spec.autofocus,
  );
}
