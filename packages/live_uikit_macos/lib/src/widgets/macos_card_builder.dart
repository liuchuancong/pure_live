import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a macOS card from a [LanguageCardSpec] (§9 Card).
///
/// Composed, not mapped: `macos_ui` 2.2.2 ships no card and no box widget — its
/// exports contain no `MacosCard` and no `MacosBox`, only window-level surfaces.
/// The one panel it has that can be mounted inline is `MacosSheet`, the widget
/// `showMacosSheet` puts in its route: a 12pt rounded panel filled with the
/// control background and edged with the library's own inner and outer hairlines,
/// which is exactly what a macOS group box looks like. So the card is that panel,
/// with the token's padding inside it and the token's selection tint on its fill,
/// rather than the shared renderer's Material-shaped surface.
///
/// `insetPadding` is set to zero because the sheet's default (140 horizontal, 48
/// vertical) is the clearance a dialog route gives a modal; an inline card is
/// sized by its own content. Of the inline [Style] only [Style.background] is
/// read — the panel's radius and its double hairline are the library's decision,
/// the same way `MacosPopupButton` decides its own edge.
///
/// Three fields are handled rather than dropped: [LanguageCardSpec.bordered] asks
/// for an edge the sheet already draws, so it needs no extra work;
/// [LanguageCardSpec.onTap] / [LanguageCardSpec.onLongPress] get the pointer
/// affordance macOS itself uses (a click cursor over an opaque hit area), since
/// the library's own tap handling lives inside its buttons and none of them is a
/// card; and [LanguageCardSpec.focusNode] / [LanguageCardSpec.autofocus] are
/// unexpressible — a sheet is a surface, not a control, exactly as recorded for
/// the Fluent card (§9/§15).
abstract final class MacosCardBuilder {
  /// Builds the card for [spec].
  static Widget build(BuildContext context, LanguageCardSpec spec) {
    final theme = LiveTheme.of(context);
    final override = spec.style;
    final interactive = spec.onTap != null || spec.onLongPress != null;
    final content = spec.child;
    return macos.MacosSheet(
      insetPadding: EdgeInsets.zero,
      backgroundColor: override?.background ?? (spec.selected ? theme.colors.primaryBg : null),
      child: Padding(
        padding: spec.padding ?? EdgeInsets.all(spec.dense ? theme.card.padding * 0.66 : theme.card.padding),
        child: interactive
            ? MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: spec.onTap,
                  onLongPress: spec.onLongPress,
                  child: content,
                ),
              )
            : content,
      ),
    );
  }
}
