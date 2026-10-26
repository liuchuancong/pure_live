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

  /// Moves the tool at [from] to [to], writing the order through.
  Future<void> move(int from, int to) async {
    if (from < 0 || to < 0 || from >= state.length || to >= state.length || from == to) return;
    final next = [...state];
    final item = next.removeAt(from);
    next.insert(to, item);
    state = next;
    try {
      await StoragePrefs.setStringList('tools.order', [for (final item in next) item.name]);
    } on Object {
      // The order is a preference; a closed store loses it.
    }
  }
}

/// The sidebar's tools, in the viewer's order.
final toolOrderProvider = NotifierProvider<ToolOrderController, List<NavigationItem>>(ToolOrderController.new);
