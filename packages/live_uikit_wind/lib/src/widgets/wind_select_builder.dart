import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/styling.dart';

/// Builds a native Wind select from a [LanguageSelectSpec] (§9 Select).
///
/// `WSelect<T>` takes the same typed value the spec carries, so the caller's
/// own item type survives the swap: every spec item becomes one
/// `wind.SelectOption<T>` whose label comes from the spec's `itemLabel`, and
/// the chosen option's value is handed back unchanged. A null callback or
/// `enabled: false` disables the fork outright (`disabled: true` plus no
/// `onChange`) rather than leaving an openable menu that reports nothing.
///
/// The trigger and menu stay the fork's own surfaces: `WSelect` styles through
/// utility classNames and has no slot for a resolved `Style` or a token
/// border, and hand-painting one over the overlay it mounts would be the
/// overlay §8.1 rules out (§15). The spec has no search, pagination or
/// multi-select fields, so none is enabled here.
abstract final class WindSelectBuilder {
  /// Builds the select for [spec].
  static Widget build<T>(BuildContext context, LanguageSelectSpec<T> spec) {
    // `WSelect.onChange` is a `ValueChanged<T>` and only ever reports the pick
    // of an existing option, so the spec's callback passes straight through —
    // the same shape, and null means the same "not interactive" here.
    final onChanged = spec.enabled ? spec.onChanged : null;
    return wind.WSelect<T>(
      value: spec.value,
      options: [for (final item in spec.items) wind.SelectOption<T>(value: item, label: spec.itemLabel(item))],
      onChange: onChanged,
      placeholder: spec.placeholder ?? '',
      disabled: onChanged == null,
    );
  }
}
