import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/live_uikit.dart';

/// The library's own bar height (`kToolbarHeight`), restated as a literal because
/// this file builds on the widgets layer and does not import Material.
const double _kToolbarHeight = 56;

/// Builds a Neumorphic top bar from a [LanguageAppBarSpec] (§9 AppBar).
///
/// **Mapped.** `NeuAppBar` is this control: a `NeuContainer` plane carrying a
/// `NavigationToolbar` with the leading widget, the title and the trailing row,
/// and it takes the status-bar inset itself (`MediaQuery.paddingOf`). It is an
/// ordinary `StatelessWidget` that also implements `PreferredSizeWidget`, so it
/// needs neither a Material `Scaffold` nor an app shell — it renders inline in a
/// page, and the Neumorphic frame stacks it by flex rather than by
/// [PreferredSizeWidget.preferredSize]. The title is left as a bare [Text]: the
/// bar's own type (18, w700, `isDark`-derived) is the language's reading of a page
/// title, and only ellipsis is added so a long title cannot overflow the toolbar.
///
/// Handled rather than dropped, field by field:
/// - [LanguageAppBarSpec.leading] and [LanguageAppBarSpec.actions] map straight
///   through — the library's `actions` is a `List<Widget>?` laid out in a trailing
///   row, exactly the contract's "actions after the title, in order"; an empty list
///   is passed as null so the toolbar does not reserve a slot for it.
/// - [LanguageAppBarSpec.centerTitle] maps onto the library's own `centerTitle`,
///   which defaults to true; a null spec therefore asks for a centred bar, which is
///   what this style does by default.
/// - [LanguageAppBarSpec.height] maps onto `height`, null taking the library's
///   default [_kToolbarHeight]. It sizes the title row only, as it does there.
/// - [LanguageAppBarSpec.background] maps onto `baseColor`, the bar plane's surface
///   colour — the library's own way of overriding a surface, not a fill painted
///   over it.
/// - [LanguageAppBarSpec.bottom] is the one field with no slot: the library types
///   it as `PreferredSizeWidget?`, while the contract's bottom strip is any
///   dispatched widget — the Neumorphic tab strip is a `Row` of cells, which has no
///   preferred size. So the strip is stacked under the bar in a column on the same
///   plane, the way the Fluent header does it, rather than forced through a slot it
///   cannot fill.
abstract final class NeumorphicAppBarBuilder {
  /// Builds the bar for [spec].
  static Widget build(BuildContext context, LanguageAppBarSpec spec) {
    final surface = neu.NeuTheme.of(context);
    final bar = neu.NeuAppBar(
      title: Text(spec.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      leading: spec.leading,
      actions: spec.actions.isEmpty ? null : spec.actions,
      centerTitle: spec.centerTitle ?? true,
      height: spec.height ?? _kToolbarHeight,
      baseColor: spec.background ?? surface.baseColor,
    );

    final bottom = spec.bottom;
    if (bottom == null) {
      return bar;
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [bar, bottom]);
  }
}
