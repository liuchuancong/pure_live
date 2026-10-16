import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a Material UI bottom navigation bar from a [LanguageNavBarSpec]
/// (§9 NavBar).
///
/// `mu.NavigationBar` is the contract's counterpart one-for-one: destinations
/// carry an icon and a label, the selected index is an `int`, and the callback is
/// an index rather than a route, so the shell's branch switching survives the
/// language change. [LanguageNavBarSpec.enabled] is mapped by disabling the bar
/// (the library's own inert state) rather than dropping the callback.
abstract final class MaterialNavBarBuilder {
  /// Builds the bar for [spec].
  static Widget build(BuildContext context, LanguageNavBarSpec spec) {
    return mu.NavigationBar(
      selectedIndex: spec.index,
      onDestinationSelected: spec.enabled ? spec.onChanged : null,
      destinations: [for (final item in spec.items) mu.NavigationDestination(icon: Icon(item.icon), label: item.label)],
    );
  }
}
