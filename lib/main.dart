import 'dart:io';
import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pure_live/common/global/initialized.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/routes/navigation_observer.dart';
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/routes/route_observer_controller.dart';
import 'package:pure_live/core/iptv/services/epg_import_manager.dart';
import 'package:pure_live/common/global/platform/desktop_manager.dart';
import 'package:pure_live/core/iptv/services/iptv_import_manager.dart';

void main(List<String> args) async {
  // Flutter abbreviates every framework error after the first one. In release
  // builds that abbreviation hides the actual exception behind a diagnostics
  // node, making a grey player surface impossible to diagnose from logcat.
  // Always retain the concrete exception and stack locally on the device.
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details, forceReport: true);
  };

  await AppInitializer().initialize(args);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('zh')],
      path: 'assets/translations',
      fallbackLocale: const Locale('zh'),
      assetLoader: const RootBundleAssetLoader(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with DesktopWindowMixin {
  StreamSubscription<SharedMedia>? _sharedMediaSubscription;

  @override
  void initState() {
    super.initState();
    // Start favourite verification after the first Flutter frame instead of
    // waiting until HomePage is created. When the splash page is enabled this
    // overlaps its one-second animation; when it is disabled the first frame
    // still wins over network/JSON work. The controller already publishes the
    // settled room snapshot as one transaction, so cards do not reshuffle as
    // individual requests finish.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Get.isRegistered<FavoriteController>()) {
        Get.find<FavoriteController>();
      }
    });
    if (PlatformUtils.isDesktop) {
      DesktopManager.initializeListeners(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(DesktopManager.updateTrayWhenLocalized());
      });
    }
    unawaited(initSharedMediaListener());
    unawaited(initGlobalPlayer());
  }

  Future<void> initGlobalPlayer() async {
    final String savedKey = SettingsService.to.player.videoPlayerKey.v;
    final String validKey = PlayerConsts.engines.containsKey(savedKey) ? savedKey : PlayerConsts.defaultKey;
    final PlayerEngine targetEngine = PlayerConsts.engines[validKey]!;
    final PlayerEngine defaultEngine;

    if (PlatformUtils.isDesktop) {
      defaultEngine = PlayerEngine.mediaKit;
    } else {
      defaultEngine = targetEngine;
    }
    await GlobalPlayerService.instance.initialize(defaultEngine: defaultEngine);
  }

  @override
  void dispose() {
    if (PlatformUtils.isDesktop) {
      DesktopManager.disposeListeners();
    }
    final subscription = _sharedMediaSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    unawaited(GlobalPlayerService.instance.dispose());
    super.dispose();
  }

  Future<void> initSharedMediaListener() async {
    if (Platform.isAndroid) {
      final handler = ShareHandler.instance;
      await handler.getInitialSharedMedia();
      _sharedMediaSubscription = handler.sharedMediaStream.listen((SharedMedia media) async {
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
          final themeColor = HexColor(SettingsService.to.theme.themeColorSwitch.v);
          final showSplashPage = SettingsService.to.app.showSplashPage.v;
          final currentFactor = SettingsService.to.font.textScaleFactor.v;

          ThemeData lightTheme;
          ThemeData darkTheme;

          if (SettingsService.to.theme.enableDynamicTheme.v && lightDynamic != null && darkDynamic != null) {
            lightTheme = MyTheme(colorScheme: lightDynamic.harmonized()).lightThemeData;
            darkTheme = MyTheme(colorScheme: darkDynamic.harmonized()).darkThemeData;
          } else {
            lightTheme = MyTheme(primaryColor: themeColor).lightThemeData;
            darkTheme = MyTheme(primaryColor: themeColor).darkThemeData;
          }

          return GetMaterialApp(
            // The localized title is rendered by CustomTitleBar. A stable
            // application title avoids asking EasyLocalization for a key
            // before its delegate has completed the first load.
            title: i18n('app_name'),
            scrollBehavior: MyCustomScrollBehavior(),
            debugShowCheckedModeBanner: false,
            themeMode: AppConsts.themeModes[SettingsService.to.theme.themeModeName.v]!,
            theme: lightTheme.copyWith(
              appBarTheme: const AppBarTheme(surfaceTintColor: Colors.transparent),
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: <TargetPlatform, PageTransitionsBuilder>{
                  TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
                  TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
                },
              ),
            ),
            darkTheme: darkTheme.copyWith(
              appBarTheme: const AppBarTheme(surfaceTintColor: Colors.transparent),
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: <TargetPlatform, PageTransitionsBuilder>{
                  TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
                  TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
                },
              ),
            ),
            locale: context.locale,
            navigatorObservers: [FlutterSmartDialog.observer, LiveRouteObserver()],
            builder: FlutterSmartDialog.init(
              builder: (context, child) {
                Widget resultWidget = child ?? const SizedBox.shrink();
                if (PlatformUtils.isDesktopNotMac) {
                  resultWidget = DesktopManager.buildWithTitleBar(resultWidget);
                } else if (Platform.isAndroid) {
                  resultWidget = AdaptiveRefreshRateScope(
                    mode: SettingsService.to.app.refreshRateMode,
                    child: resultWidget,
                  );
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
