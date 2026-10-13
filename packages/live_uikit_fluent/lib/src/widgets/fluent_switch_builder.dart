import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';

/// Builds a native Fluent toggle from a [LanguageSwitchSpec] (§9 Switch). The
/// switch stays fully controlled — value and callback come from the spec, with no
/// local or persistent state invented here.
abstract final class FluentSwitchBuilder {
  /// Builds the switch for [spec].
  static Widget build(BuildContext context, LanguageSwitchSpec spec) => fluent.ToggleSwitch(
    checked: spec.value,
    onChanged: spec.enabled ? spec.onChanged : null,
    focusNode: spec.focusNode,
    autofocus: spec.autofocus,
  );
}
