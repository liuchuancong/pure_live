// Module: lib/src/domain/home_tab.dart
// Purpose: The home tab model: the tab itself and the order-and-visibility rule over a saved layout.
// Author: liuchuancong
// Created: 2026-10-10
//
// The tab set is declared by the app, the order and the hidden set are chosen by the user, and the two have
// to be merged by a rule that survives a release where a tab disappears or a new one appears. That merge is
// the whole job here, so it is a pure function over a [HomeLayout] rather than behaviour living in a widget:
// a screen that recomputes it differently is a screen that moves the user's tabs on them.

import 'package:pure_live_utils/pure_live_utils.dart';

/// A tab on the home surface.
final class HomeTab {
  const HomeTab({required this.id, required this.label, this.defaultVisible = true});

  /// The stable id written into the saved order; never rename one without a migration.
  final String id;

  final String label;

  /// Whether the tab shows when the user has said nothing about it.
  ///
  /// This used to be `visible`, a single flag the organizer overwrote from the hidden set - which meant a
  /// tab shipped hidden by default came back visible the moment the organizer ran. The persisted choice and
  /// the default are different facts, and only a model that keeps both can tell them apart.
  final bool defaultVisible;

  HomeTab withDefaultVisible(bool value) => HomeTab(id: id, label: label, defaultVisible: value);

  @override
  String toString() => 'HomeTab($id)';
}

/// What the user has chosen: an order, plus the tabs they explicitly toggled off.
final class HomeLayout with ValueEquality {
  const HomeLayout({this.order = const <String>[], this.hidden = const <String>[]});

  /// Tab ids, most wanted first. Ids the app no longer has are kept: dropping them on read would lose the
  /// user's arrangement of everything behind them if a tab is temporarily unavailable.
  final List<String> order;

  /// Ids the user switched off. Membership is the whole meaning, so ordering here is irrelevant.
  final List<String> hidden;

  bool isHidden(String id) => hidden.contains(id);

  @override
  List<Object?> get equalityFields => <Object?>[order, hidden];
}

/// The merge result: the tabs in render order, each with the visibility that comes out of the rule.
final class ArrangedHomeTab {
  const ArrangedHomeTab({required this.tab, required this.isVisible, required this.userOrdered});

  final HomeTab tab;
  final bool isVisible;

  /// True when this position came from the user's saved order rather than from the app's default tail.
  final bool userOrdered;
}

/// Applies [HomeLayout] to a declared tab set.
///
/// Unknown saved ids are ignored for rendering (the tab was removed since), tabs the user never ordered keep
/// their default position after the ordered ones, and a hidden tab stays in the list so the settings screen
/// can re-show it without re-adding it.
final class HomeTabOrganizer {
  const HomeTabOrganizer({required this.defaults});

  final List<HomeTab> defaults;

  List<ArrangedHomeTab> arrange(HomeLayout layout) {
    final byId = <String, HomeTab>{for (final tab in defaults) tab.id: tab};
    final arranged = <ArrangedHomeTab>[];
    final seen = <String>{};

    for (final id in layout.order) {
      final tab = byId[id];
      // A repeated id in a corrupt order must not duplicate the tile; first occurrence wins.
      if (tab == null || !seen.add(id)) {
        continue;
      }
      arranged.add(_place(tab, layout, userOrdered: true));
    }
    for (final tab in defaults) {
      if (!seen.contains(tab.id)) {
        arranged.add(_place(tab, layout, userOrdered: false));
      }
    }
    return arranged;
  }

  /// The tabs a renderer shows, in order.
  List<HomeTab> visibleTabs(HomeLayout layout) => <HomeTab>[
    for (final placed in arrange(layout))
      if (placed.isVisible) placed.tab,
  ];

  ArrangedHomeTab _place(HomeTab tab, HomeLayout layout, {required bool userOrdered}) {
    final switchedOff = layout.isHidden(tab.id);
    return ArrangedHomeTab(
      tab: tab,
      // Both facts matter: an opt-out hides, and a default-hidden tab stays hidden until the user turns it
      // on - which is a different edit than removing it from `hidden`, and the settings screen needs to be
      // able to tell the two apart.
      isVisible: tab.defaultVisible && !switchedOff,
      userOrdered: userOrdered,
    );
  }
}
