import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a native Material UI switch from a [LanguageSwitchSpec] (§9 Switch),
/// fully controlled by the spec.
abstract final class MaterialSwitchBuilder {
  /// Builds the switch for [spec].
  static Widget build(BuildContext context, LanguageSwitchSpec spec) => mu.Switch(
    value: spec.value,
    onChanged: spec.enabled ? spec.onChanged : null,
    focusNode: spec.focusNode,
    autofocus: spec.autofocus,
  );
}
