// Module: test/domain/home_layout_service_test.dart
// Purpose: Pins the two user-facing edits: move to front, and hide without losing the position.
// Author: liuchuancong
// Created: 2026-10-10

import 'package:pure_live_home/pure_live_home.dart';
import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:test/test.dart';

void main() {
  const List<HomeTab> _defaults = <HomeTab>[
    HomeTab(id: 'live', label: '直播'),
    HomeTab(id: 'vod', label: '影视'),
    HomeTab(id: 'music', label: '音乐'),
  ];

  HomeLayoutService service(MemoryKeyValueStore store) => HomeLayoutService(
    defaults: _defaults,
    repository: StoredHomeLayout(store: store, namespace: 'app'),
  );

  test('test_homeLayoutService_recordUse_movesToFrontWithoutDuplicating', () async {
    final stored = service(MemoryKeyValueStore());
    await stored.recordUse('vod');
    await stored.recordUse('music');
    await stored.recordUse('vod');

    expect((await stored.arrange()).map((placed) => placed.tab.id), <String>['vod', 'music', 'live']);
  });

  test('test_homeLayoutService_setHidden_thenShowsAgain_restoresThePosition', () async {
    final stored = service(MemoryKeyValueStore());
    await stored.recordUse('live');
    await stored.recordUse('vod');
    await stored.setHidden('live', hidden: true);

    // 'music' was never ordered, so it keeps its default place behind the ordered tabs and stays visible.
    expect((await stored.visibleTabs()).map((tab) => tab.id), <String>['vod', 'music']);
    // The hidden tab is still in the arrangement, so settings can list it as "turned off" rather than gone.
    expect((await stored.arrange()).map((placed) => placed.tab.id), <String>['vod', 'live', 'music']);

    await stored.setHidden('live', hidden: false);
    expect((await stored.visibleTabs()).map((tab) => tab.id), <String>['vod', 'live', 'music']);
  });

  test('test_homeLayoutService_staleSavedIds_namesTabsTheAppNoLongerDeclares', () async {
    final store = MemoryKeyValueStore();
    await StoredHomeLayout(
      store: store,
      namespace: 'app',
    ).save(const HomeLayout(order: <String>['removed', 'vod'], hidden: <String>['also-gone']));

    expect(await service(store).staleSavedIds(), <String>['removed', 'also-gone']);
  });

  test('test_homeLayoutService_reset_returnsTheDeclaredOrder', () async {
    final stored = service(MemoryKeyValueStore());
    await stored.recordUse('music');
    await stored.reset();

    expect((await stored.arrange()).map((placed) => placed.tab.id), <String>['live', 'vod', 'music']);
  });
}
