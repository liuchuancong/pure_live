// Module: lib/src/domain/home_layout_service.dart
// Purpose: The two edits a user can actually make to their home tabs, expressed against the declared set.
// Author: liuchuancong
// Created: 2026-10-10
//
// A screen should not assemble order lists or decide what "hide this tab" means: those rules have to be the
// same in the settings list, the long-press menu and whatever the TV remote reaches, and three copies of an
// edit rule is how a tab ends up both ordered and deleted. This is the single place that turns an intent
// into a [HomeLayout].

import 'home_layout_repository.dart';
import 'home_tab.dart';

/// Declares the app's tabs and reads back what to render.
final class HomeLayoutService {
  HomeLayoutService({required this.defaults, required this.repository});

  /// The tabs this app declares, in the order the app ships them.
  final List<HomeTab> defaults;

  final HomeLayoutRepository repository;

  HomeTabOrganizer get _organizer => HomeTabOrganizer(defaults: defaults);

  /// The layout plus every tab with its computed visibility, in render order.
  Future<List<ArrangedHomeTab>> arrange() async => _organizer.arrange(await repository.load());

  /// Only the tabs that should appear, in order.
  Future<List<HomeTab>> visibleTabs() async => _organizer.visibleTabs(await repository.load());

  /// Saved ids with no matching declared tab.
  ///
  /// Normal after a release removes a tab, so it is a diagnostic rather than an error - but a typo in a new
  /// tab's id shows up here as a tab the user can never move.
  Future<List<String>> staleSavedIds() async {
    final layout = await repository.load();
    final known = <String>{for (final tab in defaults) tab.id};
    return <String>[...layout.order, ...layout.hidden].where((id) => !known.contains(id)).toList();
  }

  /// Moves [id] to the front, which is what "the user opened this tab again" means for the arrangement.
  Future<HomeLayout> recordUse(String id) async {
    final layout = await repository.load();
    return repository.save(
      HomeLayout(order: <String>[id, ...layout.order.where((saved) => saved != id)], hidden: layout.hidden),
    );
  }

  /// Switches [id] off or back on without disturbing where it sits in the order.
  ///
  /// Re-showing a tab must put it back in the row the user left it in, which is why hiding is a separate set
  /// and not a deletion from the order.
  Future<HomeLayout> setHidden(String id, {required bool hidden}) async {
    final layout = await repository.load();
    final hiddenIds = <String>{...layout.hidden};
    if (hidden) {
      hiddenIds.add(id);
    } else {
      hiddenIds.remove(id);
    }
    // Sorted so two devices that made the same choice write the same bytes.
    final sorted = hiddenIds.toList()..sort();
    return repository.save(HomeLayout(order: layout.order, hidden: sorted));
  }

  /// Puts the arrangement back to the app's declared defaults.
  Future<void> reset() => repository.reset();
}
