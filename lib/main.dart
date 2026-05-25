import 'dart:io';
import 'dart:async';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pure_live/common/global/initialized.dart';
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/player/core/live_audio_service.dart';
import 'package:pure_live/routes/route_observer_controller.dart';
import 'package:pure_live/core/iptv/services/epg_import_manager.dart';
import 'package:pure_live/common/global/platform/desktop_manager.dart';
import 'package:pure_live/core/iptv/services/iptv_import_manager.dart';

// 引入统一解耦重构后的两个核心数据流解析管理器

void main(List<String> args) async {
  await AppInitializer().initialize(args);
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('zh')],
      path: 'assets/translations',
      fallbackLocale: const Locale('zh'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with DesktopWindowMixin {
  final settings = Get.find<SettingsService>();

  @override
  void initState() {
    super.initState();
    if (PlatformUtils.isDesktop) {
      DesktopManager.initializeListeners(this);
    }
    initSharedMediaListener();
    initGlopalPlayer();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (Platform.isAndroid && settings.enableBackgroundPlay.value) {
        bool hasPermission = await LiveAudioService.requestPlatformPermissions();
        if (!hasPermission) {
          ToastUtil.show(i18n("background_play_permission_tip"));
        }
      }
    });
  }

  Future<void> initGlopalPlayer() async {
    final settings = Get.find<SettingsService>();
    PlayerEngine defaultEngine;

    try {
      if (PlatformUtils.isDesktop) {
        defaultEngine = PlayerEngine.mediaKit;
      } else {
        defaultEngine = PlayerEngine.values[settings.videoPlayerIndex.value];
      }
    } catch (e) {
      defaultEngine = PlayerEngine.mediaKit;
    }
    await GlobalPlayerService.instance.initialize(defaultEngine: defaultEngine);
  }

  @override
  void dispose() {
    if (PlatformUtils.isDesktop) {
      DesktopManager.disposeListeners();
    }
    GlobalPlayerService.instance.playerManager.dispose();
    super.dispose();
  }

  Future<void> initSharedMediaListener() async {
    if (Platform.isAndroid) {
      final handler = ShareHandler.instance;
      await handler.getInitialSharedMedia();
      handler.sharedMediaStream.listen((SharedMedia media) async {
        final path = media.content?.trim().toLowerCase() ?? '';
        if (path.isEmpty) return;
        if (path.endsWith('.m3u') || path.endsWith('.txt') || path.contains('.m3u8')) {
          await IptvImportManager().importFromSharedMedia(media);
        } else if (path.endsWith('.xml') || path.endsWith('.gz') || path.endsWith('.json')) {
          await EpgImportManager().importFromSharedMedia(media);
        } else {
          ToastUtil.show(i18n("unsupported_file_format"));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return Obx(() {
          final themeColor = HexColor(settings.themeColorSwitch.value);
          final showSplashPage = settings.showSplashPage.value;
          final currentFactor = settings.textScaleFactor.value;

          ThemeData lightTheme;
          ThemeData darkTheme;

          if (settings.enableDynamicTheme.value && lightDynamic != null && darkDynamic != null) {
            lightTheme = MyTheme(colorScheme: lightDynamic.harmonized()).lightThemeData;
            darkTheme = MyTheme(colorScheme: darkDynamic.harmonized()).darkThemeData;
          } else {
            lightTheme = MyTheme(primaryColor: themeColor).lightThemeData;
            darkTheme = MyTheme(primaryColor: themeColor).darkThemeData;
          }

          return GetMaterialApp(
            title: i18n('app_name'),
            scrollBehavior: MyCustomScrollBehavior(),
            debugShowCheckedModeBanner: false,
            themeMode: AppConsts.themeModes[settings.themeModeName.value]!,
            theme: lightTheme.copyWith(
              appBarTheme: const AppBarTheme(surfaceTintColor: Colors.transparent),
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: <TargetPlatform, PageTransitionsBuilder>{
                  TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
                },
              ),
            ),
            darkTheme: darkTheme.copyWith(appBarTheme: const AppBarTheme(surfaceTintColor: Colors.transparent)),
            locale: context.locale,
            navigatorObservers: [FlutterSmartDialog.observer, BackButtonObserver()],
            builder: FlutterSmartDialog.init(
              builder: (context, child) {
                Widget resultWidget = child ?? const SizedBox.shrink();
                if (PlatformUtils.isDesktopNotMac) {
                  resultWidget = DesktopManager.buildWithTitleBar(resultWidget);
                }
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(currentFactor)),
                  child: resultWidget,
                );
              },
            ),
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            initialRoute: showSplashPage ? RoutePath.kSplash : RoutePath.kInitial,
            defaultTransition: Transition.native,
            routingCallback: (routing) {
              if (routing != null) {
                RouteObserverController.to.updateRoute(routing.current);
              }
            },
            getPages: AppPages.routes,
          );
        });
      },
    );
  }
}
