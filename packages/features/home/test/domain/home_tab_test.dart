// Module: test/domain/home_tab_test.dart
// Purpose: Pins the merge rule between the app's declared tabs and the user's saved layout.
// Author: liuchuancong
// Created: 2026-10-10

import 'package:pure_live_home/pure_live_home.dart';
import 'package:test/test.dart';

const List<HomeTab> _defaults = <HomeTab>[
  HomeTab(id: 'live', label: '直播'),
  HomeTab(id: 'vod', label: '影视'),
  HomeTab(id: 'music', label: '音乐', defaultVisible: false),
];

void main() {
  test('test_homeTabOrganizer_putsSavedOrderFirstAndKeepsDefaultsBehindIt', () {
    const layout = HomeLayout(order: <String>['vod']);
    final arranged = HomeTabOrganizer(defaults: _defaults).arrange(layout);

    expect(arranged.map((placed) => placed.tab.id), <String>['vod', 'live', 'music']);
    expect(arranged.first.userOrdered, isTrue);
    expect(arranged.last.userOrdered, isFalse);
  });

  test('test_homeTabOrganizer_ignoresSavedIdsTheAppNoLongerHas', () {
    const layout = HomeLayout(order: <String>['gone', 'vod']);
    final arranged = HomeTabOrganizer(defaults: _defaults).arrange(layout);

    expect(arranged.map((placed) => placed.tab.id), <String>['vod', 'live', 'music']);
  });

  test('test_homeTabOrganizer_defaultHiddenTabStaysHidden', () {
    // The bug this replaces: one `visible` flag was overwritten from the hidden set, so a tab shipped
    // hidden came back visible the moment the organizer ran.
    final arranged = HomeTabOrganizer(defaults: _defaults).arrange(const HomeLayout());

    expect(arranged.firstWhere((placed) => placed.tab.id == 'music').isVisible, isFalse);
    expect(arranged.firstWhere((placed) => placed.tab.id == 'live').isVisible, isTrue);
  });

  test('test_homeTabOrganizer_hiddenTabStaysInTheList', () {
    const layout = HomeLayout(order: <String>['live', 'vod'], hidden: <String>['vod']);
    final organizer = HomeTabOrganizer(defaults: _defaults);

    expect(organizer.arrange(layout).map((placed) => placed.tab.id), <String>['live', 'vod', 'music']);
    expect(organizer.visibleTabs(layout).map((tab) => tab.id), <String>['live']);
  });

  test('test_homeTabOrganizer_duplicateSavedIdDoesNotDuplicateTheTile', () {
    const layout = HomeLayout(order: <String>['vod', 'vod']);
    final arranged = HomeTabOrganizer(defaults: _defaults).arrange(layout);

    expect(arranged.map((placed) => placed.tab.id).toSet(), <String>{'vod', 'live', 'music'});
  });

  test('test_homeLayout_equalityIsByContentNotByInstance', () {
    expect(
      const HomeLayout(order: <String>['a'], hidden: <String>['b']),
      const HomeLayout(order: <String>['a'], hidden: <String>['b']),
    );
    expect(const HomeLayout(order: <String>['a']) == const HomeLayout(order: <String>['b']), isFalse);
  });
}
