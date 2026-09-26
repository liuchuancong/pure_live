import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pure_live/common/global/initialized.dart';
import 'package:material_ui/material_ui.dart' as material;
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/routes/navigation_observer.dart';
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/routes/route_observer_controller.dart';
import 'package:pure_live/common/utils/shared_media_intake.dart';
import 'package:pure_live/player/utils/popup_route_tracker.dart';
import 'package:pure_live/common/utils/share_command_handler.dart';
import 'package:pure_live/common/utils/shared_live_link_opener.dart';
import 'package:pure_live/core/iptv/services/epg_import_manager.dart';
import 'package:pure_live/common/global/platform/desktop_manager.dart';
import 'package:pure_live/core/iptv/services/iptv_import_manager.dart';
import 'package:pure_live/common/services/settings/player_settings_controller.dart';

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
  SharedMediaReceiver? _sharedMediaReceiver;
  bool _dynamicThemeChangeScheduled = false;

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
    final String validKey = normalizeVideoPlayerKeyForPlatform(savedKey, defaultTargetPlatform);
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
    final receiver = _sharedMediaReceiver;
    if (receiver != null) unawaited(receiver.dispose());
    unawaited(GlobalPlayerService.instance.dispose());
    super.dispose();
  }

  Future<void> initSharedMediaListener() async {
    if (!Platform.isAndroid) return;

    final handler = ShareHandler.instance;
    final intake = SharedMediaIntake(
      isRoomCommand: ShareCommandHandler.isUsableCommand,
      consumeRoomCommand: handleIncomingShareCommand,
      importPlaylist: (path) => IptvImportManager().importFromSharedMedia(SharedMedia(content: path)),
      importEpg: (path) => EpgImportManager().importFromSharedMedia(SharedMedia(content: path)),
      releaseAttachment: (path) async {
        await FileUtils.cleanupOwnedSharedMediaFile(File(path));
      },
      notifyUnsupported: (key) => ToastUtil.show(i18n(key)),
      isLiveLink: SharedLiveLinkOpener.containsLiveLink,
      openLiveLink: SharedLiveLinkOpener(waitForNavigator: waitForShareNavigator).open,
      reportError: (error, stackTrace) => debugPrint('Shared media receiver failed: $error\n$stackTrace'),
    );
    final receiver = SharedMediaReceiver(
      readInitialMedia: handler.getInitialSharedMedia,
      resetInitialMedia: handler.resetInitialSharedMedia,
      mediaStream: handler.sharedMediaStream,
      intake: intake,
      reportError: (error, stackTrace) => debugPrint('Shared media channel failed: $error\n$stackTrace'),
    );
    _sharedMediaReceiver = receiver;
    await receiver.start();
  }

  void _applyDynamicTheme(
    material.ColorScheme? lightDynamic,
    material.ColorScheme? darkDynamic,
    ThemeData lightThemeData,
    ThemeData darkThemeData,
  ) {
    if (_dynamicThemeChangeScheduled) {
      return;
    }

    _dynamicThemeChangeScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dynamicThemeChangeScheduled = false;

      if (!mounted) {
        return;
      }

      final brightness = Theme.of(context).brightness;

      if (SettingsService.to.theme.enableDynamicTheme.v && lightDynamic != null && darkDynamic != null) {
        final scheme = brightness == Brightness.dark
            ? toFlutterColorScheme(darkDynamic)
            : toFlutterColorScheme(lightDynamic);

        final theme = MyTheme(colorScheme: scheme);

        Get.changeTheme(brightness == Brightness.dark ? theme.darkThemeData : theme.lightThemeData);
      } else {
        Get.changeTheme(brightness == Brightness.dark ? darkThemeData : lightThemeData);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return Obx(() {
          final themeColor = SettingsService.to.theme.themeColor;
          final showSplashPage = SettingsService.to.app.showSplashPage.v;
          final currentFactor = SettingsService.to.font.textScaleFactor.v;

          ThemeData lightTheme;
          ThemeData darkTheme;

          if (SettingsService.to.theme.enableDynamicTheme.v && lightDynamic != null && darkDynamic != null) {
            lightTheme = MyTheme(colorScheme: toFlutterColorScheme(lightDynamic)).lightThemeData;
            darkTheme = MyTheme(colorScheme: toFlutterColorScheme(darkDynamic)).darkThemeData;
          } else {
            lightTheme = MyTheme(primaryColor: themeColor).lightThemeData;
            darkTheme = MyTheme(primaryColor: themeColor).darkThemeData;
          }
          _applyDynamicTheme(lightDynamic, darkDynamic, lightTheme, darkTheme);

          return GetMaterialApp(
            // The localized title is rendered by CustomTitleBar. A stable
            // application title avoids asking EasyLocalization for a key
            // before its delegate has completed the first load.
            title: i18n('app_name'),
            navigatorKey: appNavigatorKey,
            scrollBehavior: MyCustomScrollBehavior(),
            debugShowCheckedModeBanner: false,
            themeMode: SettingsService.to.theme.themeMode,
            theme: lightTheme.copyWith(
              appBarTheme: const AppBarTheme(surfaceTintColor: Colors.transparent),
              pageTransitionsTheme: appPageTransitionsTheme,
            ),
            darkTheme: darkTheme.copyWith(
              appBarTheme: const AppBarTheme(surfaceTintColor: Colors.transparent),
              pageTransitionsTheme: appPageTransitionsTheme,
            ),
            locale: context.locale,
            navigatorObservers: [FlutterSmartDialog.observer, LiveRouteObserver(), PopupRouteTracker.instance],
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
                  child: MaterialUiThemeBridge(child: resultWidget),
                );
              },
            ),
            supportedLocales: context.supportedLocales,
            localizationsDelegates: [
              ...context.localizationDelegates,
              // flex_color_picker 4.x and cached_network_image 4.x use the
              // decoupled Material library. Its localization type is distinct
              // from flutter/material.dart and must be registered alongside it.
              material.GlobalMaterialLocalizations.delegate,
            ],
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
