import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/live_play/widgets/button/record_action_button.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/models/record_status.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, Map<String, dynamic>> translations;
  late _RecorderFake recorder;
  late LiveRoom room;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    translations = {
      for (final language in ['zh', 'en'])
        language: jsonDecode(await File('assets/translations/$language.json').readAsString()) as Map<String, dynamic>,
    };
  });

  setUp(() {
    Get.testMode = true;
    recorder = _RecorderFake();
    room = LiveRoom(roomId: 'fixture-room', platform: 'bilibili', title: 'Fixture title', nick: 'Fixture host');
  });

  tearDown(() {
    Get.reset();
    Get.testMode = false;
  });

  Future<void> open(
    WidgetTester tester, {
    String language = 'en',
    Size size = const Size(800, 600),
    double textScale = 1,
    bool compactHeader = false,
    Future<void> Function()? onOpenRecordCenter,
  }) async {
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
        assetLoader: _LoadedTranslations(translations),
        child: Builder(
          builder: (context) => GetMaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: RecordActionButton(
                  room: room,
                  recorderController: recorder,
                  onOpenRecordCenter: onOpenRecordCenter ?? () async {},
                  compactHeader: compactHeader,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDialog(WidgetTester tester, {String language = 'en'}) async {
    await tester.tap(find.widgetWithText(FilledButton, translations[language]!['record'] as String));
    await tester.pumpAndSettle();
  }

  for (final compactHeader in [false, true]) {
    testWidgets('${compactHeader ? 'compact' : 'expanded'} record action keeps a 48dp touch target', (tester) async {
      await open(tester, compactHeader: compactHeader);

      final size = tester.getSize(find.byKey(const ValueKey('record-action-button')));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  }

  for (final language in ['en', 'zh']) {
    testWidgets('$language 320x480 at 3x text keeps every action scrollable and cancellation fixed', (tester) async {
      await open(tester, language: language, size: const Size(320, 480), textScale: 3);
      await openDialog(tester, language: language);

      expect(tester.takeException(), isNull);
      final scroll = find.byKey(const ValueKey('record-action-scroll'));
      final cancel = find.byKey(const ValueKey('record-action-cancel'));
      expect(scroll, findsOneWidget);
      expect(cancel.hitTestable(), findsOneWidget);
      final lastAction = find.text(translations[language]!['remove_monitor'] as String);
      await tester.scrollUntilVisible(
        lastAction,
        120,
        scrollable: find.descendant(of: scroll, matching: find.byType(Scrollable)).first,
        maxScrolls: 20,
      );
      expect(lastAction, findsOneWidget);
      expect(cancel.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('start action revalidates a task added while the dialog is open', (tester) async {
    await open(tester);
    await openDialog(tester);
    final task = LiveRecordTask.fromRoom(room)..status = RecordStatus.waitingLive;
    recorder.tasks.add(task);
    await tester.pump();

    await tester.tap(find.text(translations['en']!['start_record_now'] as String));
    await tester.pumpAndSettle();

    expect(recorder.forceStarts, [task]);
    expect(recorder.addCalls, 0);
  });

  testWidgets('pending monitor addition keeps the header action single-flight', (tester) async {
    final pending = Completer<LiveRecordTask?>();
    recorder.nextAdd = pending;
    await open(tester);
    await openDialog(tester);

    await tester.tap(find.text(translations['en']!['add_monitor'] as String));
    await tester.pumpAndSettle();
    final headerFinder = find.widgetWithText(FilledButton, translations['en']!['record'] as String);
    final headerButton = tester.widget<FilledButton>(headerFinder);
    expect(headerButton.onPressed, isNull);
    expect(recorder.addCalls, 1);

    pending.complete(null);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(headerFinder).onPressed, isNotNull);
  });

  testWidgets('system back cancels the dialog and releases the header action', (tester) async {
    await open(tester);
    await openDialog(tester);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('record-action-dialog')), findsNothing);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, translations['en']!['record'] as String)).onPressed,
      isNotNull,
    );
    expect(recorder.addCalls, 0);
    expect(recorder.forceStarts, isEmpty);
    expect(recorder.stops, isEmpty);
    expect(recorder.removals, isEmpty);
  });

  testWidgets('record center navigation starts after the dialog reverse transition', (tester) async {
    var opens = 0;
    await open(
      tester,
      onOpenRecordCenter: () async {
        opens++;
      },
    );
    await openDialog(tester);

    await tester.tap(find.text(translations['en']!['go_record_center'] as String));
    await tester.pump();
    expect(opens, 0);
    await tester.pump(kThemeAnimationDuration - const Duration(milliseconds: 1));
    expect(opens, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(opens, 1);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('record-action-dialog')), findsNothing);
  });
}

class _RecorderFake implements RecorderController {
  @override
  final RxList<LiveRecordTask> tasks = <LiveRecordTask>[].obs;
  final forceStarts = <LiveRecordTask>[];
  final stops = <LiveRecordTask>[];
  final removals = <LiveRecordTask>[];
  Completer<LiveRecordTask?>? nextAdd;
  int addCalls = 0;

  @override
  Future<LiveRecordTask?> addTask({required LiveRoom room, bool startImmediately = true}) {
    addCalls++;
    return nextAdd?.future ?? Future<LiveRecordTask?>.value(LiveRecordTask.fromRoom(room));
  }

  @override
  Future<void> forceStartTask(LiveRecordTask task) async => forceStarts.add(task);

  @override
  Future<void> stopTask(LiveRecordTask task) async => stops.add(task);

  @override
  Future<void> unRecorder(LiveRecordTask task) async => removals.add(task);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LoadedTranslations extends AssetLoader {
  const _LoadedTranslations(this.translations);
  final Map<String, Map<String, dynamic>> translations;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => translations[locale.languageCode]!;
}
