import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/shared/enums/navigation_item.dart' show NavigationItem;

/// The destination the shell currently shows.
final class SelectedNavItemController extends Notifier<NavigationItem> {
  @override
  NavigationItem build() => NavigationItem.home;

  /// The destination the shell is showing.
  NavigationItem get selected => state;

  /// Moves the selection; the layouts read this for their bars and rails.
  set selected(NavigationItem item) => state = item;
}

/// The selected navigation destination.
final selectedNavItemProvider = NotifierProvider<SelectedNavItemController, NavigationItem>(
  SelectedNavItemController.new,
);
