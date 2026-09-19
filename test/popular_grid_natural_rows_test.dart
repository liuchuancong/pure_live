import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/base/base_page_scroll_bone.dart';
import 'package:pure_live/common/base/live_directory_controller.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/services/settings/room_card_settings_controller.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/widgets/room_card.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/popular/popular_grid_view.dart';

import 'support/weibo_application_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
  });
  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
    Get.put(SettingsService(), permanent: true);
  });
  tearDown(Get.reset);
  tearDownAll(Hive.close);

  for (final width in [320.0, 680.0, 960.0, 1000.0, 1320.0]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('popular rows retain lazy cards, final partial row and columns at $width / scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        });
        final fixture = WeiboApplicationFixture();
        final c = LiveDirectoryController(directory: fixture.adapter);
        c.list.assignAll(
          List.generate(
            101,
            (i) => LiveRoom(
              platform: 'weibo',
              roomId: 'fixture-$i',
              title: 'Title $i',
              nick: 'Owner $i',
              liveStatus: LiveStatus.unknown,
            ),
          ),
        );
        c.totalCount.value = 101;
        Get.put<BasePageScrollAndStateBone<LiveRoom>>(c, tag: 'weibo');
        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(body: PopularGridView('weibo')),
          ),
        );
        await tester.pumpAndSettle();
        final columns = width > 1280 ? 5 : (width > 960 ? 4 : (width > 640 ? 3 : 2));
        final first = find.byKey(const ValueKey('weibo:fixture-0'));
        final second = find.byKey(const ValueKey('weibo:fixture-1'));
        final nextRow = find.byKey(ValueKey('weibo:fixture-$columns'));
        expect(tester.getTopLeft(second).dy, tester.getTopLeft(first).dy);
        expect(tester.getTopLeft(second).dx, greaterThan(tester.getTopLeft(first).dx));
        expect(tester.getTopLeft(nextRow).dy, greaterThanOrEqualTo(tester.getBottomLeft(first).dy));
        expect(find.byType(RoomCard).evaluate().length, lessThan(101));
        final list = find.descendant(of: find.byType(PopularGridView), matching: find.byType(CustomScrollView));
        expect(tester.widget<CustomScrollView>(list).semanticChildCount, 101);
        final last = find.byKey(const ValueKey('weibo:fixture-100'));
        await tester.scrollUntilVisible(
          last,
          600,
          scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
          maxScrolls: 80,
        );
        await tester.pumpAndSettle();
        expect(last.hitTestable(), findsOneWidget);
        expect(tester.widget<RoomCard>(last).room.roomId, 'fixture-100');
        expect(find.byType(RoomCard).evaluate().length, lessThan(101));
        expect(fixture.requests, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('compact preset restores short identity rows instead of cover cards', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    SettingsService.to.roomCard.applyPreset(RoomCardViewport.desktop, RoomCardPreset.compact);
    final fixture = WeiboApplicationFixture();
    final controller = LiveDirectoryController(directory: fixture.adapter);
    controller.list.assignAll([
      LiveRoom(
        platform: 'weibo',
        roomId: 'compact-fixture',
        title: 'Compact title',
        nick: 'Compact owner',
        liveStatus: LiveStatus.live,
      ),
    ]);
    controller.totalCount.value = 1;
    Get.put<BasePageScrollAndStateBone<LiveRoom>>(controller, tag: 'weibo');

    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: PopularGridView('weibo'))));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('weibo:compact-fixture'));
    expect(find.descendant(of: card, matching: find.byKey(const ValueKey('room-card-compact-layout'))), findsOneWidget);
    expect(find.descendant(of: card, matching: find.byKey(const ValueKey('room-card-cover-layout'))), findsNothing);
    expect(tester.getSize(card).height, lessThan(100));
    expect(find.descendant(of: card, matching: find.byKey(const ValueKey('room-card-avatar'))), findsOneWidget);
    expect(find.descendant(of: card, matching: find.byKey(const ValueKey('room-card-anchor-name'))), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
