import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:forui/forui.dart' as forui;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:yaru/yaru.dart' as yaru;

/// The public switch: one widget, every theme and density. It carries only
/// semantics (`value`, `onChanged`, `enabled`); its appearance comes straight
/// from the active design language's own widget library. There is no adapter
/// and no spec in between: [build] switches on `UiConfig.language` and
/// constructs the library's real component directly — fluent_2's `FluentSwitch`
/// under fluent, `MacosSwitch` under macOS, `CupertinoSwitch` under iOS — so
/// what the user sees is exactly what that library's own documentation shows.
/// Switching `UiConfig.language` re-skins every switch.
class PureSwitch extends StatelessWidget {
  /// A switch bound to [value].
  const new({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the next value; null (or `enabled: false`) disables it.
  final ValueChanged<bool>? onChanged;

  /// Whether the switch responds to input.
  final bool enabled;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    // A null callback is every library's own inert state, so folding `enabled`
    // into it once serves all the branches below.
    final select = enabled ? onChanged : null;

    return switch (theme.config.language) {
      PureDesignLanguage.fluent => f2.FluentSwitch(
        checked: value,
        onChanged: select,
        focusNode: focusNode,
        autofocus: autofocus,
      ),
      // `MacosSwitch` derives its disabled look from the null callback and
      // takes no focus node: the control builds its own tap and drag
      // recognizers, so keyboard activation is not expressible in this library.
      PureDesignLanguage.macos => macos.MacosSwitch(value: value, onChanged: select),
      // The Cupertino switch has no focus slot either; a null callback greys it.
      PureDesignLanguage.cupertino => cupertino.CupertinoSwitch(value: value, onChanged: select),
      PureDesignLanguage.forui => forui.FSwitch(
        value: value,
        // Fully controlled: the fork reports the next value and never keeps
        // state of its own, and the null callback reaches it as null (§9).
        onChange: select,
        enabled: enabled,
        focusNode: focusNode,
        autofocus: autofocus,
      ),
      // glass_morphism_plus ships no toggle. Fall back to Flutter's official
      // Material switch rather than drawing a hand-rolled one; the surrounding
      // glass surfaces still carry the language.
      PureDesignLanguage.glass => Switch(value: value, onChanged: select, focusNode: focusNode, autofocus: autofocus),
      // `NeuSwitch` takes colours, geometry and a callback — no focus node and
      // no autofocus — so [focusNode] has nowhere to go in this library.
      PureDesignLanguage.neumorphic => neu.NeuSwitch(value: value, onChanged: select),
      // Wind's fork paints its own `disabled:` state from this flag, so the
      // flag and the nulled callback come from the same verdict. The fork is
      // utility-class driven: with no classes the track and thumb are bare
      // boxes and the switch is invisible, so the grammar is spelled here in
      // its own dialect (the thumb rides `justify-start` → `checked:
      // justify-end`, the only motion its parser understands). Like the other
      // libraries without a focus slot, `WSwitch` takes no node — its tap is a
      // gesture, not a focusable control.
      PureDesignLanguage.wind => wind.WSwitch(
        value: value,
        onChanged: select,
        disabled: select == null,
        className:
            'w-11 h-6 rounded-full px-0.5 flex items-center justify-start checked:justify-end '
            'bg-gray-300 checked:bg-blue-600 disabled:opacity-50',
        thumbClassName: 'w-5 h-5 rounded-full bg-white',
      ),
      // Yaru's own switch: Ubuntu draws a wider pill with a squared thumb, and
      // `YaruSwitch` takes the same four slots this contract needs (value,
      // callback, focus node, autofocus), so the language has nothing to give up.
      PureDesignLanguage.yaru => yaru.YaruSwitch(
        value: value,
        onChanged: select,
        focusNode: focusNode,
        autofocus: autofocus,
      ),
      PureDesignLanguage.material => Switch(
        value: value,
        onChanged: select,
        focusNode: focusNode,
        autofocus: autofocus,
      ),
    };
  }
}
