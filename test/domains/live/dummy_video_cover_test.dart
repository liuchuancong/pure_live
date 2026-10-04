import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/core/config/danmaku_settings_controller.dart';
import 'package:pure_live/core/config/font_settings_controller.dart';
import 'package:pure_live/core/config/settings_service.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/video_player/dummy_video_cover.dart';
import 'package:pure_live/get/get.dart';

/// GetX 会在被 pump 的树销毁时清掉路由登记的依赖，而 `isRegistered` 之后还可能
/// 报 true，所以每次 pump 前都强制重登记一遍。
void _ensureControllers() {
  Get.delete<SettingsService>(force: true);
  Get.delete<DanmakuSettingsController>(force: true);
  Get.delete<FontSettingsController>(force: true);
  Get.put(SettingsService(), permanent: true);
  Get.put(DanmakuSettingsController(), permanent: true);
  Get.put(FontSettingsController(), permanent: true);
}

Future<void> _pump(WidgetTester tester, LiveRoom room, {Size surface = const Size(1280, 720)}) async {
  _ensureControllers();
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      path: 'assets/translations',
      fallbackLocale: const Locale('zh', 'CN'),
      child: GetMaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: surface.width, height: surface.height, child: DummyVideoCover(room: room))),
        ),
      ),
    ),
  );
  // pumpAndSettle 而不是 pump：挂载过程里有一个零延时定时器（GetX 的调度），
  // 不排空的话用例结束时会被判"仍有待处理定时器"。
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : true,
    );
    await EasyLocalization.ensureInitialized();
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
    Get.testMode = true;
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('底色不透明，底下那路占位视频不能透出来', (tester) async {
    await _pump(tester, LiveRoom(platform: 'missevan', roomId: '123', cover: '', avatar: ''));

    final cover = tester.widget<ColoredBox>(find.byKey(const ValueKey('dummy-video-cover')));
    expect(cover.color, Colors.black);
    // 没有封面也没有头像时不挂 Image，就是一块黑底加说明。
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('说明条常驻：不解释的话用户只看到一张静止的图', (tester) async {
    await _pump(tester, LiveRoom(platform: 'missevan', roomId: '123'));

    final notice = tester.widget<Text>(find.byKey(const ValueKey('dummy-video-notice')));
    expect(notice.data, isNotEmpty);
    // 手势要能穿到控制层。
    final ignoring = tester.widget<IgnorePointer>(
      find.ancestor(of: find.byKey(const ValueKey('dummy-video-cover')), matching: find.byType(IgnorePointer)).first,
    );
    expect(ignoring.ignoring, isTrue, reason: 'Scaffold 也会插 IgnorePointer，只认最近的那一层');
  });

  testWidgets('有封面就铺封面，封面缺失退到头像', (tester) async {
    await _pump(tester, LiveRoom(platform: 'missevan', roomId: '123', cover: '//cdn.example.com/cover.jpg'));
    expect(find.byType(Image), findsOneWidget);

    await _pump(tester, LiveRoom(platform: 'missevan', roomId: '123', cover: '', avatar: 'https://cdn.example.com/a.jpg'));
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('竖屏小窗那种矮尺寸不抛异常', (tester) async {
    tester.view.physicalSize = const Size(420, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(tester, LiveRoom(platform: 'missevan', roomId: '123'), surface: const Size(400, 240));

    expect(find.byKey(const ValueKey('dummy-video-notice')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
