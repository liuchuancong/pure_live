import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';

/// Builds a ForUI page bar from a [LanguageAppBarSpec] (§9 AppBar).
///
/// `FHeader.nested` is the library's own bar with both action slots:
/// [LanguageAppBarSpec.leading] goes into `prefixes` and [LanguageAppBarSpec.actions]
/// into `suffixes` as the arbitrary widgets the contract carries — the library lays them
/// out and pads them itself. The root variant is not used because it has no leading slot,
/// and a bar the caller gave a back affordance to cannot lose it.
///
/// [LanguageAppBarSpec.centerTitle] maps onto the header's `titleAlignment`, and null
/// keeps the library's *page* bar default — start-aligned — since centring a title is
/// what the nested variant does for a page inside a navigation stack, not what this
/// contract's page bar does by default. [LanguageAppBarSpec.background] and
/// [LanguageAppBarSpec.height] go through the style delta, so the colour and the bar
/// height are the library's fields written by the caller, not a box painted over the
/// widget.
///
/// [LanguageAppBarSpec.bottom] is stacked under the bar in a column: a ForUI header is
/// one row, and the strip the contract puts there (a dispatched `LiveTabs`) belongs below
/// it rather than inside it.
abstract final class ForuiAppBarBuilder {
  /// Builds the bar for [spec].
  static Widget build(BuildContext context, LanguageAppBarSpec spec) {
    final leading = spec.leading;
    final header = forui.FHeader.nested(
      title: Text(spec.title),
      titleAlignment: spec.centerTitle == true ? Alignment.center : AlignmentDirectional.centerStart,
      prefixes: leading == null ? const <Widget>[] : <Widget>[leading],
      suffixes: spec.actions,
      style: spec.background == null && spec.height == null
          ? const forui.FHeaderStyleDelta.context()
          : forui.FHeaderStyleDelta.delta(
              constraints: switch (spec.height) {
                final height? => BoxConstraints.tightFor(height: height),
                null => null,
              },
              decoration: switch (spec.background) {
                final color? => forui.DecorationDelta.boxDelta(color: color),
                null => null,
              },
            ),
    );

    final bottom = spec.bottom;
    return bottom == null ? header : Column(mainAxisSize: MainAxisSize.min, children: [header, bottom]);
  }
}
