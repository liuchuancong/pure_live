import 'dart:io';
import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/common/global/initialized.dart';
import 'package:pure_live/plugins/file_recover_utils.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/player/switchable_global_player.dart';
import 'package:pure_live/common/global/platform/desktop_manager.dart';
import 'package:pure_live/common/global/platform/background_server.dart';

const kWindowsScheme = 'purelive://signin';

void main(List<String> args) async {
  // 初始化
  await AppInitializer().initialize(args);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with DesktopWindowMixin {
  final settings = Get.find<SettingsService>();

  StreamSubscription<dynamic>? subscription;
  @override
  void initState() {
    super.initState();
    if (PlatformUtils.isDesktop) {
      DesktopManager.initializeListeners(this);
    }
    initShareM3uState();
    initGlopalPlayer();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (Platform.isAndroid && settings.enableBackgroundPlay.value) {
        bool hasPermission = await BackgroundService.requestPlatformPermissions();
        if (!hasPermission) {
          SmartDialog.showToast("如果需要后台播放，建议开启此权限");
        }
      }
    });
  }

  Future<void> initGlopalPlayer() async {
    if (Get.isRegistered<SettingsService>()) {
      final settings = Get.find<SettingsService>();
      if (PlatformUtils.isDesktop) {
        await SwitchableGlobalPlayer().init(PlayerEngine.mediaKit);
      } else {
        await SwitchableGlobalPlayer().init(PlayerEngine.values[settings.videoPlayerIndex.value]);
      }
    } else {
      Future.delayed(Duration(seconds: 1)).then((value) async {
        initGlopalPlayer();
      });
    }
  }

  @override
  void dispose() {
    if (PlatformUtils.isDesktop) {
      DesktopManager.disposeListeners();
      subscription?.cancel();
    }
    super.dispose();
  }

  bool isDataSourceM3u(String url) => url.contains('.m3u');

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initShareM3uState() async {
    if (Platform.isAndroid) {
      final handler = ShareHandler.instance;
      await handler.getInitialSharedMedia();
      handler.sharedMediaStream.listen((SharedMedia media) async {
        if (isDataSourceM3u(media.content!)) {
          FileRecoverUtils().recoverM3u8BackupByShare(media);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent()},
      child: DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) {
          return Obx(() {
            var themeColor = HexColor(settings.themeColorSwitch.value);
            var showSplashPage = settings.showSplashPage.value;
            ThemeData lightTheme = MyTheme(primaryColor: themeColor).lightThemeData;
            ThemeData darkTheme = MyTheme(primaryColor: themeColor).darkThemeData;
            if (settings.enableDynamicTheme.value) {
              lightTheme = MyTheme(colorScheme: lightDynamic).lightThemeData;
              darkTheme = MyTheme(colorScheme: darkDynamic).darkThemeData;
            }
            return GetMaterialApp(
              title: '纯粹直播',
              scrollBehavior: MyCustomScrollBehavior(),
              debugShowCheckedModeBanner: false,
              themeMode: AppConsts.themeModes[settings.themeModeName.value]!,
              theme: lightTheme.copyWith(
                appBarTheme: AppBarTheme(surfaceTintColor: Colors.transparent),
                pageTransitionsTheme: const PageTransitionsTheme(
                  builders: <TargetPlatform, PageTransitionsBuilder>{
                    TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
                  },
                ),
              ),
              darkTheme: darkTheme.copyWith(appBarTheme: AppBarTheme(surfaceTintColor: Colors.transparent)),
              locale: AppConsts.languages[settings.languageName.value]!,
              navigatorObservers: [FlutterSmartDialog.observer, BackButtonObserver()],
              builder: FlutterSmartDialog.init(
                builder: (context, child) {
                  if (PlatformUtils.isDesktopNotMac) {
                    return DesktopManager.buildWithTitleBar(child);
                  }
                  return child ?? const SizedBox.shrink();
                },
              ),
              supportedLocales: S.delegate.supportedLocales,
              localizationsDelegates: const [
                S.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              initialRoute: showSplashPage ? RoutePath.kSplash : RoutePath.kInitial,
              defaultTransition: Transition.native,
              getPages: AppPages.routes,
            );
          });
        },
      ),
    );
  }
}
