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

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-audience-settings-test-');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    Hive.init(hiveDirectory.path);
    await HivePrefUtil.init();
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
    Get.put<SettingsService>(_TestSettingsService(AppSettingsController()));
  });

  tearDown(Get.reset);

  tearDownAll(() async {
    await Hive.close();
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
  });
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
    'audience_bilibili_detail': '热度与累计观看分开显示',
    'audience_douyu_detail': '公开字段按热度显示',
    'audience_huya_detail': '公开字段按热度显示',
    'audience_douyin_detail': '列表可提供在线值',
    'audience_kuaishou_detail': '列表可提供在线值',
    'audience_cc_detail': '列表可提供在线值',
    'audience_twitch_detail': '列表可提供在线值',
    'audience_soop_detail': '列表可提供在线值',
    'audience_yy_detail': '仅提供热度',
    'audience_metric_fallback_desc': '各平台字段口径会单独标注。',
  };
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
