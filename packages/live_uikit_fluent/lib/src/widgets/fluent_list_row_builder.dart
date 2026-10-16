import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';

/// Builds a Fluent list row from a [LanguageListRowSpec] (§9 ListRow).
///
/// `fluent.ListTile` carries the same parts as the spec — leading, title,
/// subtitle, trailing, `onPressed`, focus — so the row is Fluent's own: its
/// hover fill, its ink and its typography come from `FluentTheme` rather than
/// from the token approximation.
///
/// Three fields have no native slot and are mapped rather than dropped:
/// [LanguageListRowSpec.selected] becomes Fluent's `tileColor` (the library has
/// no selected state), [LanguageListRowSpec.onLongPress] is recognised by a
/// gesture wrapper around the whole tile, and [LanguageListRowSpec.divided]
/// draws the hairline itself because Fluent's `Divider` takes no colour.
abstract final class FluentListRowBuilder {
  /// Builds the row for [spec].
  static Widget build(BuildContext context, LanguageListRowSpec spec) {
    final theme = LiveTheme.of(context);
    final secondary = theme.colors.textSecondary;
    final row = fluent.ListTile(
      leading: spec.leading,
      title: Text(spec.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: spec.subtitle == null
          ? null
          : Text(
              spec.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle().copyWith(color: secondary),
            ),
      trailing: spec.trailing,
      onPressed: spec.onTap,
      tileColor: spec.selected ? WidgetStateColor.resolveWith((_) => theme.listTile.selectedBackground) : null,
      focusNode: spec.focusNode,
      autofocus: spec.autofocus,
    );

    final longPressable = spec.onLongPress == null
        ? row
        : GestureDetector(behavior: HitTestBehavior.translucent, onLongPress: spec.onLongPress, child: row);

    if (!spec.divided) {
      return longPressable;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        longPressable,
        Container(height: theme.token.motion.lineWidth, color: theme.listTile.dividerColor),
      ],
    );
  }
}
