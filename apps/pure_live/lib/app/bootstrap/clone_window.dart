import 'dart:async' show unawaited;
import 'dart:io' show Directory;

import 'package:desktop_multi_window/desktop_multi_window.dart' show WindowController;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding, runApp;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor, PlatformBootstrap, PlatformKind;
import 'package:live_shell/live_shell.dart' show ChromeMode, SecondaryWindows, WindowRole;
import 'package:live_shell_desktop/live_shell_desktop.dart'
    show DesktopWindowLauncher, WindowArguments, primaryChromePlan;
import 'package:live_storage/live_storage.dart' show StoragePrefs, StorageStores;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'package:pure_live/app/bootstrap/clone_window_host.dart' show CloneWindowChannel, CloneWindowHost;
import 'package:pure_live/app/bootstrap/pure_live_app.dart' show PureLiveApp;
import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/app/providers/download_directory_provider.dart'
    show defaultDownloadRoot, fontsRootOf, refreshCloudFontSnapshot;
import 'package:pure_live/app/providers/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/app/providers/player_providers.dart' show primePlayerEngine;
import 'package:pure_live/app/providers/storage_providers.dart' show storagePathsProvider;
import 'package:pure_live/app/providers/user_notification_providers.dart' show enableUserNotifications;
import 'package:pure_live/app/providers/window_providers.dart'
    show
        isPrimaryWindowProvider,
        presentationWindowHandleProvider,
        secondaryWindowsProvider,
        windowCloseProvider,
        windowHostProvider,
        windowIdProvider,
        windowInvokePrimaryProvider;
import 'package:pure_live/app/providers/window_storage_bridge.dart'
    show WindowStorageClient, windowStorageBridgeProvider;
import 'package:pure_live/app/routing/app_router.dart' show windowInitialRouteProvider;
import 'package:pure_live/app/routing/route_names.dart' show RouteNames;
import 'package:pure_live/app/theme/fonts/font_library.dart' show CloudFontIds, FontLibrary;
import 'package:pure_live/app/theme/system_accent_color.dart' show preloadSystemAccent;
import 'package:pure_live/app/window_chrome.dart' show WindowChromeState;
import 'package:pure_live/infrastructure/storage/storage_paths.dart' show StoragePaths;
import 'package:pure_live/shared/images/app_image_cache.dart' show installWindowImageCache, prepareImageCache;

/// Runs a full application clone: the same router, pages and settings as
/// the primary window, but without SQLite. The clone's StorageStores is a
/// remote projection fed by the primary's snapshots and change broadcasts.
Future<void> runCloneWindow(String rawArguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  final runtime = PlatformBootstrap.init(appNamespace: 'pure_live', formFactor: FormFactor.desktop);
  final log = appLog.forCategory('clone window');
  final arguments = WindowArguments.fromRaw(rawArguments);
  final route = arguments.route ?? RouteNames.popular;
  final window = CloneWindowChannel();
  final host = CloneWindowHost(role: WindowRole.panel);
  unawaited(window.setTitle('Pure Live'));

  // The primary is the only database owner. A clone that cannot find it
  // has no data; close instead of showing an app whose stores are empty.
  WindowController? primary;
  try {
    for (final controller in await WindowController.getAll()) {
      if (WindowArguments.fromRaw(controller.arguments).role == WindowRole.main) {
        primary = controller;
        break;
      }
    }
  } on Object catch (error, stackTrace) {
    log.warning('the primary window could not be found', fields: {'error': '$error', 'stack': '$stackTrace'});
  }
  if (primary == null) {
    log.warning('clone window started without a primary');
    await window.close();
    return;
  }

  Future<Object?> invokePrimary(String method, [Object? arguments]) async {
    final target = primary!;
    for (var attempt = 0; ; attempt++) {
      try {
        return await target.invokeMethod<Object>(method, arguments);
      } on Object catch (error) {
        if (attempt >= 4) {
          log.warning('$method did not reach the primary', fields: {'error': '$error'});
          return null;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  final storagePaths = await StoragePaths.resolve(environment: runtime.environment, log: log);
  // The same synchronous cloud font snapshot the primary boot takes: a
  // clone validates the projected family the same way and registers it
  // from the shared folder for its own isolate.
  CloudFontIds.replace(
    FontLibrary.scanInstalledRoots([
      Directory(p.join(storagePaths.data.path, 'fonts')),
      fontsRootOf(defaultDownloadRoot(storagePaths)),
    ]),
  );
  try {
    // The remote projection exists before anything is read; its namespaces
    // open lazily. Setting it up first also means a broadcast that lands
    // during the boot has a store to wait on rather than a null instance.
    await StorageStores.attachRemote(WindowStorageClient(invokePrimary));
  } on Object catch (error, stackTrace) {
    log.warning('clone storage could not attach', fields: {'error': '$error', 'stack': '$stackTrace'});
    await window.close();
    return;
  }

  // The clone draws the same strip as the primary. The runner channel dresses
  // its own window on every desktop: Windows strips the caption bits, macOS
  // hides the title and extends the content view, and GTK drops the
  // window-manager decoration.
  final kind = runtime.environment.runtime.kind;
  final plan = primaryChromePlan(kind);
  WindowChromeState.mode = plan.mode;
  await window.setChrome(custom: plan.mode != ChromeMode.nativeCaption);

  // The presentation drivers pin this window's native handle; their
  // process-wide lookup would find the primary. Null on desktop window
  // systems without handles, where the drivers' own backends resolve the
  // active window.
  final nativeHandle = await window.hwnd();
  if (kind == PlatformKind.windows && nativeHandle == null) {
    // A pinned zero makes the presentation backends degrade instead of
    // taking the primary fullscreen; report why the buttons do nothing.
    log.warning('clone window handle unavailable; fullscreen and PiP are disabled');
  }

  // The media hub in the primary addresses this window by id; the reporter
  // needs that same id for every claim and release.
  String? selfWindowId;
  for (var attempt = 0; attempt < 5 && selfWindowId == null; attempt++) {
    try {
      selfWindowId = (await WindowController.fromCurrentEngine()).windowId;
    } on Object catch (error) {
      if (attempt >= 4) {
        log.warning('clone window id unavailable', fields: {'error': '$error'});
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    }
  }

  // The container is built before the first frame so the change channel is
  // armed before the settings snapshot is taken. A change committed while
  // a namespace is still opening is buffered by the remote stores, so the
  // clone cannot miss a write made during its boot.
  final container = ProviderContainer(
    overrides: [
      platformRuntimeProvider.overrideWithValue(runtime),
      secondaryWindowsProvider.overrideWithValue(SecondaryWindows(launcher: DesktopWindowLauncher())),
      isPrimaryWindowProvider.overrideWithValue(false),
      windowCloseProvider.overrideWithValue(host.close),
      windowHostProvider.overrideWithValue(host),
      presentationWindowHandleProvider.overrideWithValue(nativeHandle),
      windowIdProvider.overrideWithValue(selfWindowId),
      windowInvokePrimaryProvider.overrideWithValue(invokePrimary),
      windowInitialRouteProvider.overrideWithValue(route),
      storagePathsProvider.overrideWithValue(storagePaths),
    ],
  );
  try {
    await container.read(windowStorageBridgeProvider).register();
    await StoragePrefs.init();
    // A custom download folder moves the fonts with it; the pre-prefs scan
    // above could not know the choice, so fold its families in now.
    refreshCloudFontSnapshot();
  } on Object catch (error, stackTrace) {
    // The primary's bridge may not be armed yet, or it refused the snapshot.
    // An app whose stores are empty is worse than a window that goes away.
    log.warning('clone storage could not attach', fields: {'error': '$error', 'stack': '$stackTrace'});
    container.dispose();
    await window.close();
    return;
  }
  log.info('clone storage ready', fields: {'route': route, 'settings': '${StoragePrefs.snapshot().length}'});

  primePlayerEngine();
  // The primary owns the process-wide SMTC session; a second engine cannot
  // initialize another one. A clone's playback remains audible and local.
  unawaited(enableUserNotifications());
  try {
    await preloadSystemAccent();
  } on Object {
    // No accent on this platform; the theme's own seed stands.
  }
  await prepareImageCache();
  try {
    final temp = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final name = '${_safeId(arguments.route ?? 'home')}-$stamp';
    await installWindowImageCache(Directory(p.join(temp.path, 'pure_live_window_cache', name)));
  } on Object {
    // A cache folder that cannot be created costs images their disk copy.
  }

  log.info('clone window started', fields: {'route': route, 'hwnd': '$nativeHandle'});
  runApp(UncontrolledProviderScope(container: container, child: const PureLiveApp()));
}

String _safeId(String raw) => raw.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
