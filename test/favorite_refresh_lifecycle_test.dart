import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/modules/tags/live_tag.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';

_Favorite? _mounted;

void _testWidgets(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    _mounted = null;
    try {
      await body(tester);
    } finally {
      // Widget invariants run before package:test addTearDown callbacks. Close
      // this active controller and its timers inside the Widget test body.
      final c = _mounted;
      if (c != null) {
        c.onDelete();
        await _drain(tester, c.source);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
      Get.reset();
    }
  });
}

LiveRoom _room([String title = 'cached']) =>
    LiveRoom(roomId: '100', platform: 'bilibili', title: title, liveStatus: LiveStatus.live);

class _Source extends LiveSite {
  final requests = <Completer<LiveRoom>>[];
  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) {
    final gate = Completer<LiveRoom>();
    requests.add(gate);
    return gate.future;
  }
}

class _Favorite extends FavoriteController {
  _Favorite(this.source, {super.now});
  final _Source source;
  int factories = 0;
  final finishes = <IndicatorResult>[];
  @override
  LiveSite createRoomRefreshSite(String platform) {
    factories++;
    return source;
  }

  @override
  void finishRefreshControllers(IndicatorResult result) {
    finishes.add(result);
  }

  Map<String, Object?> snapshot() => {
    'rows': list.map((r) => r.toJson()).toList(),
    'online': onlineRooms.map((r) => r.toJson()).toList(),
    'offline': offlineRooms.map((r) => r.toJson()).toList(),
    'replay': replayRooms.map((r) => r.toJson()).toList(),
    'tags': visibleTags.map((t) => t.id).toList(),
    'verifying': isVerifyingFavorites.value,
    'loading': loadding.value,
    'empty': pageEmpty.value,
    'pageLoading': pageLoadding.value,
    'error': pageError.value,
    'page': currentPage,
    'size': pageSize.value,
    'site': tabSiteIndex.value,
    'status': tabOnlineIndex.value,
    'selectedTag': selectedTagId.value,
    'finishes': finishes.toList(),
  };
}

Future<void> _drain(WidgetTester tester, _Source source) async {
  for (var i = 0; i < 8; i++) {
    for (final gate in source.requests.toList()) {
      if (!gate.isCompleted) gate.complete(_room('fresh'));
    }
    await tester.pump(Duration.zero);
  }
}

Future<_Favorite> _mount(WidgetTester tester, {bool desktop = true, DateTime Function()? now}) async {
  Get.testMode = true;
  Get.reset();
  await Hive.box('app_settings').clear();
  Get.put(SettingsService(), permanent: true);
  SettingsService.to.fav.favoriteRooms.v = [_room()];
  SettingsService.to.fav.hotAreasList.assignAll(['bilibili']);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(desktop ? 900 : 400, 640);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final source = _Source();
  _Favorite? owner;
  await tester.pumpWidget(
    GetMaterialApp(
      home: Builder(
        builder: (_) {
          if (owner == null) {
            owner = _Favorite(source, now: now);
            _mounted = owner;
            Get.put<FavoriteController>(owner!);
          }
          return const SizedBox();
        },
      ),
    ),
  );
  for (var frame = 0; frame < 10 && owner == null; frame++) {
    await tester.pump(Duration.zero);
  }
  expect(owner, isNotNull);
  final c = owner!;
  addTearDown(() async {
    c.onDelete();
    await _drain(tester, source);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    Get.reset();
  });
  await tester.pump(Duration.zero);
  expect(source.requests, hasLength(1));
  expect(c.isVerifyingFavorites.value, isTrue);
  expect(c.usesDesktopPagination, desktop);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await Hive.openBox('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
  });
  tearDownAll(Hive.close);

  for (final fails in [false, true]) {
    _testWidgets('favorite startup result after delete has no publication fails=$fails', (tester) async {
      final c = await _mount(tester);
      final startup = c.refreshPersistedRoomsOnStartup();
      c.onDelete();
      final before = c.snapshot();
      final persisted = SettingsService.to.fav.favoriteRooms.v.map((r) => r.toJson()).toList();
      if (fails) {
        c.source.requests.single.completeError(StateError('late'));
      } else {
        c.source.requests.single.complete(_room('late'));
      }
      await tester.pump(Duration.zero);
      await startup;
      expect(c.snapshot(), before);
      expect(SettingsService.to.fav.favoriteRooms.v.map((r) => r.toJson()), persisted);
      expect(c.activePageOperation, isNull);
    });
  }

  _testWidgets('favorite startup completion does not read released settings', (tester) async {
    final c = await _mount(tester);
    final startup = c.refreshPersistedRoomsOnStartup();
    Object? escaped;
    final observed = startup.catchError((Object error) {
      escaped = error;
    });
    c.onDelete();
    Get.reset();
    c.source.requests.single.complete(_room());
    await tester.pump(Duration.zero);
    await observed;
    expect(escaped, isNull);
  });

  _testWidgets('closed favorite refresh entrypoints are inert', (tester) async {
    final c = await _mount(tester);
    await _drain(tester, c.source);
    c.onDelete();
    final before = c.snapshot();
    final count = c.source.requests.length;
    c.currentPage = 3;
    final closedPage = c.currentPage;
    await c.refreshData();
    final startup = c.refreshPersistedRoomsOnStartup();
    await _drain(tester, c.source);
    await startup;
    expect(c.currentPage, closedPage);
    c.currentPage = before['page'] as int;
    expect(c.snapshot(), before);
    expect(c.source.requests, hasLength(count));
  });

  _testWidgets('closed favorite filter actions preserve the disposed snapshot', (tester) async {
    final c = await _mount(tester);
    await _drain(tester, c.source);
    c.onDelete();
    final before = c.snapshot();
    c.selectSiteIndex(1);
    c.selectStatusIndex(2);
    c.changeSelectedTag('late');
    c.syncRooms(roomSnapshot: [_room('changed')]);
    c.applyLocalFilter();
    expect(c.snapshot(), before);
  });

  _testWidgets('deleting the selected tag falls back to the complete favorites view', (tester) async {
    final c = await _mount(tester);
    await _drain(tester, c.source);
    final tag = LiveTag(id: 'outdoor', name: 'Outdoor');
    c.tagController.tags.assignAll([tag]);
    await c.tagController.setRoomTags(_room(), [tag.id]);
    c.changeSelectedTag(tag.id);
    await tester.pump(Duration.zero);
    expect(c.selectedTagId.value, tag.id);
    expect(c.list, hasLength(1));

    final deletion = c.tagController.deleteTag(0);
    // A two-key settings batch yields one event-loop turn before persistence.
    await tester.pump(Duration.zero);
    await deletion;
    await tester.pump(Duration.zero);

    expect(c.selectedTagId.value, TagManagementController.allTagKey);
    expect(c.list, hasLength(1));
  });

  _testWidgets('closed lifecycle and debounce events do not restart favorite work', (tester) async {
    final c = await _mount(tester);
    await _drain(tester, c.source);
    c.onDelete();
    Get.reset();
    c.debounceRefresh();
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(c.source.requests, hasLength(1));
  });

  _testWidgets('manual refresh supersedes a delayed resume refresh', (tester) async {
    var now = DateTime.utc(2026, 9, 11);
    final c = await _mount(tester, now: () => now);
    await _drain(tester, c.source);
    now = now.add(const Duration(seconds: 16));

    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    final manual = c.refreshData();
    await tester.pump(Duration.zero);
    expect(c.source.requests, hasLength(2));
    c.source.requests.last.complete(_room('manual'));
    await tester.pump(Duration.zero);
    await manual;

    await tester.pump(const Duration(milliseconds: 500));
    expect(c.source.requests, hasLength(2), reason: 'one user refresh must not be followed by a second network pass');
    expect(c.onlineRooms.single.title, 'manual');
  });

  _testWidgets('disabling resume refresh revokes an already scheduled pass', (tester) async {
    var now = DateTime.utc(2026, 9, 11);
    final c = await _mount(tester, now: () => now);
    await _drain(tester, c.source);
    now = now.add(const Duration(seconds: 16));

    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    c.refreshConfigController.refreshFavoriteOnResume.value = false;
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 500));

    expect(c.source.requests, hasLength(1));
  });

  _testWidgets('debounced favorite change supersedes a delayed resume refresh', (tester) async {
    var now = DateTime.utc(2026, 9, 11);
    final c = await _mount(tester, now: () => now);
    await _drain(tester, c.source);
    now = now.add(const Duration(seconds: 16));

    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    c.debounceRefresh();
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.source.requests, hasLength(2));
    c.source.requests.last.complete(_room('event'));
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 200));

    expect(c.source.requests, hasLength(2), reason: 'the event-owned pass already refreshed the complete snapshot');
    expect(c.onlineRooms.single.title, 'event');
  });

  _testWidgets('a completed full refresh revokes a resume event received while it was active', (tester) async {
    var now = DateTime.utc(2026, 9, 11);
    final c = await _mount(tester, now: () => now);
    await _drain(tester, c.source);
    now = now.add(const Duration(seconds: 16));

    c.debounceRefresh();
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.source.requests, hasLength(2));
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    c.source.requests.last.complete(_room('current-full'));
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 500));

    expect(c.source.requests, hasLength(2), reason: 'the just-completed full snapshot satisfies the resume event');
    expect(c.onlineRooms.single.title, 'current-full');
  });

  _testWidgets('favorite startup owns the page operation and preserves preview until completion', (tester) async {
    final c = await _mount(tester);
    final active = c.activePageOperation;
    expect(c.onlineRooms.single.liveStatus, LiveStatus.unknown);
    final startup = c.refreshPersistedRoomsOnStartup();
    await _drain(tester, c.source);
    await startup;
    expect(active, isNotNull);
    expect(c.activePageOperation, isNull);
    expect(c.isVerifyingFavorites.value, isFalse);
    expect(c.onlineRooms.single.title, 'fresh');
  });

  _testWidgets('favorite page size waits for startup and applies the latest selection', (tester) async {
    final c = await _mount(tester);
    final oldSize = c.pageSize.value;
    c.setPageSize(4);
    c.setPageSize(3);
    final during = c.pageSize.value;
    await _drain(tester, c.source);
    expect(during, oldSize);
    expect(c.pageSize.value, 3);
    expect(c.list.single.title, 'fresh');
  });

  for (final startup in [false, true]) {
    for (final desktop in [false, true]) {
      _testWidgets('favorite layout awaits refresh startup=$startup desktop=$desktop', (tester) async {
        final c = await _mount(tester, desktop: desktop);
        if (!startup) {
          await _drain(tester, c.source);
          unawaited(c.refreshData());
          await tester.pump(Duration.zero);
        }
        final count = c.source.requests.length;
        final size = c.pageSize.value;
        c.checkAndNotifyLayoutChange(!desktop);
        await tester.pump(const Duration(milliseconds: 200));
        final duringMode = c.usesDesktopPagination;
        final duringSize = c.pageSize.value;
        await _drain(tester, c.source);
        expect(duringMode, desktop);
        expect(duringSize, size);
        expect(c.usesDesktopPagination, !desktop);
        expect(c.source.requests, hasLength(count + 1));
      });
    }
  }

  _testWidgets('favorite queued refresh remains owned after the preceding refresh completes', (tester) async {
    final c = await _mount(tester);
    await _drain(tester, c.source);
    final first = c.refreshData();
    final second = c.refreshData();
    await tester.pump(Duration.zero);
    final initialCount = c.source.requests.length;
    c.source.requests.last.complete(_room('first'));
    await tester.pump(Duration.zero);
    await first;
    final queuedOwned = c.activePageOperation != null;
    final nextCount = c.source.requests.length;
    await _drain(tester, c.source);
    await second;
    expect(initialCount, 2);
    expect(nextCount, 3);
    expect(queuedOwned, isTrue);
    expect(c.activePageOperation, isNull);
  });

  _testWidgets('favorite pending snapshot debounce is disposed before settings are released', (tester) async {
    final c = await _mount(tester);
    await _drain(tester, c.source);
    SettingsService.to.fav.favoriteRooms.v = [_room('edited')];
    await tester.pump(Duration.zero);
    c.onDelete();
    final before = c.snapshot();
    Get.reset();
    await tester.pump(const Duration(milliseconds: 1100));
    expect(c.snapshot(), before);
    expect(tester.takeException(), isNull);
  });

  _testWidgets('favorite current snapshot debounce still publishes local edits', (tester) async {
    final c = await _mount(tester);
    await _drain(tester, c.source);
    SettingsService.to.fav.favoriteRooms.v = [_room('edited')];
    await tester.pump(Duration.zero);
    expect(c.list.single.title, 'fresh');
    await tester.pump(const Duration(milliseconds: 1100));
    expect(c.list.single.title, 'edited');
    expect(c.source.requests, hasLength(1));
  });

  _testWidgets('favorite failed startup becomes unknown and explicit refresh can recover', (tester) async {
    final c = await _mount(tester);
    c.source.requests.single.completeError(StateError('unavailable'));
    await tester.pump(Duration.zero);
    expect(c.isVerifyingFavorites.value, isFalse);
    expect(SettingsService.to.fav.favoriteRooms.v.single.liveStatus, LiveStatus.unknown);
    expect(c.offlineRooms, hasLength(1));
    final refresh = c.refreshData();
    await _drain(tester, c.source);
    await refresh;
    expect(c.onlineRooms.single.title, 'fresh');
    expect(c.loadding.value, isFalse);
  });

  _testWidgets('favorite startup merge retains current tags and current selection', (tester) async {
    final c = await _mount(tester);
    SettingsService.to.fav.favoriteRooms.v = [
      _room().copyWith(tagIds: ['keep']),
    ];
    c.selectStatusIndex(2);
    await _drain(tester, c.source);
    expect(SettingsService.to.fav.favoriteRooms.v.single.tagIds, ['keep']);
    expect(c.tabOnlineIndex.value, 2);
    expect(c.list, isEmpty);
    c.selectStatusIndex(0);
    expect(c.list.single.title, 'fresh');
  });

  _testWidgets('favorite startup merge never restores a removed room', (tester) async {
    final c = await _mount(tester);
    SettingsService.to.fav.favoriteRooms.v = [];
    await _drain(tester, c.source);
    expect(SettingsService.to.fav.favoriteRooms.v, isEmpty);
    expect(c.list, isEmpty);
    expect(c.onlineRooms, isEmpty);
    expect(c.isVerifyingFavorites.value, isFalse);
  });

  _testWidgets('favorite close discards queued work and pending page size', (tester) async {
    final c = await _mount(tester);
    await _drain(tester, c.source);
    final first = c.refreshData();
    final second = c.refreshData();
    c.setPageSize(3);
    await tester.pump(Duration.zero);
    c.onDelete();
    final before = c.snapshot();
    await _drain(tester, c.source);
    await Future.wait([first, second]);
    expect(c.snapshot(), before);
    expect(c.source.requests, hasLength(2));
    expect(c.activePageOperation, isNull);
  });
}
