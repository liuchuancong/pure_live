import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_list_view.dart';
import 'package:pure_live/modules/live_play/widgets/local_interaction/local_interaction_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Local extends Fake implements LocalInteractionController {
  @override
  final enabled = false.obs;
}

class _Room extends GetxController implements LivePlayController {
  @override
  final danmakuMessages = <LiveMessage>[].obs;
  @override
  final danmakuPresentationRevision = 0.obs;
  @override
  final localInteractionController = _Local();
  final removals = StreamController<bool Function(LiveMessage)>.broadcast(sync: true);
  @override
  Stream<bool Function(LiveMessage)> get danmakuRemovals => removals.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings extends SettingsService {
  @override
  final font = FontSettingsController();
  @override
  // This isolated list has no player, account or network services.
  // ignore: must_call_super
  void onInit() {}
}

class _Loader extends AssetLoader {
  _Loader(this.data);
  final Map<String, dynamic> data;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => data;
}

LiveMessage _message(String text) =>
    LiveMessage(type: LiveMessageType.chat, userName: 'viewer', message: text, color: LiveMessageColor.white);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Map<String, Map<String, dynamic>> labels;
  late _Room room;
  late GlobalKey<DanmakuListViewState> key;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('danmaku-resume-');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    Hive.init(directory.path);
    await HivePrefUtil.init();
    labels = {
      for (final locale in ['zh', 'en'])
        locale: jsonDecode(await File('assets/translations/$locale.json').readAsString()) as Map<String, dynamic>,
    };
  });

  setUp(() {
    Get.testMode = true;
    Get.put<SettingsService>(_Settings());
    Get.put(GlobalPlayerState());
    room = Get.put<LivePlayController>(_Room()) as _Room;
    room.danmakuMessages.assignAll(List.generate(60, (i) => _message('old-$i')));
    key = GlobalKey<DanmakuListViewState>();
  });

  tearDown(() async {
    await room.removals.close();
    Get.reset();
    Get.testMode = false;
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> open(WidgetTester tester, {required String locale, required double width, required double scale}) async {
    tester.view.physicalSize = Size(width, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: [Locale(locale)],
        startLocale: Locale(locale),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: _Loader(labels[locale]!),
        child: Builder(
          builder: (context) => GetMaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: DanmakuListView(
                key: key,
                room: LiveRoom(roomId: 'fixture', platform: 'test'),
                controller: room,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<List<LiveMessage>> freezeAndReceive(WidgetTester tester, String locale) async {
    await tester.drag(find.byKey(const ValueKey('danmaku-message-list')), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(key.currentState!.userScrolling, isTrue);
    final visible = tester.widgetList<DanmakuItem>(find.byType(DanmakuItem)).first.danmaku;
    final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    final frozenOffset = position.pixels;
    final incoming = List.generate(137, (i) => _message('new-$i'));
    room.danmakuMessages.assignAll([...room.danmakuMessages, ...incoming]);
    await tester.pump(const Duration(milliseconds: 100));
    expect(position.pixels, frozenOffset, reason: 'Arrivals must not move the paused viewport.');
    expect(
      find.byKey(ObjectKey(visible)),
      findsOneWidget,
      reason: 'New arrivals must not replace the paused snapshot.',
    );
    expect(find.byKey(ObjectKey(incoming.last)), findsNothing);
    expect(find.text((labels[locale]!['danmaku_new_messages'] as String).replaceAll('{count}', '137')), findsOneWidget);
    return incoming;
  }

  for (final profile in [
    (locale: 'en', width: 320.0, scale: 1.0),
    (locale: 'en', width: 320.0, scale: 2.0),
    (locale: 'zh', width: 320.0, scale: 2.0),
    (locale: 'en', width: 900.0, scale: 2.0),
  ]) {
    testWidgets('${profile.locale} resume action stays inside ${profile.width} at text scale ${profile.scale}', (
      tester,
    ) async {
      await open(tester, locale: profile.locale, width: profile.width, scale: profile.scale);
      final incoming = await freezeAndReceive(tester, profile.locale);
      final action = find.byKey(const ValueKey('danmaku-resume-live'));
      final surface = tester.getRect(find.byKey(const ValueKey('danmaku-list-surface')));
      final bounds = tester.getRect(action);
      expect(
        bounds.left,
        greaterThanOrEqualTo(surface.left + 8),
        reason: 'The clipped left side must remain visible and tappable.',
      );
      expect(bounds.right, lessThanOrEqualTo(surface.right - 8));
      expect(bounds.bottom, lessThanOrEqualTo(surface.bottom - 8));
      expect(bounds.height, greaterThanOrEqualTo(48));
      expect(action.hitTestable(), findsOneWidget);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(key.currentState!.userScrolling, isFalse);
      expect(find.byKey(ObjectKey(incoming.last)), findsOneWidget);
      expect(action, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('one explicit resume catches up and starts a fresh pending count on the next drag', (tester) async {
    await open(tester, locale: 'en', width: 900, scale: 1);
    final incoming = await freezeAndReceive(tester, 'en');
    final surface = tester.getRect(find.byKey(const ValueKey('danmaku-list-surface')));
    final action = tester.getRect(find.byKey(const ValueKey('danmaku-resume-live')));
    expect(action.width, lessThan(surface.width - 48), reason: 'A short desktop action should not stretch.');
    await tester.tap(find.byKey(const ValueKey('danmaku-resume-live')));
    await tester.pumpAndSettle();
    expect(find.byKey(ObjectKey(incoming.last)), findsOneWidget);
    expect(key.currentState!.userScrolling, isFalse);
    await tester.drag(find.byKey(const ValueKey('danmaku-message-list')), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(key.currentState!.userScrolling, isTrue);
    expect(find.text(labels['en']!['scroll_to_bottom'] as String), findsOneWidget);
    room.danmakuMessages.add(_message('next-arrival'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text((labels['en']!['danmaku_new_messages'] as String).replaceAll('{count}', '1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
