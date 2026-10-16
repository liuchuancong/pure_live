import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a Material UI select control from a [LanguageSelectSpec] (§9 Select).
///
/// `mu.DropdownButton` is the fork's own select: it is generic over the caller's
/// value type, so the chosen value comes back unchanged, and its `hint` is the
/// spec's [LanguageSelectSpec.placeholder]. A disabled select is the library's own
/// inert state — a null `onChanged` greys the control and refuses the menu — so
/// [LanguageSelectSpec.enabled] needs no extra work.
abstract final class MaterialSelectBuilder {
  /// Builds the select control for [spec].
  static Widget build<T>(BuildContext context, LanguageSelectSpec<T> spec) {
    return mu.DropdownButton<T>(
      value: spec.value,
      hint: spec.placeholder == null ? null : Text(spec.placeholder!),
      isExpanded: true,
      items: [for (final item in spec.items) mu.DropdownMenuItem<T>(value: item, child: Text(spec.itemLabel(item)))],
      // The fork's menu can hand back a null selection; the contract has no
      // such case, so a null is dropped rather than reported.
      onChanged: spec.enabled
          ? (value) {
              if (value != null) {
                spec.onChanged?.call(value);
              }
            }
          : null,
    );
  }
}
