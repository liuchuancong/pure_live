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
import 'package:pure_live/routes/android_native_page_transition.dart';
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
  StreamSubscription<SharedMedia>? _sharedMediaSubscription;

  Timer? _themeChangeDebounce;
  ThemeData? _pendingTheme;

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
        if (mounted) {
          unawaited(DesktopManager.updateTrayWhenLocalized());
        }
      });
    }

    unawaited(initSharedMediaListener());
    unawaited(initGlobalPlayer());
  }

  Future<void> initGlobalPlayer() async {
    final String savedKey = SettingsService.to.player.videoPlayerKey.v;

    final String validKey = PlayerConsts.engines.containsKey(savedKey)
        ? savedKey
        : PlayerConsts.defaultKey;

    final PlayerEngine targetEngine = PlayerConsts.engines[validKey]!;

    final PlayerEngine defaultEngine;

    if (PlatformUtils.isDesktop) {
      defaultEngine = PlayerEngine.mediaKit;
    } else {
      defaultEngine = targetEngine;
    }

    await GlobalPlayerService.instance.initialize(defaultEngine: defaultEngine);
  }

  void _debounceThemeChange(ThemeData theme) {
    _pendingTheme = theme;

    _themeChangeDebounce?.cancel();

    _themeChangeDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;

      final latestTheme = _pendingTheme;
      if (latestTheme == null) return;

      final currentTheme = Get.theme;

      if (_isSameTheme(currentTheme, latestTheme)) {
        return;
      }

      Get.changeTheme(latestTheme);
    });
  }

  bool _isSameTheme(ThemeData a, ThemeData b) {
    return a.brightness == b.brightness &&
        a.colorScheme.primary == b.colorScheme.primary &&
        a.colorScheme.secondary == b.colorScheme.secondary &&
        a.colorScheme.tertiary == b.colorScheme.tertiary &&
        a.colorScheme.surface == b.colorScheme.surface &&
        a.colorScheme.surfaceContainer == b.colorScheme.surfaceContainer &&
        a.colorScheme.surfaceContainerLow == b.colorScheme.surfaceContainerLow &&
        a.colorScheme.surfaceContainerHigh == b.colorScheme.surfaceContainerHigh;
  }

  @override
  void dispose() {
    _themeChangeDebounce?.cancel();
    _themeChangeDebounce = null;
    _pendingTheme = null;
    _pendingTheme = null;

    if (PlatformUtils.isDesktop) {
      DesktopManager.disposeListeners();
    }

    final subscription = _sharedMediaSubscription;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }

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
          ToastUtil.show(i18n('unsupported_file_format'));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return Obx(() {
          final themeColor = HexColor(SettingsService.to.theme.themeColorSwitch.v);

          final showSplashPage = SettingsService.to.app.showSplashPage.v;

          final currentFactor = SettingsService.to.font.textScaleFactor.v;

          final enableDynamicTheme = SettingsService.to.theme.enableDynamicTheme.value;

          ThemeData lightTheme;
          ThemeData darkTheme;

          if (enableDynamicTheme && lightDynamic != null && darkDynamic != null) {
            lightTheme = MyTheme(primaryColor: lightDynamic.primary).lightThemeData;

            darkTheme = MyTheme(primaryColor: darkDynamic.primary).darkThemeData;
          } else {
            lightTheme = MyTheme(primaryColor: themeColor).lightThemeData;

            darkTheme = MyTheme(primaryColor: themeColor).darkThemeData;
          }

          final themeMode = AppConsts.themeModes[SettingsService.to.theme.themeModeName.v]!;

          final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;

          final ThemeData currentTheme;

          switch (themeMode) {
            case ThemeMode.dark:
              currentTheme = darkTheme;
              break;

            case ThemeMode.light:
              currentTheme = lightTheme;
              break;

            case ThemeMode.system:
              currentTheme = brightness == Brightness.dark ? darkTheme : lightTheme;
              break;
          }

          _debounceThemeChange(currentTheme);

          return GetMaterialApp(
            // The localized title is rendered by CustomTitleBar. A stable
            // application title avoids asking EasyLocalization for a key
            // before its delegate has completed the first load.
            title: i18n('app_name'),

            scrollBehavior: MyCustomScrollBehavior(),

            debugShowCheckedModeBanner: false,

            themeMode: themeMode,

            theme: lightTheme.copyWith(
              appBarTheme: const AppBarTheme(surfaceTintColor: Colors.transparent),
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: <TargetPlatform, PageTransitionsBuilder>{
                  TargetPlatform.android: AndroidMaterialPageTransitionsBuilder(),
                  TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
                },
              ),
            ),

            darkTheme: darkTheme.copyWith(
              appBarTheme: const AppBarTheme(surfaceTintColor: Colors.transparent),
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: <TargetPlatform, PageTransitionsBuilder>{
                  TargetPlatform.android: AndroidMaterialPageTransitionsBuilder(),
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
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(currentFactor)),
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
