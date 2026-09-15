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

  testWidgets('tag card actions expose the affected tag name', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      Get.find<TagManagementController>().tags.assignAll([
        LiveTag(id: 'named-actions', name: 'Travel streams', description: 'Outdoor channels'),
      ]);
      await _pumpPage(tester, english);

      final expectedLabels = {
        'pin-tag-named-actions': 'Move Travel streams to top',
        'edit-tag-named-actions': 'Edit tag: Travel streams',
        'delete-tag-named-actions': 'Delete tag: Travel streams',
      };
      for (final entry in expectedLabels.entries) {
        final action = find.byKey(ValueKey(entry.key));
        await _scrollUntilHitTestable(tester, action);
        final semanticsNode = tester.getSemantics(action);
        final semanticsData = semanticsNode.getSemanticsData();
        expect(semanticsNode.label, entry.value);
        expect(semanticsData.flagsCollection.isButton, isTrue);
        expect(semanticsData.hasAction(SemanticsAction.tap), isTrue);
        expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      }
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
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(detailEntry);
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

  testWidgets('tag editor keeps validation inline and exposes named clear actions', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      Get.find<TagManagementController>().tags.assignAll([LiveTag(id: 'existing', name: 'Existing')]);
      await _pumpPage(tester, english);
      await tester.tap(find.byIcon(Remix.add_line));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tag-editor-confirm')).hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Tag name cannot be empty'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);

      final nameField = find.byKey(const ValueKey('tag-editor-name'));
      await tester.enterText(nameField, ' existing ');
      await tester.tap(find.byKey(const ValueKey('tag-editor-confirm')).hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('A tag with this name already exists'), findsOneWidget);

      await tester.enterText(nameField, 'Travel');
      await tester.enterText(find.byKey(const ValueKey('tag-editor-description')), 'Outdoor streams');
      await tester.pump();
      expect(find.text('A tag with this name already exists'), findsNothing);

      final clearName = find.byKey(const ValueKey('tag-editor-clear-name'));
      final clearDescription = find.byKey(const ValueKey('tag-editor-clear-description'));
      expect(clearName, findsOneWidget);
      expect(clearDescription, findsOneWidget);
      expect(tester.getSemantics(clearName).label, 'Clear tag name');
      expect(tester.getSemantics(clearDescription).label, 'Clear tag description');
      expect(tester.getSize(clearName).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(clearDescription).height, greaterThanOrEqualTo(48));

      await Scrollable.ensureVisible(tester.element(clearDescription), alignment: 0.5, duration: Duration.zero);
      await tester.pump();
      expect(clearDescription.hitTestable(), findsOneWidget);
      await tester.tap(clearDescription);
      await tester.pump();
      await Scrollable.ensureVisible(tester.element(clearName), alignment: 0.5, duration: Duration.zero);
      await tester.pump();
      expect(clearName.hitTestable(), findsOneWidget);
      await tester.tap(clearName);
      await tester.pump();
      expect(tester.widget<TextField>(nameField).controller!.text, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('case-only edit remains reachable and commits at narrow 3x text', (tester) async {
    final controller = Get.find<TagManagementController>();
    controller.tags.assignAll([LiveTag(id: 'case-edit', name: 'Travel', description: 'Before')]);
    await _pumpPage(tester, english);

    final editAction = find.byKey(const ValueKey('edit-tag-case-edit'));
    await _scrollUntilHitTestable(tester, editAction);
    await tester.tap(editAction);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tag-editor-cancel')).hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('tag-editor-confirm')).hitTestable(), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('tag-editor-name')), ' travel ');
    await tester.enterText(find.byKey(const ValueKey('tag-editor-description')), 'After');
    await tester.tap(find.byKey(const ValueKey('tag-editor-confirm')).hitTestable());
    await tester.pumpAndSettle();

    expect(controller.tags.single.name, 'travel');
    expect(controller.tags.single.description, 'After');
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

  test('case-only rename excludes the edited tag from duplicate detection', () async {
    final controller = Get.find<TagManagementController>();
    controller.tags.assignAll([LiveTag(id: 'travel', name: 'Travel'), LiveTag(id: 'work', name: 'Work', order: 1)]);

    expect(controller.updateTag(0, ' travel ', 'Updated description'), isTrue);
    expect(controller.tags.first.name, 'travel');
    expect(controller.tags.first.description, 'Updated description');

    expect(controller.updateTag(0, 'WORK', 'Must stay unchanged'), isFalse);
    expect(controller.tags.first.name, 'travel');
    expect(controller.tags.first.description, 'Updated description');
  });

  test('rapid tag creation keeps every persisted identity unique', () async {
    final controller = Get.find<TagManagementController>();

    for (var index = 0; index < 256; index++) {
      expect(controller.addTag('Tag $index', ''), isTrue);
    }

    final ids = controller.tags.map((tag) => tag.id).toList(growable: false);
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('loading legacy identity collisions repairs and persists stable tag keys', () async {
    Get.delete<TagManagementController>();
    await HivePrefUtil.setAnyPref('user_custom_tags_v5', [
      {'id': 'duplicate', 'name': 'Second', 'description': '', 'order': 1},
      {'id': 'duplicate', 'name': 'First', 'description': '', 'order': 0},
    ]);

    final controller = Get.put(TagManagementController());
    expect(controller.tags.map((tag) => tag.name), ['First', 'Second']);
    expect(controller.tags.map((tag) => tag.order), [0, 1]);
    final ids = controller.tags.map((tag) => tag.id).toList(growable: false);
    expect(ids.first, 'duplicate');
    expect(ids.last, isNot('duplicate'));
    expect(ids.toSet(), hasLength(2));

    await Future<void>.delayed(Duration.zero);
    await HivePrefUtil.flush();
    final stored = HivePrefUtil.getAnyPref('user_custom_tags_v5') as List<dynamic>;
    expect(stored.map((entry) => (entry as Map)['id']).toSet(), hasLength(2));
  });

  test('loading room mappings removes blank keys, duplicate IDs, and orphan IDs', () async {
    Get.delete<TagManagementController>();
    await HivePrefUtil.setAnyPref('user_custom_tags_v5', [
      {'id': 'first', 'name': 'First', 'description': '', 'order': 0},
      {'id': 'second', 'name': 'Second', 'description': '', 'order': 1},
    ]);
    await HivePrefUtil.setAnyPref('room_to_tags_mapping_v1', {
      ' room ': ['first', 'first', 'missing'],
      'room': ['second'],
      'empty': ['missing'],
      'valid': ['second'],
      '   ': ['first'],
    });

    final controller = Get.put(TagManagementController());
    expect(controller.roomTagsMap, {
      'room': ['first', 'second'],
      'valid': ['second'],
    });

    await Future<void>.delayed(Duration.zero);
    await HivePrefUtil.flush();
    expect(HivePrefUtil.getAnyPref('room_to_tags_mapping_v1'), {
      'room': ['first', 'second'],
      'valid': ['second'],
    });
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
