import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/core/config/danmaku_settings_controller.dart';
import 'package:pure_live/core/config/font_settings_controller.dart';
import 'package:pure_live/core/config/settings_service.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/video_player/audio_only_presentation.dart';
import 'package:pure_live/get/get.dart';

final LiveRoom _room = LiveRoom(
  platform: 'sixroom',
  roomId: '58018',
  title: '深夜电台 · 一起听歌',
  nick: '主播名字',
  avatar: '',
);

Future<void> _pump(WidgetTester tester, {required Size surface}) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      path: 'assets/translations',
      fallbackLocale: const Locale('zh', 'CN'),
      // AppTextStyles 从 GetMaterialApp 装的 GetRoot 取全局 context，
      // 裸 MaterialApp 会抛 "GetRoot is not part of the three"。
      child: GetMaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: surface.width,
              height: surface.height,
              child: AudioOnlyPresentation(room: _room),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // easy_localization 存语言偏好用 shared_preferences；测试里没有那个插件，
    // 给它一个空的假实现就够（我们不测语言切换）。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : true,
    );
    await EasyLocalization.ensureInitialized();
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
    Get.testMode = true;
  });

  // 每个用例重新登记：GetMaterialApp 的树被换掉时，GetX 会把路由登记的依赖一并
  // 清掉，只在 setUpAll 里登记的话第二个用例就找不到 SettingsService 了。
  setUp(() {
    if (!Get.isRegistered<SettingsService>()) Get.put(SettingsService(), permanent: true);
    // AppTextStyles 的字号来自字体设置控制器，而它的 onInit 会去拿弹幕设置。
    if (!Get.isRegistered<DanmakuSettingsController>()) Get.put(DanmakuSettingsController(), permanent: true);
    if (!Get.isRegistered<FontSettingsController>()) Get.put(FontSettingsController(), permanent: true);
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('横屏全屏尺寸下画出房间信息，且不溢出', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(tester, surface: const Size(1280, 720));

    expect(find.byKey(const ValueKey('audio-only-presentation')), findsOneWidget);
    expect(find.text('深夜电台 · 一起听歌'), findsOneWidget);
    expect(find.text('主播名字'), findsOneWidget);
    // 720 高走非 compact 分支：头像直径 100。
    expect(tester.getSize(find.byKey(const ValueKey('audio-only-avatar'))).width, 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets('竖屏小窗那种矮尺寸要把头像与排版缩下去', (tester) async {
    tester.view.physicalSize = const Size(420, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 240 高 < 500，走 compact 分支：头像、字号、间距都要缩下去。内容在
    // SingleChildScrollView 里，所以溢出不会报错——真正能钉住这个分支的是尺寸。
    await _pump(tester, surface: const Size(400, 240));

    expect(find.byKey(const ValueKey('audio-only-title')), findsOneWidget);
    final avatar = tester.getSize(find.byKey(const ValueKey('audio-only-avatar')));
    expect(avatar.width, lessThan(100), reason: 'compact 分支必须缩小头像');
    expect(avatar.width, greaterThanOrEqualTo(50), reason: '再小就看不出是谁了');
    expect(tester.takeException(), isNull);
  });

  testWidgets('背景必须不透明：视频还在下面解码渲染', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(tester, surface: const Size(1280, 720));

    // 这一层是"盖住"而不是"替换"：半透明等于把画面透出来，纯音频模式就名不副实。
    final cover = tester.widget<ColoredBox>(find.byKey(const ValueKey('audio-only-presentation')));
    expect(cover.color, Colors.black);

    // 手势要能穿过去落到控制层/视频区，这一层自己不吃点击。
    expect(find.descendant(of: find.byType(IgnorePointer), matching: find.byType(ColoredBox)), findsWidgets);
  });
}
