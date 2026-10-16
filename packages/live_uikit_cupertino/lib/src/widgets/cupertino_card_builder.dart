import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a Cupertino card from a [LanguageCardSpec] (§9 Card).
///
/// Composed, not mapped: `cupertino_ui` 1.1.2 ships no card and no box widget —
/// its exports have `CupertinoListSection`, `CupertinoFormSection` and
/// `CupertinoPopupSurface`, and only the first of those is a surface an inline
/// control can be put on. The iOS card *is* the inset-grouped section: the 10pt
/// rounded panel Notes and Reminders drop each item into, filled with the
/// library's own `secondarySystemGroupedBackground` and clipped to its own
/// superellipse. So the card is that widget rather than the shared renderer's
/// Material-shaped box.
///
/// Two of the section's own decisions are reset because they belong to a grouped
/// list and not to a card: `margin` is zeroed (its default is the page gutter an
/// iOS list draws around itself, and this card is placed by its caller) and
/// `backgroundColor` is transparent (the section otherwise paints a
/// `systemGroupedBackground` band behind the panel, while the frame already
/// supplies the page surface).
///
/// [LanguageCardSpec.padding] and the `dense` step land inside the panel;
/// [LanguageCardSpec.selected] and [Style.background] replace the panel fill, and
/// the override keeps the library's 10pt corner because that is what the panel
/// clips to. The parameter is typed `BoxDecoration`, so an override is drawn with
/// a circular radius while the library's own default is a superellipse — the one
/// place the fork's typing is coarser than its drawing.
/// [LanguageCardSpec.bordered] asks for an edge iOS cards do not have, so it adds
/// nothing rather than inventing a hairline. [LanguageCardSpec.onTap] /
/// [LanguageCardSpec.onLongPress] get an opaque hit area, since the library's tap
/// handling lives inside its buttons and none of them is a card;
/// [LanguageCardSpec.focusNode] / [LanguageCardSpec.autofocus] are unexpressible
/// — a section is a surface, not a control — exactly as recorded for the Fluent
/// and macOS cards (§9/§15).
abstract final class CupertinoCardBuilder {
  /// Builds the card for [spec].
  static Widget build(BuildContext context, LanguageCardSpec spec) {
    final theme = LiveTheme.of(context);
    final override = spec.style;
    final interactive = spec.onTap != null || spec.onLongPress != null;
    final fill = override?.background ?? (spec.selected ? theme.colors.primaryBg : null);

    Widget content = Padding(
      padding: spec.padding ?? EdgeInsets.all(spec.dense ? theme.card.padding * 0.66 : theme.card.padding),
      child: spec.child,
    );
    if (interactive) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: spec.onTap,
        onLongPress: spec.onLongPress,
        child: content,
      );
    }

    return cu.CupertinoListSection.insetGrouped(
      backgroundColor: const Color(0x00000000),
      margin: EdgeInsets.zero,
      decoration: fill == null
          ? null
          // The 10pt corner `_kDefaultInsetGroupedBorderRadius` clips to, which
          // the library does not expose.
          : BoxDecoration(color: fill, borderRadius: BorderRadius.circular(10)),
      children: [content],
    );
  }
}
