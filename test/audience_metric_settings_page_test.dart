import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/settings/pages/audience_metric_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  late Map<String, dynamic> english;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-audience-settings-test-');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    english = jsonDecode(await File('assets/translations/en.json').readAsString()) as Map<String, dynamic>;
    Hive.init(hiveDirectory.path);
    await HivePrefUtil.init();
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
    Get.put<SettingsService>(_TestSettingsService(_AudienceTestAppSettings()));
  });

  tearDown(Get.reset);

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 10));
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('unsupported audience rows render without an empty GetX card', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('zh')],
        path: 'assets/translations',
        fallbackLocale: const Locale('zh'),
        assetLoader: const _AudienceAssetLoader(),
        child: Builder(
          builder: (context) => GetMaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: const AudienceMetricSettingsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('audience-platform-bilibili')), findsOneWidget);
    expect(find.text('哔哩哔哩'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('audience-platform-douyin')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final acfun = find.byKey(const ValueKey('audience-platform-acfun'));
    await tester.ensureVisible(acfun);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(acfun).value, isTrue);
    await tester.tap(acfun);
    await tester.pumpAndSettle();
    expect(SettingsService.to.app.isRealOnlineEnabledFor('acfun'), isFalse);
    expect(tester.widget<SwitchListTile>(acfun).value, isFalse);
    final picarto = find.byKey(const ValueKey('audience-platform-picarto'));
    await tester.ensureVisible(picarto);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(picarto).value, isTrue);
    await tester.tap(picarto);
    await tester.pumpAndSettle();
    expect(SettingsService.to.app.isRealOnlineEnabledFor('picarto'), isFalse);
    expect(tester.widget<SwitchListTile>(picarto).value, isFalse);
    final twitcasting = find.byKey(const ValueKey('audience-platform-twitcasting'));
    await tester.ensureVisible(twitcasting);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(twitcasting).value, isTrue);
    await tester.tap(twitcasting);
    await tester.pumpAndSettle();
    expect(SettingsService.to.app.isRealOnlineEnabledFor('twitcasting'), isFalse);
    expect(tester.widget<SwitchListTile>(twitcasting).value, isFalse);
    final openrec = find.byKey(const ValueKey('audience-platform-openrec'));
    await tester.ensureVisible(openrec);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(openrec).value, isTrue);
    await tester.tap(openrec);
    await tester.pumpAndSettle();
    expect(SettingsService.to.app.isRealOnlineEnabledFor('openrec'), isFalse);
    expect(tester.widget<SwitchListTile>(openrec).value, isFalse);
    final tting = find.byKey(const ValueKey('audience-platform-ttinglive'));
    await tester.ensureVisible(tting);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(tting).value, isTrue);
    await tester.tap(tting);
    await tester.pumpAndSettle();
    expect(SettingsService.to.app.isRealOnlineEnabledFor('ttinglive'), isFalse);
    expect(tester.widget<SwitchListTile>(tting).value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy platform spellings render through canonical switch state', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = SettingsService.to.app;
    app.realOnlinePlatforms.assignAll([' DOUYIN ', 'HUYA']);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('zh')],
        path: 'assets/translations',
        fallbackLocale: const Locale('zh'),
        assetLoader: const _AudienceAssetLoader(),
        child: Builder(
          builder: (context) => GetMaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: const AudienceMetricSettingsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final douyin = find.byKey(const ValueKey('audience-platform-douyin'));
    await tester.ensureVisible(douyin);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(douyin).value, isTrue);
    expect(app.realOnlinePlatforms, [' DOUYIN ', 'HUYA']);
    expect(app.toJson()['realOnlinePlatforms'], ['douyin']);

    await tester.tap(douyin);
    await tester.pumpAndSettle();
    expect(app.realOnlinePlatforms, isEmpty);
    expect(tester.widget<SwitchListTile>(douyin).value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every live platform stays localized and operable in narrow very-large text', (tester) async {
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
            home: const AudienceMetricSettingsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final onlineMode = find.byKey(const ValueKey('audience-mode-online'));
    await _scrollPageUntilHitTestable(tester, onlineMode);
    await tester.tap(onlineMode.hitTestable());
    await tester.pumpAndSettle();
    expect(SettingsService.to.app.preferRealOnlineCounts.value, isTrue);

    const expectedPlatforms = <String, String>{
      'bilibili': 'Bilibili',
      'douyu': 'Douyu',
      'huya': 'Huya',
      'douyin': 'Douyin',
      'kuaishou': 'Kuaishou',
      'cc': 'NetEase CC',
      'twitch': 'Twitch',
      'soop': 'Soop',
      'yy': 'YY',
      'acfun': 'AcFun Live',
      'picarto': 'Picarto',
      'twitcasting': 'TwitCasting',
      'missevan': 'Missevan',
      'inke': 'Inke',
      'kilakila': 'Kilakila',
      'huajiao': 'Huajiao',
      'openrec': 'mellow-fan (OPENREC)',
      'ttinglive': 'FLEX TV (TTingLive)',
      'xiaohongshu': 'Xiaohongshu',
      'niconico': 'niconico',
      'weibo': 'Weibo Live',
    };
    for (final entry in expectedPlatforms.entries) {
      final tile = find.byKey(ValueKey('audience-platform-${entry.key}'));
      await _scrollPageUntilHitTestable(tester, tile);
      expect(find.descendant(of: tile, matching: find.text(entry.value)), findsOneWidget);
      final detail = find.byKey(ValueKey('audience-platform-detail-${entry.key}'));
      expect(tester.getRect(detail).bottom, lessThanOrEqualTo(tester.getRect(tile).bottom));
      expect(tester.takeException(), isNull);
      if (entry.key == 'acfun') {
        expect(tester.widget<SwitchListTile>(tile).value, isTrue);
        await tester.tap(tile.hitTestable());
        await tester.pumpAndSettle();
        expect(SettingsService.to.app.isRealOnlineEnabledFor('acfun'), isFalse);
      }
    }
    expect(tester.takeException(), isNull);
  }, skip: !Platform.isWindows);
}

Future<void> _scrollPageUntilHitTestable(WidgetTester tester, Finder target) async {
  final scrollable = tester.state<ScrollableState>(
    find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first,
  );
  for (var attempt = 0; attempt < 120; attempt++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final position = scrollable.position;
    final delta = position.viewportDimension * 0.25;
    final next = (position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
    position.jumpTo(next);
    await tester.pump();
  }
  fail('Target did not become hit-testable after bounded page scrolling.');
}

class _AudienceAssetLoader extends AssetLoader {
  const _AudienceAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
    'audience_metric_settings': '观看数据与排行口径',
    'audience_display_mode': '显示方式',
    'audience_mode_heat': '平台热度优先',
    'audience_mode_heat_desc': '按平台原始口径显示',
    'audience_mode_online': '真实在线人数优先',
    'audience_mode_online_desc': '支持的平台显示并发在线',
    'audience_ranking_rule_desc': '在线优先，其次等待数据，最后是热度。',
    'audience_online_platforms': '真实在线平台开关',
    'audience_source_room_list': '房间列表直接提供',
    'audience_source_room_realtime': '进入房间后实时提供',
    'audience_source_not_exposed': '平台公开接口仅提供热度',
    'site_bilibili': '哔哩哔哩',
    'site_douyu': '斗鱼',
    'site_huya': '虎牙',
    'site_douyin': '抖音',
    'site_kuaishou': '快手',
    'site_cc': '网易 CC',
    'site_twitch': 'Twitch',
    'site_soop': 'SOOP',
    'site_yy': 'YY Live',
    'site_acfun': 'AcFun',
    'site_picarto': 'Picarto',
    'site_twitcasting': 'TwitCasting',
    'site_missevan': '猫耳 FM',
    'site_inke': '映客',
    'site_kilakila': '克拉克拉',
    'site_huajiao': '花椒',
    'site_openrec': 'mellow-fan (OPENREC)',
    'site_ttinglive': 'FLEX TV (TTingLive)',
    'site_xiaohongshu': '小红书',
    'site_niconico': 'niconico',
    'site_weibo': '微博直播',
    'audience_bilibili_detail': '热度与累计观看分开显示',
    'audience_douyu_detail': '公开字段按热度显示',
    'audience_huya_detail': '公开字段按热度显示',
    'audience_douyin_detail': '列表可提供在线值',
    'audience_kuaishou_detail': '列表可提供在线值',
    'audience_cc_detail': '列表可提供在线值',
    'audience_twitch_detail': '列表可提供在线值',
    'audience_soop_detail': '列表可提供在线值',
    'audience_yy_detail': '仅提供热度',
    'audience_acfun_detail': '列表提供在线数，作者搜索没有在线数',
    'audience_picarto_detail': '在线人数与累计观看分列',
    'audience_twitcasting_detail': '目录提供在线值，详情暂缺该值',
    'audience_openrec_detail': '公开在线人数与累计值分开，隐藏时保持未知',
    'audience_ttinglive_detail': '目录提供当前观看数，频道详情不提供',
    'audience_missevan_detail': '公开 score 是平台热度',
    'audience_inke_detail': '未提供已验证的观看人数',
    'audience_kilakila_detail': 'watchNumber 不作为并发人数',
    'audience_huajiao_detail': '目录 heat 是平台热度',
    'audience_xiaohongshu_detail': '展示文本不作为并发人数',
    'audience_niconico_detail': 'watchCount 是累计观看',
    'audience_weibo_detail': '未提供已验证的观看人数',
    'audience_metric_fallback_desc': '各平台字段口径会单独标注。',
  };
}

class _Translations extends AssetLoader {
  const _Translations(this.values);

  final Map<String, dynamic> values;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => values;
}

// Widget tests own a fake clock. Keep their observable state in memory; the
// actual Hive write/upgrade contract is covered in acfun_catalog_migration_test.
class _AudienceTestAppSettings extends AppSettingsController {
  final RxList<String> _onlinePlatforms = List<String>.from(AppSettingsController.defaultRealOnlinePlatforms).obs;
  @override
  RxList<String> get realOnlinePlatforms => _onlinePlatforms;
}

class _TestSettingsService extends SettingsService {
  _TestSettingsService(this._app) : _font = FontSettingsController();

  final AppSettingsController _app;
  final FontSettingsController _font;

  @override
  AppSettingsController get app => _app;

  @override
  FontSettingsController get font => _font;

  @override
  // Test fixture intentionally skips production controller registrations.
  // ignore: must_call_super
  void onInit() {}
}
