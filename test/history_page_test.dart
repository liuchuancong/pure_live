import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings/history_controller.dart';
import 'package:pure_live/common/services/settings/refresh_config_controller.dart';
import 'package:pure_live/common/services/settings/room_card_settings_controller.dart';
import 'package:pure_live/common/services/settings/theme_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/history/history_page.dart';
import 'package:pure_live/plugins/global.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Map<String, dynamic> translations;
  late Map<String, dynamic> english;
  late HistoryController history;
  late List<(LiveRoom, Completer<LiveRoom>)> requests;
  final originalHeader = EasyRefresh.defaultHeaderBuilder;
  final originalFooter = EasyRefresh.defaultFooterBuilder;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('history-page-');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    initRefresh();
    Hive.init(directory.path);
    await HivePrefUtil.init();
    translations = jsonDecode(await File('assets/translations/zh.json').readAsString()) as Map<String, dynamic>;
    english = jsonDecode(await File('assets/translations/en.json').readAsString()) as Map<String, dynamic>;
  });
  setUp(() {
    Get.testMode = true;
    Get.put<SettingsService>(_Settings());
    Get.put(ThemeSettingsController());
    Get.put(RoomCardSettingsController());
    Get.put(RefreshConfigController()).maxConcurrentRefresh.value = 4;
    history = Get.put(HistoryController());
    history.setHistoryLimit(50);
    history.historyRooms.value = [room('a', 100), room('b', 90)];
    requests = [];
  });
  tearDown(() {
    Get.deleteAll(force: true);
    Get.reset();
  });
  tearDownAll(() async {
    EasyRefresh.defaultHeaderBuilder = originalHeader;
    EasyRefresh.defaultFooterBuilder = originalFooter;
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(900, 600),
    double scale = 1,
    String locale = 'zh',
  }) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: [Locale(locale)],
        startLocale: Locale(locale),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: _Loader(locale == 'en' ? english : translations),
        child: Builder(
          builder: (context) => GetMaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: HistoryPage(
              loadRoom: (room) {
                final pending = Completer<LiveRoom>();
                requests.add((room, pending));
                return pending.future;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<dynamic> refresh(WidgetTester tester) =>
      Future<dynamic>.sync(tester.widget<EasyRefresh>(find.byType(EasyRefresh)).onRefresh!);

  Future<void> complete(WidgetTester tester) async {
    for (final (old, pending) in requests.toList()) {
      if (!pending.isCompleted) pending.complete(old.copyWith(title: 'refreshed-${old.roomId}'));
    }
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    final error = tester.takeException();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(error, isNull);
  }

  testWidgets('refresh never resurrects cleared history', (tester) async {
    await open(tester);
    final pending = refresh(tester);
    await tester.tap(find.byTooltip(translations['clear_history'] as String));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, translations['clear'] as String));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(history.historyRooms.value, isEmpty);
    await complete(tester);
    await pending;
    expect(history.historyRooms.value, isEmpty);
    await finish(tester);
  });

  testWidgets('refresh preserves deletion and updates surviving entries', (tester) async {
    await open(tester);
    final pending = refresh(tester);
    history.removeRoomFromHistory(history.historyRooms.value.first);
    await complete(tester);
    await pending;
    expect(history.historyRooms.value.map((r) => r.roomId), ['b']);
    expect(history.historyRooms.value.single.title, 'refreshed-b');
    await finish(tester);
  });

  testWidgets('refresh preserves a new watch and the latest ordering and timestamp', (tester) async {
    await open(tester);
    final pending = refresh(tester);
    history.addRoomToHistory(room('b', 0).copyWith(title: 'new-watch'));
    final watchedAt = history.historyRooms.value.first.lastWatchedAt;
    await complete(tester);
    await pending;
    expect(history.historyRooms.value.map((r) => r.roomId), ['b', 'a']);
    expect(history.historyRooms.value.first.title, 'new-watch');
    expect(history.historyRooms.value.first.lastWatchedAt, watchedAt);
    expect(history.historyRooms.value.last.title, 'refreshed-a');
    await finish(tester);
  });

  testWidgets('refresh obeys a history limit lowered during the request', (tester) async {
    await open(tester);
    final pending = refresh(tester);
    history.setHistoryLimit(1);
    await complete(tester);
    await pending;
    expect(history.historyRooms.value.map((r) => r.roomId), ['a']);
    await finish(tester);
  });

  testWidgets('refresh does not overwrite a restored list', (tester) async {
    await open(tester);
    final pending = refresh(tester);
    history.fromJson({
      'historyLimit': 50,
      'historyRooms': [room('a', 999).copyWith(title: 'imported').toJson()],
    });
    await complete(tester);
    await pending;
    expect(history.historyRooms.value, hasLength(1));
    expect(history.historyRooms.value.single.title, 'imported');
    expect(history.historyRooms.value.single.lastWatchedAt, 999);
    await finish(tester);
  });

  testWidgets('overlapping refresh callbacks share one request batch', (tester) async {
    await open(tester);
    final first = refresh(tester);
    final second = refresh(tester);
    final count = requests.length;
    await complete(tester);
    await Future.wait([first, second]);
    expect(count, 2);
    await finish(tester);
  });

  for (final locale in ['zh', 'en']) {
    testWidgets('$locale history limits use count labels rather than dimensions', (tester) async {
      final labels = locale == 'en' ? english : translations;
      await open(tester, locale: locale, size: const Size(320, 480), scale: 2);
      await tester.tap(find.byTooltip(labels['history_limit'] as String));
      await tester.pumpAndSettle();
      expect(find.text(locale == 'en' ? 'Preset Limits' : '预设数量'), findsOneWidget);
      expect(find.text(locale == 'en' ? 'Custom Limit' : '自定义数量'), findsOneWidget);
      expect(find.text(labels['custom_input'] as String), findsNothing);
      expect(find.text(labels['current_options'] as String), findsNothing);
      final cancel = find.widgetWithText(TextButton, labels['cancel'] as String);
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(history.historyLimit.value, 50);
      expect(history.historyRooms.value.map((room) => room.roomId), ['a', 'b']);
      await finish(tester);
    });
  }

  testWidgets('history limit input remains alive through dialog dismissal', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip(translations['history_limit'] as String));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text(translations['cancel'] as String));
    await tester.pumpAndSettle();
    expect(history.historyLimit.value, 50);
    await finish(tester);
  });

  testWidgets('history limit reports invalid custom input without changing the draft', (tester) async {
    await open(tester, locale: 'en');
    await tester.tap(find.byTooltip(english['history_limit'] as String));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'not-a-count');
    final apply = find.widgetWithText(ElevatedButton, english['apply'] as String);
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();

    expect(find.text('Enter a whole number of 0 or greater.'), findsOneWidget);
    expect(find.text('Current Value: 50'), findsOneWidget);
    expect(history.historyLimit.value, 50);

    await tester.enterText(find.byType(TextField), '75');
    await tester.pump();
    expect(find.text('Enter a whole number of 0 or greater.'), findsNothing);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(find.text('Current Value: 75'), findsOneWidget);
    expect(history.historyLimit.value, 50);
    await tester.tap(find.text(english['confirm'] as String));
    await tester.pumpAndSettle();
    expect(history.historyLimit.value, 75);
    await finish(tester);
  });

  testWidgets('history limit actions remain reachable at narrow three-times text', (tester) async {
    await open(tester, locale: 'en', size: const Size(320, 480), scale: 3);
    await tester.tap(find.byTooltip(english['history_limit'] as String));
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    await tester.ensureVisible(field);
    await tester.enterText(field, '80');
    final apply = find.widgetWithText(ElevatedButton, english['apply'] as String);
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(find.text('Current Value: 80'), findsOneWidget);
    final confirm = find.widgetWithText(TextButton, english['confirm'] as String);
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(history.historyLimit.value, 80);
    await finish(tester);
  });

  testWidgets('successful refresh keeps watch timestamps and list order', (tester) async {
    await open(tester);
    final pending = refresh(tester);
    await complete(tester);
    await pending;
    expect(history.historyRooms.value.map((r) => r.title), ['refreshed-a', 'refreshed-b']);
    expect(history.historyRooms.value.map((r) => r.lastWatchedAt), [100, 90]);
    await finish(tester);
  });

  testWidgets('partial failures retain old entries and release the batch for retry', (tester) async {
    await open(tester);
    final pending = refresh(tester);
    requests.first.$2.completeError(StateError('fixture detail failure'));
    await complete(tester);
    await pending;
    expect(history.historyRooms.value.map((r) => r.title), ['old-a', 'refreshed-b']);
    requests.clear();
    final retry = refresh(tester);
    expect(requests, hasLength(2));
    await complete(tester);
    await retry;
    expect(history.historyRooms.value.map((r) => r.title), ['refreshed-a', 'refreshed-b']);
    await finish(tester);
  });

  testWidgets('timeout retains history and a late response does not overwrite it', (tester) async {
    await open(tester);
    final pending = refresh(tester);
    await tester.pump(const Duration(seconds: 13));
    await pending;
    expect(history.historyRooms.value.map((r) => r.title), ['old-a', 'old-b']);
    await complete(tester);
    expect(history.historyRooms.value.map((r) => r.title), ['old-a', 'old-b']);
    await finish(tester);
  });

  testWidgets('disposing the page stops queued work and discards pending results', (tester) async {
    Get.find<RefreshConfigController>().maxConcurrentRefresh.value = 1;
    await open(tester);
    final pending = refresh(tester);
    expect(requests, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    await complete(tester);
    await pending;
    expect(requests, hasLength(1));
    expect(history.historyRooms.value.map((r) => r.title), ['old-a', 'old-b']);
    await finish(tester);
  });

  testWidgets('new entries on another platform survive the refresh', (tester) async {
    await open(tester);
    final pending = refresh(tester);
    history.addRoomToHistory(room('a', 0).copyWith(platform: 'huya'));
    await complete(tester);
    await pending;
    expect(history.historyRooms.value.map((r) => r.platform), ['huya', 'bilibili', 'bilibili']);
    expect(history.historyRooms.value.map((r) => r.title), ['old-a', 'refreshed-a', 'refreshed-b']);
    await finish(tester);
  });

  testWidgets('clear cancellation leaves history unchanged', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip(translations['clear_history'] as String));
    await tester.pumpAndSettle();
    await tester.tap(find.text(translations['cancel'] as String));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(history.historyRooms.value, hasLength(2));
    await finish(tester);
  });

  for (final locale in ['en', 'zh']) {
    testWidgets('$locale clear confirmation names its snapshot and coalesces repeated actions', (tester) async {
      final labels = locale == 'en' ? english : translations;
      await open(tester, locale: locale, size: const Size(320, 480), scale: 3);
      final clearAction = find.ancestor(
        of: find.byTooltip(labels['clear_history'] as String),
        matching: find.byType(IconButton),
      );
      final onPressed = tester.widget<IconButton>(clearAction).onPressed!;

      onPressed();
      onPressed();
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text(
          locale == 'en' ? 'Clear all 2 history entries? This action cannot be undone.' : '确定清空这 2 条历史记录吗？此操作不可撤销。',
        ),
        findsOneWidget,
      );
      final cancel = find.widgetWithText(TextButton, labels['cancel'] as String).hitTestable();
      final clear = find.widgetWithText(FilledButton, labels['clear'] as String).hitTestable();
      expect(cancel, findsOneWidget);
      expect(clear, findsOneWidget);
      expect(tester.getSize(cancel).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(clear).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(clear).height, greaterThanOrEqualTo(48));
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(history.historyRooms.value, hasLength(2));

      onPressed();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, labels['cancel'] as String));
      await tester.pumpAndSettle();
      await finish(tester);
    });
  }

  testWidgets('clear removes the confirmed snapshot but preserves watches added while deciding', (tester) async {
    await open(tester, locale: 'en');
    await tester.tap(find.byTooltip(english['clear_history'] as String));
    await tester.pumpAndSettle();

    history.addRoomToHistory(room('a', 0).copyWith(title: 'rewatched-a'));
    history.addRoomToHistory(room('c', 0).copyWith(title: 'new-c'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, english['clear'] as String));
    await tester.pumpAndSettle();

    expect(history.historyRooms.value.map((room) => room.roomId), ['c', 'a']);
    expect(history.historyRooms.value.map((room) => room.title), ['new-c', 'rewatched-a']);
    await finish(tester);
  });

  for (final (size, scale) in [(const Size(320, 480), 2.0), (const Size(900, 600), 1.0)]) {
    testWidgets('custom limit apply and confirm work at $size scale $scale', (tester) async {
      await open(tester, size: size, scale: scale);
      await tester.tap(find.byTooltip(translations['history_limit'] as String));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1');
      final apply = find.widgetWithText(ElevatedButton, translations['apply'] as String);
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(history.historyLimit.value, 50);
      await tester.tap(find.text(translations['confirm'] as String));
      await tester.pumpAndSettle();
      expect(history.historyLimit.value, 1);
      expect(history.historyRooms.value.map((r) => r.roomId), ['a']);
      await finish(tester);
    });
  }

  testWidgets('unlimited selection cancels or confirms without an intermediate save', (tester) async {
    await open(tester);
    for (final confirm in [false, true]) {
      await tester.tap(find.byTooltip(translations['history_limit'] as String));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, translations['history_unlimited'] as String));
      await tester.pumpAndSettle();
      expect(history.historyLimit.value, 50);
      await tester.tap(find.text(translations[confirm ? 'confirm' : 'cancel'] as String));
      await tester.pumpAndSettle();
      expect(history.historyLimit.value, confirm ? 0 : 50);
    }
    await finish(tester);
  });

  testWidgets('empty history refresh performs no detail requests', (tester) async {
    history.clearHistory();
    await open(tester);
    await refresh(tester);
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    expect(find.text(translations['empty_history'] as String), findsOneWidget);
    await finish(tester);
  });
}

LiveRoom room(String id, int watchedAt) => LiveRoom(
  roomId: id,
  platform: 'bilibili',
  title: 'old-$id',
  nick: 'fixture',
  lastWatchedAt: watchedAt,
  liveStatus: LiveStatus.offline,
);

class _Settings extends SettingsService {
  final _font = FontSettingsController();
  @override
  FontSettingsController get font => _font;
  @override
  // Avoid unrelated application startup IO in page tests.
  // ignore: must_call_super
  void onInit() {}
}

class _Loader extends AssetLoader {
  _Loader(this.data);
  final Map<String, dynamic> data;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => data;
}
