import 'dart:async' show unawaited;
import 'dart:io' show Directory, exit;

import 'package:desktop_multi_window/desktop_multi_window.dart' show WindowController, onWindowsChanged;
import 'package:flutter/services.dart' show MethodChannel, MissingPluginException;
import 'package:flutter/widgets.dart';
import 'package:live_log/live_log.dart' show ErrorReporter, LiveLog;
import 'package:live_platform/live_platform.dart' show FormFactor, PlatformBootstrap, PlatformKind, PlatformRuntime;
import 'package:live_shell/live_shell.dart'
    show
        ChromePlan,
        ChromeStage,
        CloseAction,
        DesktopShell,
        RenderFallbacks,
        SecondaryWindows,
        ShellSettings,
        TrayAction,
        TrayDivider,
        TrayEntry,
        TrayIconState,
        WindowHost,
        WindowRole;
import 'package:live_shell_desktop/live_shell_desktop.dart'
    show
        DesktopWindowLauncher,
        TrayManagerHost,
        WindowManagerHost,
        configureMainWindow,
        primaryChromePlan,
        reapplyMainWindowChrome;
import 'package:live_storage/live_storage.dart'
    show StorageBootstrap, StoragePathProvider, StoragePrefs, StorageStores;
import 'package:path/path.dart' as p;
import 'package:pure_live/app/logging/app_log.dart' show appLog, initAppLog;
import 'package:pure_live/app/providers/media_session_providers.dart' show enableMediaSession;
import 'package:pure_live/app/providers/player_providers.dart' show primePlayerEngine;
import 'package:pure_live/app/providers/user_notification_providers.dart' show enableUserNotifications;
import 'package:pure_live/app/providers/window_storage_bridge.dart' show WindowStorageMethods;
import 'package:pure_live/app/routing/root_navigator.dart' show rootNavigatorKey;
import 'package:pure_live/app/theme/system_accent_color.dart' show preloadSystemAccent;
import 'package:pure_live/app/window_chrome.dart' show WindowChrome, WindowChromeState;
import 'package:pure_live/app/window_close_dialog.dart' show showCloseWindowDialog;
import 'package:pure_live/infrastructure/storage/storage_paths.dart' show StoragePaths;
import 'package:pure_live/l10n/translations.dart' show t;
import 'package:pure_live/shared/images/app_image_cache.dart' show prepareImageCache;

/// What one process boot produced: the platform snapshot, the resolved
/// storage layout and, on a desktop form factor, the main window's host
/// with its close policy armed and the secondary-window set the shell
/// dismisses on quit.
final class Boot {
  /// A completed boot.
  const Boot({required this.runtime, required this.windowHost, required this.storagePaths, this.secondaryWindows})
    : error = null;

  /// A failed boot; [error] is what the wiring threw.
  const Boot.failure({required this.runtime, required this.error})
    : windowHost = null,
      storagePaths = null,
      secondaryWindows = null;

  /// The platform facts and capabilities.
  final PlatformRuntime runtime;

  /// The main window's host, or null where the form factor has no window
  /// to host (a phone, a tablet, a TV).
  final WindowHost? windowHost;

  /// The resolved storage layout; null only on a failed boot.
  final StoragePaths? storagePaths;

  /// The desktop's secondary windows (the room windows), or null off the
  /// desktop. The room opener and the shell's quit path share it.
  final SecondaryWindows? secondaryWindows;

  /// The failure, when [storagePaths] is null.
  final Object? error;

  /// Whether the boot failed and the error screen must show instead.
  bool get failed => storagePaths == null;
}

/// Boots everything the widget tree cannot build lazily: the platform
/// layer, the log tree, the accent preload, the desktop window's dress and
/// its host with the close policy, the storage layout, and — best-effort —
/// the SQLite storage over it.
///
/// A failure here is fatal — the startup error screen replaces the app,
/// because a half-initialised shell is worse than a visible failure.
Future<Boot> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A TV build is chosen at build time (`--dart-define=PURE_LIVE_TV=true`
  // on the leanback package): the leanback launcher cannot reach a touch
  // UI, so the shell must come up in its TV shape from the first frame.
  final runtime = PlatformBootstrap.init(
    appNamespace: 'pure_live',
    // The null branch keeps the platform's own answer (the lint knows the
    // parameter default; the ternary stays because the TV side is not a
    // literal default).
    // ignore: avoid_redundant_argument_values
    formFactor: const bool.fromEnvironment('PURE_LIVE_TV') ? FormFactor.tv : null,
  );
  final log = appLog;
  final bootLog = log.forCategory('boot');

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorReporter.report(log.forCategory('errors'), details.exception, details.stack, message: 'framework error');
  };
  // Async errors outside a widget's zone would otherwise only reach the
  // console; they belong in the same diagnostic stream.
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    log.forCategory('errors').error('uncaught asynchronous error', error: error, stackTrace: stack);
    return true;
  };

  try {
    // The accent read is asynchronous and the theme pair is built from it,
    // so it lands before the first frame instead of recolouring afterwards.
    unawaited(preloadSystemAccent());
    // The player's native engine loads once, before any room asks for it;
    // the OS playback surfaces (SMTC, the Android notification) arm right
    // after — a failure here only costs the controls, never the app.
    primePlayerEngine();
    unawaited(enableMediaSession());
    // Job outcomes (a finished or failed recording) reach the system tray;
    // the permission is asked when a job starts, not here.
    unawaited(enableUserNotifications());
    final formFactor = runtime.environment.runtime.formFactor;
    // The storage bootstrap comes first: the window's caption style is one
    // of its preferences, and the caption is dressed once, at creation.
    final storagePaths = await StoragePaths.resolve(environment: runtime.environment, log: bootLog);
    // The storage layer is best-effort: a failure logs and the boot carries
    // on — browsing works without storage, and the providers fall back to
    // their defaults when the SQLite database never opened.
    try {
      final storageBootstrap = StorageBootstrap(
        pathProvider: StoragePathProvider(resolver: () async => storagePaths.data.path),
      );
      await storageBootstrap.initialize();
      await StoragePrefs.init();
      initAppLog(directory: Directory(p.join(storagePaths.data.path, 'logs')));
      bootLog.info('storage ready', fields: {'data': storagePaths.data.path});
    } on Object catch (error, stackTrace) {
      log.forCategory('storage').error('storage bootstrap failed', error: error, stackTrace: stackTrace);
    }
    // Network images need their cache folder before the first frame; the
    // folder is independent of whether the data store opened.
    await prepareImageCache();
    WindowHost? windowHost;
    SecondaryWindows? secondaryWindows;
    if (formFactor == FormFactor.desktop) {
      // The window is dressed before the first frame: the caption style —
      // the system's own or the app's self-drawn strip — is a creation-time
      // choice, not a live one. Windows offers both; macOS keeps the
      // system's traffic lights inset in the app's bar, Linux draws its
      // whole strip either way.
      final kind = runtime.environment.runtime.kind;
      final chrome = WindowChromeState.readStored();
      final plan = kind == PlatformKind.windows
          ? ChromePlan.select(
              platform: kind,
              stage: chrome == WindowChrome.custom ? ChromeStage.seamlessSelfDrawn : ChromeStage.nativeFirst,
            )
          : primaryChromePlan(kind);
      WindowChromeState.chrome = chrome;
      WindowChromeState.mode = plan.mode;
      await configureMainWindow(
        plan: plan,
        role: WindowRole.main,
        minimumSize: const Size(300, 600),
        fallbacks: const RenderFallbacks(),
        title: 'Pure Live',
        background: const Color(0xFF101418),
      );
      // A boot that raced the plugin's window registration would otherwise
      // leave the native caption under the app's own strip, and the default
      // runner title in the taskbar. Re-apply after the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(reapplyMainWindowChrome(plan: plan, title: 'Pure Live'));
      });
      // The identity oracle exists on Windows only, where the native layer
      // keeps a NativeAPIWindowId property the runner can read back.
      // macOS and Linux pass null: their hosts pin on the first focus,
      // which is correct in every release run — the primary takes focus at
      // startup, before any clone can exist — and can only miss across a
      // hot restart with a clone focused, a development-only flow. Wiring
      // the channel there anyway would answer "not ours" forever and leave
      // the primary's close button dead.
      final oracle = kind == PlatformKind.windows ? _verifyPrimaryWindowId : null;
      final host = WindowManagerHost(role: WindowRole.main, verifyOwnWindow: oracle)..attach();
      windowHost = host;
      // The room windows: one launcher for the whole process, so the shell's
      // quit path and the room opener see the same set.
      secondaryWindows = SecondaryWindows(launcher: DesktopWindowLauncher());
      // The shell arms its own close interception inside `start`, after the
      // tray has had its chance to come up: whether a close may hide depends
      // on an icon existing to bring the window back.
      await _wireDesktopShell(host: host, platform: kind, log: log.forCategory('shell'), windows: secondaryWindows);
    }
    return Boot(
      runtime: runtime,
      windowHost: windowHost,
      storagePaths: storagePaths,
      secondaryWindows: secondaryWindows,
    );
  } on Object catch (error, stackTrace) {
    bootLog.fatal('boot failed', error: error, stackTrace: stackTrace);
    return Boot.failure(runtime: runtime, error: error);
  }
}

/// Wires the desktop shell: the tray, the close policy and the quit path all
/// live in `live_shell`'s [DesktopShell]; this only hands it the OS pieces
/// and the stored choices.
///
/// The shell re-reads the close choice on every press ([storedCloseAction]),
/// so a change in the settings applies to the very next press without the
/// shell hearing about it. The menu labels, in contrast, are frozen into the
/// native menu until the next [DesktopShell.refreshTray] — a locale switch
/// lands on the next interaction with the tray, not instantly.
Future<void> _wireDesktopShell({
  required WindowHost host,
  required PlatformKind platform,
  required LiveLog log,
  required SecondaryWindows windows,
}) async {
  final tray = TrayManagerHost(iconAssets: const {TrayIconState.idle: 'assets/tray/pure_live_22.png'});
  // Set when closing the primary was turned into a hide because another
  // window existed. Once the last peer goes away, the app would have no
  // visible window at all; bring the primary back instead of leaving the
  // process hidden with only a tray icon.
  var hiddenForPeers = false;
  final shell = DesktopShell(
    platform: platform,
    window: host,
    settings: () => ShellSettings(closeAction: storedCloseAction(), dontAskExit: storedDontAskExit()),
    // The close question (the reference's `dontAskExit`): macOS closes the
    // window without ending the app, so there is no quit to confirm there.
    confirmClose: platform == PlatformKind.macos
        ? null
        : ({required tray}) async {
            final context = rootNavigatorKey.currentContext;
            // Before the first frame there is no navigator to ask from; the
            // stored action is still the right answer.
            if (context == null) return (action: storedCloseAction(), remember: storedDontAskExit());
            return await showCloseWindowDialog(context, tray: tray);
          },
    // macOS's close-for-now destroys only the window (the engine stays, the
    // Dock and the tray own the way back), so the shell needs a way to
    // raise it again. On Windows and Linux the destroy really ends the
    // window and the runner quits with it, so this never runs there.
    rebuildWindow: () => host.show(),
    // `destroy` is how this app ends. On Windows and Linux the runner quits
    // when the last window dies; on macOS the process outlives its windows
    // by design, so `exit` ends it for real — and `prepareToQuit` has
    // already torn the tray, the room windows and the subscriptions down by
    // the time `exit` runs.
    exit: () async {
      await host.destroy();
      exit(0);
    },
    tray: tray,
    windows: windows,
    // A clone is a window, not a child of the primary: closing the primary
    // must not take it down. Explicit Quit (dialog or tray) still ends all.
    hasOtherWindows: () async {
      try {
        final others = (await WindowController.getAll()).length > 1;
        if (others) hiddenForPeers = true;
        return others;
      } on Object {
        return false;
      }
    },
    // The tray can open a window while the primary is hidden, which is the
    // one entry point no page can offer.
    onMenuAction: (id) async {
      if (id != 'newWindow') return;
      try {
        await windows.open(role: WindowRole.panel);
      } on Object catch (error, stackTrace) {
        log.warning('a new window could not be opened from the tray', fields: {
          'error': '$error',
          'stack': '$stackTrace',
        });
      }
    },
    // The shell's tracked set only knows windows this engine opened; a room
    // clone can open another clone. Ask every engine directly, then flush
    // the one database before the primary's window goes away.
    beforeQuit: () async {
      await _dismissEveryWindow(log);
      try {
        await StorageStores.closeInstance();
      } on Object catch (error, stackTrace) {
        log.warning('storage could not close on quit', fields: {'error': '$error', 'stack': '$stackTrace'});
      }
    },
    menuEntries: () => <TrayEntry>[
      TrayAction(id: 'show', label: t.settings.trayShow),
      TrayAction(id: 'hide', label: t.settings.trayHide),
      TrayAction(id: 'newWindow', label: t.common.newWindow),
      const TrayDivider(),
      TrayAction(id: 'quit', label: t.settings.closeQuit),
    ],
    tooltip: () => 'Pure Live',
  );
  onWindowsChanged.listen((_) {
    if (!hiddenForPeers) return;
    unawaited(() async {
      try {
        final windows = await WindowController.getAll();
        if (windows.length > 1) return;
        await shell.reveal();
        hiddenForPeers = false;
      } on Object {
        // A failed revival leaves the tray as the way back.
      }
    }());
  });
  await shell.start();
  if (!shell.hasTray) {
    // The close policy has already absorbed the failure (hiding falls back
    // to quitting); the log line is only why the icon is missing.
    log.warning('tray icon unavailable', fields: {'error': '${tray.createError}'});
  }
}

/// Asks every other engine in the process to close.
///
/// The shell's [SecondaryWindows] only knows what this engine opened; a
/// clone opens its own windows through its own set. The process-wide list
/// is the only complete answer, and a window that closed meanwhile simply
/// fails its call.
Future<void> _dismissEveryWindow(LiveLog log) async {
  String? self;
  try {
    self = (await WindowController.fromCurrentEngine()).windowId;
  } on Object {
    // The current engine cannot name itself; ask every window instead.
  }

  final List<WindowController> windows;
  try {
    windows = await WindowController.getAll();
  } on Object catch (error) {
    log.warning('the other windows could not be listed', fields: {'error': '$error'});
    return;
  }

  await Future.wait([
    for (final window in windows)
      if (self == null || window.windowId != self)
        () async {
          try {
            await window
                .invokeMethod<Object>(WindowStorageMethods.dismiss)
                .timeout(const Duration(milliseconds: 800));
          } on Object {
            // Already gone, or its bridge never armed.
          }
        }(),
  ]);
}

/// The runner's identity oracle for the primary window: the Dart host asks
/// whether a candidate window id belongs to this engine's own top-level
/// window, and the runner answers by reading the window's NativeAPIWindowId
/// property — set the moment the native layer first wrapped this window,
/// which is during the boot that precedes any focus event. Armed in the
/// runner's create, which can trail the Dart boot by a beat, hence the
/// brief retry; an unreachable oracle answers "not ours", and the host
/// asks again on the next focus rather than guessing.
Future<bool> _verifyPrimaryWindowId(int windowId) async {
  const channel = MethodChannel('pure_live/primary_window');
  for (var attempt = 0;; attempt++) {
    try {
      return await channel.invokeMethod<bool>('verifyOwnWindow', windowId) ?? false;
    } on MissingPluginException {
      if (attempt >= 5) {
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }
}

/// The stored close choice, read outside the widget tree (the bootstrap
/// has no ref): the storage facade directly, its default on any failure.
CloseAction storedCloseAction() {
  try {
    return switch (StoragePrefs.getString('shell.closeAction')) {
      'minimise' => CloseAction.minimise,
      'hideToTray' => CloseAction.hideToTray,
      'quit' => CloseAction.quit,
      _ => CloseAction.quit,
    };
  } on Object {
    return CloseAction.quit;
  }
}

/// Whether the viewer asked the close button to skip the confirmation.
bool storedDontAskExit() {
  try {
    return StoragePrefs.getBool('shell.dontAskExit') ?? false;
  } on Object {
    return false;
  }
}
