import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/shared/enums/navigation_item.dart';

/// The tools the sidebar shows under its divider, in the viewer's order.
///
/// The order persists under `tools.order` as the items' names; an entry
/// the list does not know (a tool added later) keeps the default order at
/// its end, so a stored order can never drop a tool.
final class ToolOrderController extends Notifier<List<NavigationItem>> {
  @override
  List<NavigationItem> build() {
    try {
      final stored = StoragePrefs.getStringList('tools.order');
      if (stored == null || stored.isEmpty) return kToolItems;
      final known = {for (final item in kToolItems) item.name: item};
      final ordered = [for (final name in stored) ?known.remove(name)];
      return [...ordered, ...known.values];
    } on Object {
      return kToolItems;
    }
  }

  /// Stores [items] as the tools' order. Only a full rearrangement of the
  /// tools this build knows is accepted: the order editor hands back the same
  /// list it was shown, and anything else would drop a tool from the sidebar.
  Future<void> setOrder(List<NavigationItem> items) async {
    if (items.length != kToolItems.length || items.toSet() != kToolItems.toSet()) return;
    state = items;
    try {
      await StoragePrefs.setStringList('tools.order', [for (final item in items) item.name]);
    } on Object {
      // The order is a preference; a closed store loses it.
    }
  }
}

/// The sidebar's tools, in the viewer's order.
final toolOrderProvider = NotifierProvider<ToolOrderController, List<NavigationItem>>(ToolOrderController.new);
