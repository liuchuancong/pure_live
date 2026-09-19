import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings/danmaku_settings_controller.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/modules/shield/danmu_shield_controller.dart';
import 'package:pure_live/modules/shield/danmu_shield_page.dart';
import 'package:pure_live/modules/live_play/pages/keyword_block_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';

class _Settings extends SettingsService {
  @override
  final fav = FavoriteRoomController();
  @override
  final font = FontSettingsController();
  @override
  final danmaku = DanmakuSettingsController();
  @override
  // Use real preferences without starting app/network services.
  // ignore: must_call_super
  void onInit() {}
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
  late Map<String, Map<String, dynamic>> translations;
  late Map<String, dynamic> labels;
  late _Settings settings;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('shield-management-');
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
    settings = Get.put<SettingsService>(_Settings()) as _Settings;
    settings.fav.shieldList.clear();
    settings.fav.blockedDanmakuUsers.clear();
    settings.danmaku.filterDouyuSuspectedAutomatedMessages.value = false;
    settings.danmaku.enableDanmakuSimilarityFilter.value = false;
    Get.put(DanmuShieldController());
  });
  tearDown(() {
    Get.reset();
    Get.testMode = false;
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> open(
    WidgetTester tester, {
    bool modern = false,
    String language = 'en',
    double width = 800,
    double scale = 1,
  }) async {
    labels = translations[language]!;
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
            home: modern ? const KeywordBlockPage() : const DanmuShieldPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> visible(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(target, 160, scrollable: find.byType(Scrollable).first);
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Finder removeFor(String text, {required bool modern}) {
    final row = find
        .ancestor(of: find.text(text), matching: modern ? find.byType(ListTile) : find.byType(InkWell))
        .first;
    return find.descendant(of: row, matching: find.byIcon(Remix.close_line));
  }

  for (final profile in [
    (language: 'en', width: 320.0, scale: 1.0),
    (language: 'en', width: 320.0, scale: 2.0),
    (language: 'zh', width: 320.0, scale: 2.0),
    (language: 'en', width: 900.0, scale: 2.0),
  ]) {
    _case('legacy full keyword fits ${profile.language}/${profile.width}/${profile.scale}', (tester) async {
      final keyword = List.filled(12, profile.language == 'zh' ? '屏蔽关键字' : 'LongKeyword').join();
      settings.fav.shieldList.assignAll([keyword]);
      await open(tester, language: profile.language, width: profile.width, scale: profile.scale);
      expect(tester.takeException(), isNull);
      final label = find.text(keyword);
      await visible(tester, label);
      final text = tester.widget<Text>(label);
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(tester.getRect(label).right, lessThanOrEqualTo(profile.width - 16));
      expect(MediaQuery.textScalerOf(tester.element(label)).scale(10), 10 * profile.scale);
      final remove = removeFor(keyword, modern: false);
      await visible(tester, remove);
      expect(remove.hitTestable(), findsOneWidget);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(settings.fav.shieldList, isEmpty);
      expect(find.text(labels['empty_shield_title'] as String), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  _case('modern list exposes the complete stored keyword and a named remove action', (tester) async {
    final keyword = List.filled(8, 'LongKeyword').join();
    settings.fav.shieldList.assignAll([keyword]);
    final semantics = tester.ensureSemantics();
    try {
      await open(tester, modern: true, width: 320, scale: 2);
      final label = find.text(keyword);
      await visible(tester, label);
      final text = tester.widget<Text>(label);
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(find.bySemanticsLabel('Click to remove: $keyword'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  _case('Douyu heuristic filter is visibly opt-in and applies immediately', (tester) async {
    await open(tester, modern: true, width: 320, scale: 2);
    final label = find.text(labels['douyu_suspected_automated_filter'] as String);
    final description = find.text(labels['douyu_suspected_automated_filter_desc'] as String);
    await visible(tester, label);
    expect(description, findsOneWidget);

    final row = find.ancestor(of: label, matching: find.byType(SwitchListTile));
    expect(tester.widget<SwitchListTile>(row).value, isFalse);
    await tester.tap(label);
    await tester.pumpAndSettle();

    expect(settings.danmaku.filterDouyuSuspectedAutomatedMessages.value, isTrue);
    expect(tester.widget<SwitchListTile>(row).value, isTrue);
    expect(tester.takeException(), isNull);
  });

  _case('legacy keyword chip names the exact remove target', (tester) async {
    settings.fav.shieldList.assignAll(['Selected keyword']);
    final semantics = tester.ensureSemantics();
    try {
      await open(tester, modern: false);
      expect(find.bySemanticsLabel('Click to remove: Selected keyword'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  for (final language in ['en', 'zh']) {
    _case('live filter slider headers fit $language narrow large text', (tester) async {
      settings.danmaku.enableDanmakuSimilarityFilter.value = true;
      await open(tester, modern: true, language: language, width: 320, scale: 2);
      expect(tester.takeException(), isNull);
      for (final key in [
        'danmaku_similarity_threshold',
        'danmaku_similarity_cache_duration',
        'danmaku_similarity_max_cache_size',
      ]) {
        final label = find.text(labels[key] as String);
        await visible(tester, label);
        expect(tester.getRect(label).right, lessThanOrEqualTo(304));
        expect(MediaQuery.textScalerOf(tester.element(label)).scale(10), 20);
      }
      expect(settings.danmaku.danmakuSimilarityThreshold.value, 85);
      expect(tester.takeException(), isNull);
    });
  }

  for (final profile in [(modern: false, users: false), (modern: true, users: false), (modern: true, users: true)]) {
    _case('already removed target leaves neighbors intact modern=${profile.modern} users=${profile.users}', (
      tester,
    ) async {
      final values = profile.users ? settings.fav.blockedDanmakuUsers : settings.fav.shieldList;
      values.assignAll(['keep', 'selected', 'neighbor']);
      await open(tester, modern: profile.modern);
      await visible(tester, find.text('selected'));
      final remove = removeFor('selected', modern: profile.modern);
      await visible(tester, remove);
      values.assignAll(['keep', 'neighbor']);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(values.toList(), ['keep', 'neighbor']);
      expect(tester.takeException(), isNull);
    });

    _case('delete retains rendered identity modern=${profile.modern} users=${profile.users}', (tester) async {
      final values = profile.users ? settings.fav.blockedDanmakuUsers : settings.fav.shieldList;
      values.assignAll(['keep', 'selected']);
      await open(tester, modern: profile.modern);
      await visible(tester, find.text('selected'));
      final remove = removeFor('selected', modern: profile.modern);
      await visible(tester, remove);
      // A preference update happens before this rendered callback's next frame.
      // The user's target is still selected, not the old list index.
      values.assignAll(['inserted', 'keep', 'selected']);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(values.toList(), ['inserted', 'keep']);
      expect(tester.takeException(), isNull);
    });
  }

  for (final modern in [false, true]) {
    _case('add trim duplicate keyboard submit and delete modern=$modern', (tester) async {
      await open(tester, modern: modern);
      final field = find.byType(TextField);
      await visible(tester, field);
      expect(tester.widget<TextField>(field).maxLength, 40);
      await tester.enterText(field, '  first  ');
      final add = modern ? find.byTooltip(labels['add'] as String) : find.text(labels['add'] as String);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(settings.fav.shieldList.toList(), ['first']);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      await tester.enterText(field, 'FIRST');
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(settings.fav.shieldList.toList(), ['first']);
      await tester.enterText(field, 'second');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(settings.fav.shieldList.toList(), ['first', 'second']);
      final remove = removeFor('first', modern: modern);
      await visible(tester, remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(settings.fav.shieldList.toList(), ['second']);
      expect(tester.takeException(), isNull);
    });
  }

  _case('similarity switch and slider remain interactive after header reflow', (tester) async {
    await open(tester, modern: true, width: 320, scale: 2);
    final toggleLabel = find.text(labels['danmaku_similarity_filter_enable'] as String);
    await visible(tester, toggleLabel);
    final toggle = find.descendant(
      of: find.ancestor(of: toggleLabel, matching: find.byType(SwitchListTile)),
      matching: find.byType(Switch),
    );
    await visible(tester, toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(settings.danmaku.enableDanmakuSimilarityFilter.value, isTrue);
    final slider = find.byType(SfSlider).first;
    await visible(tester, slider);
    final rect = tester.getRect(slider);
    await tester.tapAt(Offset(rect.left + rect.width * 0.3, rect.center.dy));
    await tester.pumpAndSettle();
    expect(settings.danmaku.danmakuSimilarityThreshold.value, isNot(85));
    expect(settings.danmaku.danmakuSimilarityThreshold.value, inInclusiveRange(50, 100));
    final selected = settings.danmaku.danmakuSimilarityThreshold.value;
    await visible(tester, toggleLabel);
    await visible(tester, toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(settings.danmaku.enableDanmakuSimilarityFilter.value, isFalse);
    expect(find.byType(SfSlider), findsNothing);
    expect(settings.danmaku.danmakuSimilarityThreshold.value, selected);
    expect(tester.takeException(), isNull);
  });

  _case('filter switch row and slider expose complete adjustable semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await open(tester, modern: true, width: 320, scale: 2);
      final toggleLabel = labels['danmaku_similarity_filter_enable'] as String;
      await visible(tester, find.text(toggleLabel));
      await tester.tap(find.text(toggleLabel));
      await tester.pumpAndSettle();
      expect(settings.danmaku.enableDanmakuSimilarityFilter.value, isTrue);

      final slider = find.byType(SfSlider).first;
      await visible(tester, slider);
      final thresholdLabel = labels['danmaku_similarity_threshold'] as String;
      final thresholdValue = settings.danmaku.danmakuSimilarityThreshold.value;
      final threshold = find.semantics.byValue('$thresholdLabel, $thresholdValue%');
      expect(threshold, findsOneWidget);
      final data = threshold.evaluate().single.getSemanticsData();
      expect(data.hasAction(ui.SemanticsAction.increase), isTrue);
      expect(data.hasAction(ui.SemanticsAction.decrease), isTrue);
    } finally {
      semantics.dispose();
    }
  });

  test('filter preference parsing trims and deduplicates the case-insensitive matching keys', () {
    final parsed = FavoriteRoomController.parseConfig({
      'shieldList': ['  Spam  ', 'spam', '', 'NEWS'],
      'blockedDanmakuUsers': [' Alice ', 'alice', 'BOB'],
    });

    expect(parsed['shieldList'], ['Spam', 'NEWS']);
    expect(parsed['blockedDanmakuUsers'], ['Alice', 'BOB']);
  });

  test('filter add APIs preserve the first spelling and reject case-only duplicates', () {
    expect(settings.fav.addShieldList('  Spam  '), isTrue);
    expect(settings.fav.addShieldList('spam'), isFalse);
    expect(settings.fav.shieldList, ['Spam']);

    expect(settings.fav.addBlockedDanmakuUser(' Alice '), isTrue);
    expect(settings.fav.addBlockedDanmakuUser('alice'), isFalse);
    expect(settings.fav.blockedDanmakuUsers, ['Alice']);
  });
}
