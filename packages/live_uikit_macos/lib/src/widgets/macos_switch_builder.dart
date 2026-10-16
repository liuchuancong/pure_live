import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a macOS switch from a [LanguageSwitchSpec] (§9 Switch): the library's
/// own `MacosSwitch`, the control whose track follows the theme's primary colour
/// and whose knob slides on a drag.
///
/// [LanguageSwitchSpec.enabled] is folded into the callback rather than
/// approximated: `MacosSwitch` derives its disabled look from a null `onChanged`
/// (the same rule this adapter already relies on for `MacosCheckbox`), so a dead
/// spec gets the library's own inert state instead of a closure that swallows the
/// value. The switch stays fully controlled — the value comes from the spec and
/// the library never mutates it.
///
/// [LanguageSwitchSpec.focusNode] and [LanguageSwitchSpec.autofocus] have no slot
/// on `MacosSwitch`: the control builds its own tap and drag recognizers and
/// takes no focus node, so keyboard activation of a switch is not expressible in
/// this library at all. Recorded as the gap it is rather than wrapped in a second
/// `Focus` that would hold the focus actually handling activation (§9/§15).
abstract final class MacosSwitchBuilder {
  /// Builds the switch for [spec].
  static Widget build(BuildContext context, LanguageSwitchSpec spec) => macos.MacosSwitch(
    value: spec.value,
    onChanged: spec.enabled ? spec.onChanged : null,
  );
}
