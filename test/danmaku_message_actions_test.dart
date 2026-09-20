import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_message_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Settings extends SettingsService {
  @override
  final fav = FavoriteRoomController();
  @override
  // The actions use actual preference logic without starting network services.
  // ignore: must_call_super
  void onInit() {}
}

class _Room extends GetxController implements LivePlayController {
  final predicates = <bool Function(LiveMessage)>[];
  @override
  void removeDanmakuWhere(bool Function(LiveMessage) predicate) => predicates.add(predicate);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Labels extends AssetLoader {
  _Labels(this.labels);
  final Map<String, dynamic> labels;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => labels;
}

void _case(String name, Future<void> Function(WidgetTester) callback) {
  testWidgets(name, callback, timeout: const Timeout(Duration(seconds: 45)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late _Settings settings;
  late _Room room;
  late Map<String, dynamic> labels;
  late BuildContext host;
  late Map<String, Map<String, dynamic>> translations;
  late ValueNotifier<bool> originVisible;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('danmaku-actions-');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    Hive.init(directory.path);
    await HivePrefUtil.init();
    translations = {
      for (final language in ['en', 'zh'])
        language: jsonDecode(await File('assets/translations/$language.json').readAsString()) as Map<String, dynamic>,
    };
  });
  setUp(() {
    Get.testMode = true;
    originVisible = ValueNotifier(true);
    settings = Get.put<SettingsService>(_Settings()) as _Settings;
    settings.fav.shieldList.clear();
    settings.fav.blockedDanmakuUsers.clear();
    room = Get.put<LivePlayController>(_Room()) as _Room;
  });
  tearDown(() {
    originVisible.dispose();
    Get.reset();
    Get.testMode = false;
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> open(
    WidgetTester tester, {
    String language = 'en',
    double scale = 1,
    Size size = const Size(800, 600),
  }) async {
    labels = translations[language]!;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: [Locale(language)],
        startLocale: Locale(language),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: _Labels(labels),
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
              body: ValueListenableBuilder<bool>(
                valueListenable: originVisible,
                builder: (context, visible, _) => visible
                    ? Builder(
                        builder: (context) {
                          host = context;
                          return const Text('Room fixture');
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapLabel(WidgetTester tester, String key) async {
    final target = find.text(labels[key] as String).last;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  for (final confirm in [false, true]) {
    _case('focused keyword ${confirm ? "confirm" : "cancel"} survives route exit', (tester) async {
      await open(tester);
      final pending = DanmakuMessageActions.showKeywordDialog(host, 'original', controller: room);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  New KEY  ');
      await tapLabel(tester, confirm ? 'confirm' : 'cancel');
      await pending;
      expect(tester.takeException(), isNull);
      expect(settings.fav.shieldList.toList(), confirm ? ['New KEY'] : isEmpty);
      expect(room.predicates.length, confirm ? 1 : 0);
      if (confirm) {
        final predicate = room.predicates.single;
        expect(
          predicate(
            LiveMessage(
              type: LiveMessageType.chat,
              userName: 'viewer',
              message: 'a new key here',
              color: LiveMessageColor.white,
            ),
          ),
          isTrue,
        );
        expect(
          predicate(
            LiveMessage(
              type: LiveMessageType.chat,
              userName: 'viewer',
              message: 'other',
              color: LiveMessageColor.white,
            ),
          ),
          isFalse,
        );
      }
    });
  }

  for (final language in ['en', 'zh']) {
    _case('$language long message keeps keyword action reachable at large text', (tester) async {
      await open(tester, language: language, scale: 2, size: const Size(320, 480));
      final message = LiveMessage(
        type: LiveMessageType.chat,
        userName: 'viewer',
        message: List.filled(25, 'Message content').join(' '),
        color: LiveMessageColor.white,
      );
      final pending = DanmakuMessageActions.show(host, message, controller: room);
      await tester.pumpAndSettle();
      await tapLabel(tester, 'block_danmaku_keyword');
      expect(find.byType(TextField), findsOneWidget);
      await tapLabel(tester, 'cancel');
      await pending;
      expect(settings.fav.shieldList, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
  _case('keyword action survives disposal of the originating message row', (tester) async {
    await open(tester);
    final pending = DanmakuMessageActions.show(
      host,
      LiveMessage(type: LiveMessageType.chat, userName: 'viewer', message: 'old row', color: LiveMessageColor.white),
      controller: room,
    );
    await tester.pumpAndSettle();
    originVisible.value = false;
    await tester.pumpAndSettle();
    expect(host.mounted, isFalse);
    await tapLabel(tester, 'block_danmaku_keyword');
    expect(find.byType(TextField), findsOneWidget);
    await tapLabel(tester, 'cancel');
    await pending;
    expect(settings.fav.shieldList, isEmpty);
    expect(tester.takeException(), isNull);
  });
  for (final dismissal in ['barrier', 'back', 'blank']) {
    _case('keyword $dismissal preserves saved preferences and reopens', (tester) async {
      await open(tester);
      settings.fav.addShieldList('keep');
      final pending = DanmakuMessageActions.showKeywordDialog(host, 'discard', controller: room);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), dismissal == 'blank' ? '   ' : 'edited');
      if (dismissal == 'barrier') {
        await tester.tapAt(const Offset(5, 5));
      } else if (dismissal == 'back') {
        await tester.binding.handlePopRoute();
      } else {
        await tapLabel(tester, 'confirm');
      }
      await tester.pumpAndSettle();
      await pending;
      expect(settings.fav.shieldList.toList(), ['keep']);
      expect(room.predicates, isEmpty);
      final reopened = DanmakuMessageActions.showKeywordDialog(host, 'fresh', controller: room);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'fresh');
      await tapLabel(tester, 'cancel');
      await reopened;
      expect(tester.takeException(), isNull);
    });
  }

  _case('keyword confirmation persists through a real settings file reopen', (tester) async {
    await open(tester);
    final pending = DanmakuMessageActions.showKeywordDialog(host, '  persisted  ', controller: room);
    await tester.pumpAndSettle();
    await tapLabel(tester, 'confirm');
    await pending;
    await tester.runAsync(() async {
      await Hive.box('app_settings').flush();
      await Hive.close();
      await HivePrefUtil.init();
    });
    expect(HivePrefUtil.getStringList('shieldList'), ['persisted']);
    expect(room.predicates, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  _case('copy keeps full long text and changes no blocking preference', (tester) async {
    await open(tester, size: const Size(320, 480), scale: 2);
    final copies = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copies.add((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final content = List.filled(25, 'Complete message').join(' ');
    final pending = DanmakuMessageActions.show(
      host,
      LiveMessage(type: LiveMessageType.chat, userName: 'viewer', message: content, color: LiveMessageColor.white),
      controller: room,
    );
    await tester.pumpAndSettle();
    await tapLabel(tester, 'copy');
    await pending;
    expect(copies, ['viewer: $content']);
    expect(settings.fav.shieldList, isEmpty);
    expect(settings.fav.blockedDanmakuUsers, isEmpty);
    expect(room.predicates, isEmpty);
    expect(tester.takeException(), isNull);
  });

  _case('user block uses the selected user and emits one matching removal', (tester) async {
    await open(tester);
    final pending = DanmakuMessageActions.show(
      host,
      LiveMessage(
        type: LiveMessageType.chat,
        userName: '  Selected  ',
        message: 'hello',
        color: LiveMessageColor.white,
      ),
      controller: room,
    );
    await tester.pumpAndSettle();
    await tapLabel(tester, 'block_danmaku_user');
    await pending;
    expect(settings.fav.blockedDanmakuUsers.toList(), ['Selected']);
    expect(settings.fav.shieldList, isEmpty);
    expect(room.predicates, hasLength(1));
    final matches = room.predicates.single;
    expect(
      matches(
        LiveMessage(
          type: LiveMessageType.chat,
          userName: 'selected',
          message: 'other text',
          color: LiveMessageColor.white,
        ),
      ),
      isTrue,
    );
    expect(
      matches(
        LiveMessage(type: LiveMessageType.chat, userName: 'other', message: 'hello', color: LiveMessageColor.white),
      ),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'zh']) {
    _case('$language keyword field and actions remain reachable above keyboard', (tester) async {
      await open(tester, language: language, scale: 2, size: const Size(320, 480));
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(tester.view.resetViewInsets);
      final pending = DanmakuMessageActions.showKeywordDialog(host, 'draft', controller: room);
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      expect(field.hitTestable(), findsOneWidget);
      expect(MediaQuery.textScalerOf(tester.element(field)).scale(10), 20);
      await tester.enterText(field, 'new keyword');
      await tapLabel(tester, 'confirm');
      await pending;
      expect(settings.fav.shieldList.toList(), ['new keyword']);
      expect(tester.takeException(), isNull);
    });
  }
}
