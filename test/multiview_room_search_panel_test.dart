import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/modules/multiview/multiview_room_search_controller.dart';
import 'package:pure_live/modules/multiview/widgets/multiview_room_search_panel.dart';

/// Deterministic platform adapter: search returns canned rooms and the direct
/// lookup path is observable, so nothing in these tests touches the network.
class _FakeLiveSite extends LiveSite {
  _FakeLiveSite({List<LiveRoom> rooms = const <LiveRoom>[], this.detail, this.fail = false}) : _rooms = rooms;

  final List<LiveRoom> _rooms;
  final LiveRoom? detail;
  final bool fail;

  String? lastKeyword;
  String? lastRoomId;

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    if (fail) throw StateError('simulated platform outage');
    lastKeyword = keyword;
    return _rooms;
  }

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) async {
    if (fail) throw StateError('simulated detail outage');
    lastRoomId = roomId;
    return detail ?? LiveRoom(roomId: roomId, platform: platform, nick: 'direct-$roomId');
  }
}

Site _site(String id, _FakeLiveSite liveSite) => Site(id: id, name: id, logo: '', liveSite: liveSite);

int _byNick(LiveRoom left, LiveRoom right) => (left.nick ?? '').compareTo(right.nick ?? '');

Widget _harness(Widget child) {
  return EasyLocalization(
    supportedLocales: const <Locale>[Locale('zh')],
    path: 'assets/translations',
    fallbackLocale: const Locale('zh'),
    assetLoader: const _DiskAssetLoader(),
    // AppTextStyles reads Get.theme, so the app shell must be GetMaterialApp.
    child: Builder(
      builder: (context) => GetMaterialApp(
        locale: context.locale,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        theme: ThemeData.dark(),
        home: Scaffold(body: child),
      ),
    ),
  );
}

class _TestSettingsService extends SettingsService {
  _TestSettingsService(this._font);

  final FontSettingsController _font;

  @override
  FontSettingsController get font => _font;

  @override
  // Panel only reads SettingsService.to.font; skip the production registrations
  // so nothing needs AppPathManager or Hive boxes in this test.
  // ignore: must_call_super
  void onInit() {}
}

class _DiskAssetLoader extends AssetLoader {
  const _DiskAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final file = File('assets/translations/${locale.languageCode}.json');
    return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

/// Bounded settle: the loading spinner is an indefinite animation, so an
/// unbounded pumpAndSettle would hang the whole file.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> _pumpPanel(WidgetTester tester, Widget panel) async {
  Get.testMode = true;
  Get.reset();
  // Registered here rather than in setUp: GetMaterialApp rebuilds the
  // dependency graph on init and a service put beforehand is not reachable.
  Get.put<SettingsService>(_TestSettingsService(FontSettingsController()));
  await tester.pumpWidget(_harness(panel));
  // EasyLocalization renders nothing until its async asset load resolves, and
  // pumpAndSettle alone does not wait on that future.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await _settle(tester);
}

/// Runs a case and then advances past framework-owned 3s timers (GetX toast /
/// status-view defaults). Neither the panel nor the search controller starts a
/// `Timer`, so without this the binding reports a leaked timer at teardown.
void testPanel(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pump(const Duration(seconds: 4));
    await _settle(tester);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-multiview-search-test-');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
    Hive.init(hiveDirectory.path);
    await HivePrefUtil.init();
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
    Get.put<SettingsService>(_TestSettingsService(FontSettingsController()));
  });

  tearDown(Get.reset);

  tearDownAll(() async {
    await Hive.close();
    if (hiveDirectory.existsSync()) await hiveDirectory.delete(recursive: true);
  });

  LiveRoom room(String platform, String roomId, String nick) => LiveRoom(
    roomId: roomId,
    platform: platform,
    nick: nick,
    title: 'title-$roomId',
    liveStatus: LiveStatus.live,
    status: true,
  );

  testPanel('keyword search lists results and tapping one reports the picked room', (tester) async {
    final picked = <LiveRoom>[];
    final site = _FakeLiveSite(rooms: <LiveRoom>[room(Sites.huyaSite, '111', 'huya-anchor')]);
    final controller = MultiviewRoomSearchController(
      sites: <Site>[_site(Sites.huyaSite, site)],
      audienceCompare: _byNick,
    );

    await _pumpPanel(tester, MultiviewRoomSearchPanel(cellIndex: 2, onPicked: picked.add, search: controller));

    await tester.enterText(find.byType(TextField).first, 'anchor');
    await tester.tap(find.text('搜索'));
    await _settle(tester);

    expect(site.lastKeyword, 'anchor');
    expect(find.text('huya-anchor'), findsOneWidget);

    await tester.tap(find.text('huya-anchor'));
    await _settle(tester);

    expect(picked, hasLength(1));
    expect(picked.single.roomId, '111');
    expect(tester.takeException(), isNull);
  });

  testPanel('results are deduplicated per platform and room id', (tester) async {
    final shared = room(Sites.douyuSite, '777', 'douyu-anchor');
    final controller = MultiviewRoomSearchController(
      sites: <Site>[
        _site(Sites.douyuSite, _FakeLiveSite(rooms: <LiveRoom>[shared])),
        _site(Sites.bilibiliSite, _FakeLiveSite(rooms: <LiveRoom>[shared])),
      ],
      audienceCompare: _byNick,
    );

    await _pumpPanel(tester, MultiviewRoomSearchPanel(cellIndex: 0, onPicked: (_) {}, search: controller));
    await tester.enterText(find.byType(TextField).first, 'x');
    await tester.tap(find.text('搜索'));
    await _settle(tester);

    // Same platform + roomId from two adapters collapses to one row.
    expect(find.text('douyu-anchor'), findsOneWidget);
  });

  testPanel('a failing platform is surfaced without hiding the good results', (tester) async {
    final controller = MultiviewRoomSearchController(
      sites: <Site>[
        _site(Sites.huyaSite, _FakeLiveSite(fail: true)),
        _site(Sites.douyuSite, _FakeLiveSite(rooms: <LiveRoom>[room(Sites.douyuSite, '42', 'still-shown')])),
      ],
      audienceCompare: _byNick,
    );

    await _pumpPanel(tester, MultiviewRoomSearchPanel(cellIndex: 1, onPicked: (_) {}, search: controller));
    await tester.enterText(find.byType(TextField).first, 'q');
    await tester.tap(find.text('搜索'));
    await _settle(tester);

    expect(find.text('still-shown'), findsOneWidget);
    expect(find.text('部分平台搜索失败'), findsOneWidget);
  });

  testPanel('a share link is resolved through its own platform adapter', (tester) async {
    final picked = <LiveRoom>[];
    final huya = _FakeLiveSite(detail: room(Sites.huyaSite, '9527', 'link-anchor'));
    final controller = MultiviewRoomSearchController(
      sites: <Site>[_site(Sites.huyaSite, huya)],
      audienceCompare: _byNick,
    );

    await _pumpPanel(tester, MultiviewRoomSearchPanel(cellIndex: 0, onPicked: picked.add, search: controller));
    await tester.enterText(find.byType(TextField).last, 'https://www.huya.com/9527');
    await tester.tap(find.byIcon(Remix.add_line));
    await _settle(tester);

    expect(huya.lastRoomId, isNotNull);
    expect(picked, hasLength(1));
    expect(picked.single.nick, 'link-anchor');
  });

  testPanel('an unsupported platform reports instead of picking', (tester) async {
    final picked = <LiveRoom>[];
    final controller = MultiviewRoomSearchController(
      sites: <Site>[_site(Sites.huyaSite, _FakeLiveSite())],
      audienceCompare: _byNick,
    );

    await _pumpPanel(tester, MultiviewRoomSearchPanel(cellIndex: 0, onPicked: picked.add, search: controller));
    // `nosuchsite/123` parses to a platform this app has no adapter for.
    await tester.enterText(find.byType(TextField).last, 'nosuchsite/123');
    await tester.tap(find.byIcon(Remix.add_line));
    await _settle(tester);

    expect(picked, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testPanel('the panel is non-modal: taps outside its rectangle reach what is behind it', (tester) async {
    var behindTaps = 0;
    final controller = MultiviewRoomSearchController(sites: <Site>[], audienceCompare: _byNick);

    await _pumpPanel(
      tester,
      Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey('cell-behind'),
              behavior: HitTestBehavior.opaque,
              onTap: () => behindTaps++,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: 320,
            top: 20,
            child: SizedBox(
              width: 300,
              height: 380,
              child: MultiviewRoomSearchPanel(cellIndex: 0, onPicked: (_) {}, search: controller),
            ),
          ),
        ],
      ),
    );

    await tester.tapAt(const Offset(40, 300));
    expect(behindTaps, 1, reason: 'tapping a cell area must still work while the panel is open');

    await tester.tapAt(const Offset(450, 30));
    expect(behindTaps, 1, reason: 'the panel rectangle must absorb its own taps');
  });

  testPanel('dragging the header reports a move delta', (tester) async {
    final moves = <Offset>[];
    final controller = MultiviewRoomSearchController(sites: <Site>[], audienceCompare: _byNick);

    await _pumpPanel(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 320,
          height: 380,
          child: MultiviewRoomSearchPanel(cellIndex: 0, onPicked: (_) {}, search: controller, onDragUpdate: moves.add),
        ),
      ),
    );

    // The whole header row is the drag surface; the move-handle icon is the
    // clearest child of it to grab.
    await tester.drag(find.byIcon(Remix.drag_move_line), const Offset(80, 40));
    await _settle(tester);

    expect(moves, isNotEmpty);
    expect(moves.fold<Offset>(Offset.zero, (a, b) => a + b).dx, greaterThan(0));
  });
}
