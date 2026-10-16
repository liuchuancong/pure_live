import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';

/// Builds a ForUI destination strip from a [LanguageNavBarSpec] (§9 NavBar).
///
/// `FBottomNavigationBar` is the contract's counterpart one-for-one: the children are
/// `FBottomNavigationBarItem`s carrying an icon and a label, the selection is an index,
/// and the callback is an index rather than a route — so a page's branch switching
/// survives the language change, and the bar keeps the library's decoration, top border
/// and safe-area padding.
///
/// [LanguageNavBarSpec.enabled] is mapped by handing the library a null `onChange`, its
/// own inert state: the destinations keep their labels and grey out instead of staying
/// live with a swallowed callback (§9).
abstract final class ForuiNavBarBuilder {
  /// Builds the strip for [spec].
  static Widget build(BuildContext context, LanguageNavBarSpec spec) => forui.FBottomNavigationBar(
    index: spec.index,
    onChange: spec.enabled ? spec.onChanged : null,
    children: [
      for (final item in spec.items)
        forui.FBottomNavigationBarItem(icon: Icon(item.icon), label: Text(item.label)),
    ],
  );
}
