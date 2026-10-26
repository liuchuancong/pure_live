import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor, PlatformKind;
import 'package:live_shell/live_shell.dart' show SecondaryWindows, WindowRole;
import 'package:live_shell_desktop/live_shell_desktop.dart'
    show DesktopWindowRegistry, MultiViewWindowLauncher, primaryChromePlan;
import 'package:multiview_desktop/multiview_desktop.dart'
    show
        CloseMode,
        LogParams,
        MacosPlatformParams,
        MultiAppConfig,
        MultiPlatformParams,
        TitleBarStyle,
        ViewAnimationConfig,
        WindowObserver,
        WindowOptions,
        runMultiApp;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart' show TranslationProvider;

/// The process entry point.
///
/// Every desktop window is a view in this one engine and this one isolate:
/// `runMultiApp` owns the window collection, the boot happens once, and the
/// shared `ProviderContainer` carries settings, storage and follows to every
/// view. Each view adds its own child scope for identity, router, player and
/// room state (see `AppWindowRoot`).
///
/// Phones and TVs keep the single-window `runApp` path: there is no OS window
/// collection to orchestrate there, and the multiview plugin's runners exist
/// only on the desktop.
Future<void> main(List<String> arguments) async {
  final boot = await bootstrap();
  if (boot.failed) {
    runApp(StartupErrorPage(error: boot.error!));
    return;
  }
  final runtime = boot.runtime;
  if (runtime.environment.runtime.formFactor != FormFactor.desktop) {
    runApp(
      TranslationProvider(
        child: ProviderScope(
          overrides: [
            platformRuntimeProvider.overrideWithValue(runtime),
            storagePathsProvider.overrideWithValue(boot.storagePaths!),
          ],
          child: const PureLiveApp(),
        ),
      ),
    );
    return;
  }
  _runDesktop(boot);
}

/// Starts the desktop shell's window collection. Never returns.
void _runDesktop(Boot boot) {
  final runtime = boot.runtime;
  final kind = runtime.environment.runtime.kind;
  final mac = kind == PlatformKind.macos;
  // Every desktop window draws its own strip; macOS keeps the system's
  // traffic lights inset in that strip, Windows and Linux draw the buttons.
  WindowChromeState.mode = primaryChromePlan(kind).mode;

  final registry = DesktopWindowRegistry();
  final windows = SecondaryWindows(
    launcher: MultiViewWindowLauncher(
      registry: registry,
      pageBuilder: (context, record) => AppWindowRoot.fromRecord(record),
    ),
  );
  final container = ProviderContainer(
    overrides: [
      platformRuntimeProvider.overrideWithValue(runtime),
      storagePathsProvider.overrideWithValue(boot.storagePaths!),
      desktopWindowRegistryProvider.overrideWithValue(registry),
      secondaryWindowsProvider.overrideWithValue(windows),
    ],
  );

  const mainSize = Size(1280, 800);
  const minimumSize = Size(300, 600);
  const background = Color(0xFF101418);
  runMultiApp(
    home: (context, id) =>
        AppWindowRoot(viewId: id, role: WindowRole.main, initialRoute: const PopularRoute().location),
    // One provider for the whole engine: slang keys `TranslationProvider`
    // with a process-wide GlobalKey, so each window building its own copy
    // would put the same key in two places. Above `ViewCollection` it is the
    // single ancestor every view reads.
    globalScope: (child) => UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(child: child),
    ),
    config: MultiAppConfig(
      generalParams: const MultiPlatformParams(
        // The primary's close goes through `DesktopShell`: it decides hide,
        // minimise or quit from the stored choice and the remaining windows.
        // Secondaries only ever close themselves.
        // ignore: experimental_member_use
        closeMode: CloseMode.none,
        // The process lifetime belongs to the shell and its tray: the quit
        // path is what ends it, on every platform.
        closeAppAfterLastWindowClosed: false,
        // Windows draws the plugin's fade by making the window layered for
        // the duration; a layered window cannot composite Flutter's child
        // surface, so the window reads as black while it animates. The app
        // owns its own chrome and transitions, so the native fade is off.
        animation: ViewAnimationConfig.disabled,
      ),
      macosParams: const MacosPlatformParams(saveLastWindowToReopen: false),
      mainWindowOptions: WindowOptions(
        size: mainSize,
        minimumSize: minimumSize,
        titleBarStyle: TitleBarStyle.hidden,
        // macOS's traffic lights stay; the other platforms draw the caption.
        windowButtonVisibility: mac,
        title: 'Pure Live',
        backgroundColor: background,
      ),
      globalWindowOptions: WindowOptions(
        size: const Size(900, 620),
        minimumSize: const Size(520, 380),
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: mac,
        title: 'Pure Live',
        backgroundColor: background,
      ),
      // A debug run keeps the plugin's own log (`%LOCALAPPDATA%/multiview_desktop/
      // logs/mvd.log`): it is the only place the native view ids and the
      // shell/animation decisions are written down when a window misbehaves.
      fileLogParams: kDebugMode ? const LogParams(enable: true) : const LogParams(),
      observers: [_WindowRegistryObserver(registry: registry, windows: windows)],
    ),
  );
}

/// Keeps the process's window table honest when a view goes away.
final class _WindowRegistryObserver extends WindowObserver {
  _WindowRegistryObserver({required this.registry, required this.windows});

  final DesktopWindowRegistry registry;
  final SecondaryWindows windows;

  @override
  void onWindowClosed(int viewId) {
    registry.remove(viewId);
    windows.noteGone('$viewId');
  }
}
