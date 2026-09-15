import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/modules/tags/live_tag.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';
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

  test('room tag writes normalize IDs and supersede legacy room-only mappings', () async {
    final room = _room();
    final tags = Get.find<TagManagementController>();
    tags.tags.assignAll([LiveTag(id: 'keep', name: 'Keep')]);
    tags.roomTagsMap[room.normalizedRoomId] = ['legacy'];

    await tags.setRoomTags(room, ['keep', 'missing', 'keep']);

    expect(tags.roomTagsMap.containsKey(room.normalizedRoomId), isFalse);
    expect(tags.getTagsForRoom(room), ['keep']);

    await tags.setRoomTags(room, const []);
    expect(tags.getTagsForRoom(room), isEmpty);
  });

  test('legacy room mappings merge with existing platform assignments without data loss', () async {
    final tags = Get.find<TagManagementController>();
    tags.tags.assignAll([LiveTag(id: 'legacy', name: 'Legacy'), LiveTag(id: 'existing', name: 'Existing', order: 1)]);
    tags.roomTagsMap.assignAll({
      'fixture-room': ['legacy', 'legacy', 'missing'],
      'bilibili:fixture-room': ['existing'],
    });

    tags.migrateLegacyRoomTagKeys([_room(), _room(platform: 'huya')]);

    expect(tags.roomTagsMap, {
      'bilibili:fixture-room': ['existing', 'legacy'],
      'huya:fixture-room': ['legacy'],
    });
    await Future<void>.delayed(Duration.zero);
    await HivePrefUtil.flush();
    expect(HivePrefUtil.getAnyPref('room_to_tags_mapping_v1'), {
      'bilibili:fixture-room': ['existing', 'legacy'],
      'huya:fixture-room': ['legacy'],
    });
  });

  testWidgets('room tag assignment opens from the authoritative mapping instead of stale room fields', (tester) async {
    final room = _room()..tagIds = ['stale'];
    SettingsService.to.fav.addRoom(room);
    final tags = Get.find<TagManagementController>();
    tags.tags.assignAll([LiveTag(id: 'mapped', name: 'Mapped tag'), LiveTag(id: 'stale', name: 'Stale tag', order: 1)]);
    tags.roomTagsMap[room.identityKey] = ['mapped'];

    await _pumpCard(tester, english, room);
    await _openTagAssignment(tester);

    expect(_selectedIndicatorFor('Mapped tag'), findsOneWidget);
    expect(_selectedIndicatorFor('Stale tag'), findsNothing);

    await tester.tap(find.text('Confirm').hitTestable().last);
    await tester.pumpAndSettle();
    await HivePrefUtil.flush();
    expect(tags.getTagsForRoom(room), ['mapped']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add form shares limits and IME submission with tag management', (tester) async {
    final room = _room();
    SettingsService.to.fav.addRoom(room);
    await _pumpCard(tester, english, room);
    await _openTagAssignment(tester);

    await tester.tap(find.byIcon(Remix.add_circle_line));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    expect(tester.widget<TextField>(fields.first).maxLength, 15);
    expect(tester.widget<TextField>(fields.last).maxLength, 40);

    await tester.enterText(fields.first, 'Travel');
    await tester.enterText(fields.last, 'Outdoor streams');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(Get.find<TagManagementController>().tags.map((tag) => tag.name), contains('Travel'));
    expect(_selectedIndicatorFor('Travel'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tag assignment remains reachable at 320x480 with 3x English text', (tester) async {
    final room = _room();
    SettingsService.to.fav.addRoom(room);
    final tags = Get.find<TagManagementController>();
    tags.tags.assignAll([
      for (var index = 0; index < 12; index++)
        LiveTag(
          id: 'tag-$index',
          name: 'Long tag name $index',
          description: 'Long tag description $index',
          order: index,
        ),
    ]);

    final textScale = await _pumpCard(tester, english, room);
    await _openTagAssignment(tester);
    textScale.value = 3;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Cancel').hitTestable(), findsOneWidget);
    expect(find.text('Confirm').hitTestable(), findsOneWidget);

    final lastTag = find.text('Long tag name 11');
    await tester.scrollUntilVisible(
      lastTag,
      180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('room-tag-assignment-list')),
        matching: find.byType(Scrollable),
      ),
      maxScrolls: 20,
    );
    await tester.tap(lastTag.hitTestable());
    await tester.pumpAndSettle();
    expect(_selectedIndicatorFor('Long tag name 11'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long-press follow action observes favorite changes made outside its own state', (tester) async {
    final room = _room();
    await _pumpFollowButton(tester, english, room);

    expect(find.text('Follow'), findsOneWidget);
    SettingsService.to.fav.addRoom(room);
    await tester.pumpAndSettle();
    expect(find.text('Unfollow'), findsOneWidget);

    SettingsService.to.fav.removeRoom(room);
    await tester.pumpAndSettle();
    expect(find.text('Follow'), findsOneWidget);
  });

  testWidgets('long-press follow action closes the navigator that owns its dialog', (tester) async {
    final room = _room();
    final nestedNavigator = await _pumpNestedFollowDialog(tester, english, room);

    expect(nestedNavigator.currentState!.canPop(), isTrue);
    await tester.tap(find.text('Follow').hitTestable());
    await tester.pumpAndSettle();

    expect(SettingsService.to.fav.isFavorite(room), isTrue);
    expect(nestedNavigator.currentState!.canPop(), isFalse);
  });

  testWidgets('long-press unfollow requires confirmation and keeps cancellation local', (tester) async {
    final room = _room();
    SettingsService.to.fav.addRoom(room);
    final nestedNavigator = await _pumpNestedFollowDialog(tester, english, room);

    await tester.tap(find.text('Unfollow').hitTestable());
    await tester.pumpAndSettle();
    expect(SettingsService.to.fav.isFavorite(room), isTrue);
    expect(find.text('Are you sure to unfollow Fixture anchor?'), findsOneWidget);

    await tester.tap(find.text('Cancel').hitTestable());
    await tester.pumpAndSettle();
    expect(SettingsService.to.fav.isFavorite(room), isTrue);
    expect(nestedNavigator.currentState!.canPop(), isTrue);

    await tester.tap(find.text('Unfollow').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm').hitTestable());
    await tester.pumpAndSettle();
    expect(SettingsService.to.fav.isFavorite(room), isFalse);
    expect(nestedNavigator.currentState!.canPop(), isFalse);
  });

  testWidgets('long-press unfollow confirmation remains usable at 320x480 with 3x English text', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final room = _room();
    SettingsService.to.fav.addRoom(room);
    final nestedNavigator = await _pumpNestedFollowDialog(tester, english, room, textScale: 3);

    await tester.tap(find.text('Unfollow').hitTestable());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Cancel').hitTestable(), findsOneWidget);
    expect(find.text('Confirm').hitTestable(), findsOneWidget);

    await tester.tap(find.text('Cancel').hitTestable());
    await tester.pumpAndSettle();
    expect(SettingsService.to.fav.isFavorite(room), isTrue);
    expect(nestedNavigator.currentState!.canPop(), isTrue);
  });
}

LiveRoom _room({String platform = 'bilibili'}) => LiveRoom(
  roomId: 'fixture-room',
  platform: platform,
  nick: 'Fixture anchor',
  title: 'Fixture live room',
  liveStatus: LiveStatus.live,
);

Finder _selectedIndicatorFor(String tagName) {
  final tile = find.ancestor(of: find.text(tagName), matching: find.byType(InkWell)).first;
  return find.descendant(of: tile, matching: find.byIcon(Icons.check_rounded));
}

Future<ValueNotifier<double>> _pumpCard(WidgetTester tester, Map<String, dynamic> english, LiveRoom room) async {
  tester.view.physicalSize = const Size(320, 480);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final textScale = ValueNotifier<double>(1);
  addTearDown(textScale.dispose);
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
          builder: (context, child) => ValueListenableBuilder<double>(
            valueListenable: textScale,
            builder: (context, scale, _) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(width: 300, child: RoomCard(room: room)),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return textScale;
}

Future<void> _pumpFollowButton(WidgetTester tester, Map<String, dynamic> english, LiveRoom room) async {
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
          home: Scaffold(
            body: Center(child: FollowButton(room: room)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<GlobalKey<NavigatorState>> _pumpNestedFollowDialog(
  WidgetTester tester,
  Map<String, dynamic> english,
  LiveRoom room, {
  double textScale = 1,
}) async {
  final navigatorKey = GlobalKey<NavigatorState>();
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
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Navigator(
            key: navigatorKey,
            onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const Scaffold(body: SizedBox.expand())),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(
    navigatorKey.currentState!.push<void>(
      DialogRoute<void>(
        context: navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerRight,
              child: FollowButton(room: room),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return navigatorKey;
}

Future<void> _openTagAssignment(WidgetTester tester) async {
  await tester.longPress(find.byType(RoomCard));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Remix.price_tag_3_line));
  await tester.pumpAndSettle();
}

class _Translations extends AssetLoader {
  const _Translations(this.values);

  final Map<String, dynamic> values;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => values;
}
