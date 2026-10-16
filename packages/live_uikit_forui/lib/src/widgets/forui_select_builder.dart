import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';

/// Builds a ForUI select from a [LanguageSelectSpec] (§9 Select).
///
/// `FSelect<T>` is the library's own dropdown and it is generic over the caller's value
/// type, so a chosen value comes back unchanged. The library builds it as a field plus a
/// popover, and the popover opens on the caller's tap into the nearest overlay — that is
/// the widget's own behaviour, not an ancestor this adapter has to provide, so
/// [LanguageSelectSpec] still gets a single inline widget back.
///
/// The selection is handed to the library in its *lifted* form
/// ([forui.FSelectControl.lifted]): the spec's `value` goes in and the picked value comes
/// out, so the caller keeps ownership and no `FSelectController` is minted here. Items go
/// through `FSelect.rich` rather than through the library's `items:` map constructor
/// because a map is keyed by the display label — two items the caller labels the same
/// would collapse into one option, while this contract's items are values and
/// [LanguageSelectSpec.itemLabel] is just how each one is announced.
///
/// `expands` is deliberately not asked for: the library's select field forwards its own
/// `maxLines` to the text field underneath it, and that combination trips the fork's
/// `minLines and maxLines must be null when expands is true` assertion — a measured fact of
/// forui 0.27.5, not a style choice. The field takes the width it is given anyway.
///
/// A disabled select is the library's own inert state (`enabled: false`), reached by both
/// [LanguageSelectSpec.enabled] being false and a null [LanguageSelectSpec.onChanged]
/// (§9). A null [LanguageSelectSpec.placeholder] is left to the library, which labels the
/// empty field with its own localized "select an item" hint.
abstract final class ForuiSelectBuilder {
  /// Builds the select control for [spec].
  static Widget build<T>(BuildContext context, LanguageSelectSpec<T> spec) => forui.FSelect<T>.rich(
    format: spec.itemLabel,
    control: forui.FSelectControl<T>.lifted(
      value: spec.value,
      // The lifted control reports a deselection as null; this contract has no such case,
      // so a null is dropped rather than handed to the caller as a value.
      onChange: (value) {
        if (value != null) {
          spec.onChanged?.call(value);
        }
      },
    ),
    hint: spec.placeholder,
    enabled: spec.enabled && spec.onChanged != null,
    children: [for (final item in spec.items) forui.FSelectItem<T>(title: Text(spec.itemLabel(item)), value: item)],
  );
}
