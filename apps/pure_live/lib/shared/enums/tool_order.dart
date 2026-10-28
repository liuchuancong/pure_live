import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/shared/enums/navigation_item.dart';

/// The order key. It has exactly one writer — the order editor's save — so
/// the sidebar's tools block keeps the default order until the viewer has
/// saved an edit, and nothing else can move them. (The legacy `tools.order`
/// key predates the draft editor; it is left unread.)
const String kToolOrderKey = 'tools.menuOrder';

/// The tools the sidebar shows under its divider, in the viewer's order.
///
/// The order persists under [kToolOrderKey] as the items' names; an entry
/// the list does not know (a tool added later) keeps the default order at
/// its end, so a stored order can never drop a tool.
final class ToolOrderController extends Notifier<List<NavigationItem>> {
  @override
  List<NavigationItem> build() {
    try {
      final stored = StoragePrefs.getStringList(kToolOrderKey);
      if (stored == null || stored.isEmpty) return kToolItems;
      final known = {for (final item in kToolItems) item.name: item};
      final ordered = [for (final name in stored) ?known.remove(name)];
      return [...ordered, ...known.values];
    } on Object {
      return kToolItems;
    }
  }

  /// Stores [items] as the tools' order — the one writer of the order key.
  /// Only a full rearrangement of the tools this build knows is accepted:
  /// the order editor hands back the same list it was shown, and anything
  /// else would drop a tool from the sidebar.
  Future<void> setOrder(List<NavigationItem> items) async {
    // Set equality is identity in Dart, so a `.toSet() ==` guard here would
    // always fail and silently swallow every save; the length-plus-members
    // check is the real rearrangement test.
    if (items.length != kToolItems.length || !items.every(kToolItems.contains)) return;
    state = items;
    try {
      await StoragePrefs.setStringList(kToolOrderKey, [for (final item in items) item.name]);
    } on Object {
      // The order is a preference; a closed store loses it.
    }
  }
}

/// The sidebar's tools, in the viewer's order.
final toolOrderProvider = NotifierProvider<ToolOrderController, List<NavigationItem>>(ToolOrderController.new);
