import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';

/// Builds a Cupertino bottom bar from a [LanguageNavBarSpec] (§9 NavBar).
///
/// `cu.CupertinoTabBar` is the contract's iOS counterpart: destinations carry an
/// icon and a label, the selection is an index and the callback is an index, and
/// the active tint comes from the theme rather than from the token primary — the
/// one place where letting the library decide is more honest than painting it
/// ourselves.
abstract final class CupertinoUiNavBarBuilder {
  /// Builds the bar for [spec].
  static Widget build(BuildContext context, LanguageNavBarSpec spec) {
    final theme = LiveTheme.of(context);
    return cu.CupertinoTabBar(
      items: [for (final item in spec.items) cu.BottomNavigationBarItem(icon: Icon(item.icon), label: item.label)],
      currentIndex: spec.index,
      onTap: spec.enabled ? spec.onChanged : null,
      activeColor: theme.colors.primary,
      backgroundColor: theme.colors.bgElevated,
    );
  }
}
