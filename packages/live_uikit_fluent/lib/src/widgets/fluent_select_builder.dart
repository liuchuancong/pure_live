import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';

/// Builds a native Fluent select control from a [LanguageSelectSpec] (§9 Select).
///
/// Each spec item becomes one `fluent.ComboBoxItem`, so the caller's own value
/// type survives the swap — `fluent.ComboBox<T>` hands the selected value back
/// unchanged. A disabled select drops its callback (fluent_ui disables the combo
/// box whenever `onChanged` is null) and keeps the placeholder visible, greyed.
abstract final class FluentSelectBuilder {
  /// Builds the select control for [spec].
  static Widget build<T>(BuildContext context, LanguageSelectSpec<T> spec) {
    final onChanged = spec.onChanged;
    final hint = spec.placeholder;
    final placeholder = hint == null ? null : Text(hint);
    return fluent.ComboBox<T>(
      value: spec.value,
      items: [for (final item in spec.items) fluent.ComboBoxItem<T>(value: item, child: Text(spec.itemLabel(item)))],
      onChanged: spec.enabled && onChanged != null
          ? (value) {
              if (value != null) {
                onChanged(value);
              }
            }
          : null,
      placeholder: placeholder,
      disabledPlaceholder: placeholder,
    );
  }
}
