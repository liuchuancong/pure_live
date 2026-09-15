import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/tags/live_tag.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';
import 'package:pure_live/modules/tags/tag_management_page.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> english;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
    english = jsonDecode(await File('assets/translations/en.json').readAsString()) as Map<String, dynamic>;
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
    Get.put(SettingsService(), permanent: true);
    Get.put(TagManagementController());
  });

  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    await HivePrefUtil.flush();
    Get.reset();
  });

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 10));
  });

  testWidgets('tag card and actions remain reachable at narrow 3x text', (tester) async {
    Get.find<TagManagementController>().tags.assignAll([
      LiveTag(
        id: 'first',
        name: 'FifteenLetterTag',
        description: 'A deliberately long tag description that fills both summary lines.',
      ),
    ]);

    await _pumpPage(tester, english);
    final font = SettingsService.to.font;
    font.fontSizeBodySmall.value = 15;
    font.fontSizeBodyLarge.value = 18;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final edit = find.byIcon(Remix.edit_line);
    expect(edit.hitTestable(), findsOneWidget);
    expect(find.byIcon(Remix.delete_bin_line).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tag details keep long content and confirmation reachable', (tester) async {
    Get.find<TagManagementController>().tags.assignAll([
      LiveTag(
        id: 'detail',
        name: 'FifteenLetterTag',
        description: 'A deliberately long description that must remain readable in the details dialog.',
      ),
    ]);
    await _pumpPage(tester, english);

    final tagName = find.text('FifteenLetterTag');
    await _scrollUntilHitTestable(tester, tagName);
    await tester.tap(tagName.hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Tag Details'), findsOneWidget);
    expect(find.text('Confirm').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tag detail entry exposes its full named action', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      Get.find<TagManagementController>().tags.assignAll([
        LiveTag(id: 'named-detail', name: 'Travel streams', description: 'Outdoor channels'),
      ]);
      await _pumpPage(tester, english);

      final entryKey = find.byKey(const ValueKey('tag-detail-named-detail'));
      await _scrollUntilHitTestable(tester, entryKey);
      final semanticsNode = tester.getSemantics(entryKey);
      final semanticsData = semanticsNode.getSemanticsData();
      expect(semanticsNode.label, 'View tag details: Travel streams');
      expect(semanticsData.flagsCollection.isButton, isTrue);
      expect(semanticsData.hasAction(SemanticsAction.tap), isTrue);
      expect(tester.getSize(entryKey).height, greaterThanOrEqualTo(48));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('rapid repeated tag detail activation owns one dialog route', (tester) async {
    Get.find<TagManagementController>().tags.assignAll([
      LiveTag(id: 'single-detail', name: 'Travel streams', description: 'Outdoor channels'),
    ]);
    await _pumpPage(tester, english);

    final detailEntry = find.byKey(const ValueKey('tag-detail-single-detail'));
    await _scrollUntilHitTestable(tester, detailEntry);
    await tester.tap(detailEntry);
    await tester.tap(detailEntry, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Tag Details'), findsOneWidget);
    await tester.tap(find.text('Confirm').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('IME done submits the same add-tag transaction as Confirm', (tester) async {
    await _pumpPage(tester, english);
    await tester.tap(find.byIcon(Remix.add_line));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.first, 'Travel');
    await tester.enterText(fields.last, 'Outdoor streams');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(Get.find<TagManagementController>().tags.map((tag) => tag.name), contains('Travel'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('deleting a tag removes its room assignments and ignores stale indices', () async {
    final controller = Get.find<TagManagementController>();
    controller.tags.assignAll([LiveTag(id: 'remove', name: 'Remove'), LiveTag(id: 'keep', name: 'Keep', order: 1)]);
    controller.roomTagsMap.assignAll({
      'bilibili:1': ['remove', 'keep'],
      'huya:2': ['remove'],
    });

    controller.deleteTag(0);
    await Future<void>.delayed(Duration.zero);

    expect(controller.tags.map((tag) => tag.id), ['keep']);
    expect(controller.roomTagsMap, {
      'bilibili:1': ['keep'],
    });
    expect(() => controller.deleteTag(20), returnsNormally);
    expect(() => controller.updateTag(-1, 'bad', ''), returnsNormally);
  });
}

Future<void> _pumpPage(WidgetTester tester, Map<String, dynamic> english) async {
  tester.view.physicalSize = const Size(320, 480);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en')],
      startLocale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: _Translations(english),
      child: Builder(
        builder: (context) => GetMaterialApp(
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(3)),
            child: child!,
          ),
          home: const TagManagementPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollUntilHitTestable(WidgetTester tester, Finder target) async {
  final scrollable = find.descendant(of: find.byType(TagManagementPage), matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(target, 120, scrollable: scrollable, maxScrolls: 30);
  expect(target, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5, duration: Duration.zero);
  await tester.pumpAndSettle();
}

class _Translations extends AssetLoader {
  const _Translations(this.values);

  final Map<String, dynamic> values;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => values;
}
