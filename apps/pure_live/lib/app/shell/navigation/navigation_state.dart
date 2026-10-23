import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/shell/navigation/navigation_item.dart' show NavigationItem;

/// The branch the shell currently shows.
final class SelectedBranchController extends Notifier<NavigationItem> {
  @override
  NavigationItem build() => NavigationItem.home;

  /// The branch the shell is showing.
  NavigationItem get selected => state;

  /// Moves the selection; the shells read this for their rail and bar.
  set selected(NavigationItem item) => state = item;
}

/// The selected branch.
final selectedBranchProvider = NotifierProvider<SelectedBranchController, NavigationItem>(SelectedBranchController.new);
