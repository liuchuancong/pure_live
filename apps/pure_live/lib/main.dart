import 'dart:async' show unawaited;
import 'dart:io' show Platform, exit;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_log/live_log.dart' show ErrorReporter;
import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart' show CommandStartupRegistration;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/app/app_providers.dart';
import 'package:pure_live/app/app_services.dart';
import 'package:pure_live/app/icons/app_icon_registry.dart';
import 'package:pure_live/features/account/douyu_login_store.dart' show douyuLoginStoreProvider;
import 'package:pure_live/platforms/desktop/entry/desktop_entry.dart';
import 'package:pure_live/platforms/desktop/entry/desktop_launch.dart';
import 'package:pure_live/shared/in_app_web.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_live/system/logging/app_log.dart';
import 'package:pure_live/system/playback/playback_engine.dart';
import 'package:pure_live/system/playback/playback_surfaces.dart';
import 'package:pure_live/system/theme/app_theme.dart';
import 'package:pure_live/system/theme/ui_configuration_mapper.dart';
import 'package:pure_uikit/pure_uikit.dart' show PureDesignLanguage, PureUiStartupResolver;

/// The process entry point: open the log, boot the service graph, then hand
/// it to the widget tree through `ProviderScope` overrides.
///
/// The log opens first — a boot failure needs somewhere to land — and the
/// framework and zone error hooks report through it. This is the only place
/// composition happens; nothing below the scope reads `AppServices`
/// directly, so a second window can boot its own graph through the same
/// door.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final log = AppLog();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorReporter.report(
      log.forCategory('flutter'),
      details.exception,
      details.stack,
      message: 'framework error',
      // The widget chain is what names the offender; the exception alone says a
      // row overflowed and the stack ends in the framework.
      fields: {'tree': details.context?.toDescription().trim() ?? ''},
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorReporter.report(log.forCategory('uncaught'), error, stack);
    return true;
  };

  // The single-instance lock is the first thing a desktop launch takes: a
  // second launch that reached the data tree would fight the running
  // instance over its box locks. A forwarded launch exits here, having
  // already handed its request to whoever holds the port.
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    ensureMediaEngineInitialized();
  }

  final onDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  final channel = onDesktop ? await acquireDesktopInstance(log: log.root, args: args) : null;
  if (onDesktop && channel == null) {
    // Handed over — this process was only ever a messenger. Nothing past
    // the log has been initialised, so a plain exit loses nothing; a bare
    // return would leave the engine, and the process, alive.
    exit(0);
  }

  final services = await AppServices.boot(log: log);

  // A09.8: web search runs in the app where webview_flutter ships a plugin
  // (Android/iOS/macOS); elsewhere the page hands the search to the system
  // browser. Detection cannot fail, but it stays out of the boot's own
  // error path.
  InAppWeb.available = await InAppWeb.detect();

  // The desktop window's life starts before the first frame (size, title,
  // tray, close interception) and its quit runs the app's own shutdown.
  DesktopEntry? desktopEntry;
  final kind = services.environment.runtime.kind;
  if (kind == PlatformKind.windows || kind == PlatformKind.macos || kind == PlatformKind.linux) {
    desktopEntry = DesktopEntry(
      kind: kind,
      onQuitRequest: () async {
        await channel?.dispose();
        await services.shutdown();
      },
      preferences: services.shell,
      // The frame mode is decided from this plus the launch arguments, both read
      // in Dart before the window is dressed — `resolveWindowChrome` is the only
      // list of rules now, where the runner used to keep a second copy of it.
      launchArguments: args,
      appPreferences: services.appPreferences,
      log: log.forCategory('shell'),
    );
    await desktopEntry.prepare();
    // A title-bar change is still a next-start change: `desktopEntry.windowChrome`
    // is resolved once and the live window keeps the frame it was given. Nothing
    // has to carry the choice across the restart any more — the store it is read
    // from is the same store the next start reads — so the settings screen offers
    // the restart rather than a mirror file pretending to be one.
    // The purelive scheme this build answers (`purelive://room?...`) is
    // claimed per user, best effort — a refusal only means the deep link
    // stays unregistered, and must not hold the start up or fail it.
    unawaited(registerDesktopSchemes(kind: kind, log: log.root));
  }

  // A debug build can pin the design language for one run with
  // `--ui-language=<id>` (`flutter run -d windows -a --ui-language=fluent`).
  // The language decides the app host and the shell, so this is how a language
  // gets checked on a real device: without it the only way in was the persisted
  // appearance box, which the user then has to un-pick. A release never reads the
  // argument — what the user chose is the whole answer there.
  final pinnedLanguage = kDebugMode ? _pinnedLanguageFrom(args) : null;

  // The global icon registry is installed before the first frame, exactly
  // once: pages name semantic keys and never an icon font, and the tiers
  // (platform override → language → global backstop) answer them.
  AppIcons.install();

  // media_core's own playback surfaces, turned on before the first window so
  // its media-session driver is installed before any room's PlayerKernel is
  // built (a cold-start deep link can open a room immediately). Best effort:
  // the call swallows a platform that refuses (web, no Android audio_service
  // manifest), and an unregistered Windows toast identity simply reports false.
  await enablePlaybackSurfaces();

  // The design language is decided here and never again: it picks which app
  // host gets mounted, and a host is not swapped inside a running process. The
  // appearance document is already loaded (`AppServices.boot` awaited it), so
  // the store, the pin and the product default resolve to one frozen value
  // that the rest of the tree reads through `uiStartupConfigProvider`. Picking
  // another language in settings writes the document and waits for the next
  // launch.
  final startupUi = PureUiStartupResolver.resolve(
    defaultLanguage: defaultDesignLanguage,
    storedLanguageId: services.appearance.value.designLanguageId,
    decode: designLanguageByStoredId,
    launchPin: pinnedLanguage,
  );
  runApp(
    ProviderScope(
      overrides: [
        uiStartupConfigProvider.overrideWithValue(startupUi),
        environmentProvider.overrideWithValue(services.environment),
        pathsProvider.overrideWithValue(services.paths),
        storageProvider.overrideWithValue(services.storage),
        sitesProvider.overrideWithValue(services.sites),
        // The same renewal store the douyu adapter was built over, so the
        // cookie page reads and writes what the requests renew through.
        douyuLoginStoreProvider.overrideWithValue(services.sites.douyuLogin),
        appLogProvider.overrideWithValue(log),
        followRepositoryProvider.overrideWithValue(services.followRepository),
        followAreaRepositoryProvider.overrideWithValue(services.followAreaRepository),
        historyRepositoryProvider.overrideWithValue(services.historyRepository),
        iptvLibraryProvider.overrideWithValue(services.iptvLibrary),
        iptvPreferencesStoreProvider.overrideWithValue(services.iptvPreferences),
        multiviewPreferencesStoreProvider.overrideWithValue(services.multiviewPreferences),
        fontLibraryProvider.overrideWithValue(services.fontLibrary),
        appearanceStoreProvider.overrideWithValue(services.appearance),
        shellPreferencesProvider.overrideWithValue(services.shell),
        appPreferencesStoreProvider.overrideWithValue(services.appPreferences),
        // The single-instance channel is the door a second desktop launch's
        // request arrives through; the router subscribes to it and pushes
        // the room or route the request asked for (deep_link).
        if (channel != null) desktopInstanceChannelProvider.overrideWithValue(channel),
        // A request acts only after the window is on screen; the desktop
        // entry owns the show-and-focus path.
        if (desktopEntry != null) revealMainWindowProvider.overrideWithValue(desktopEntry.show),
        // This run's frame, as the native layer actually set it up — not the
        // stored preference, which may already name the mode for the next start.
        if (desktopEntry != null) windowChromeProvider.overrideWithValue(desktopEntry.windowChrome),
        // 开机自启 needs the OS verb — the registry entry, the autostart file,
        // the Login Items record — which only a desktop run can write.
        if (desktopEntry != null)
          startupRegistrationProvider.overrideWithValue(
            CommandStartupRegistration(
              platform: kind,
              executablePath: Platform.resolvedExecutable,
              registryValueName: 'PureLive',
              displayName: 'Pure Live',
              arguments: Platform.executableArguments,
            ),
          ),
        // The tray's recording row: the recorder reports its live count to
        // the desktop entry, which forwards it to the icon's menu and hint.
        if (desktopEntry != null) desktopTrayPortProvider.overrideWithValue(desktopEntry),
        // The countdown close exits through the desktop shell's own quit —
        // the graceful path that runs the app shutdown and destroys the
        // window — and through the framework's navigator pop elsewhere.
        appQuitProvider.overrideWithValue(desktopEntry == null ? SystemNavigator.pop : desktopEntry.quit),
      ],
      child: const AppTheme(child: PureLiveApp()),
    ),
  );
  // Says which language was mounted and which of the four inputs decided it —
  // stored value, absent store, unrecognised id, launch pin, degraded
  // dependency. "I switched the style and nothing changed" is a question about
  // this line and the one after it, not about guessing.
  debugPrint('[ui] ${startupUi.reason}');
  if (kDebugMode) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportHostChain());
  }
}

/// The language `--ui-language=<id>` pins for this run, null when the argument is
/// absent.
///
/// An unknown id is a typo in a command line, and the only reader of it is the
/// person who just typed it, so it fails at boot rather than quietly rendering
/// the persisted language.
PureDesignLanguage? _pinnedLanguageFrom(List<String> args) {
  const prefix = '--ui-language=';
  for (final arg in args) {
    if (!arg.startsWith(prefix)) {
      continue;
    }
    final id = arg.substring(prefix.length);
    return PureDesignLanguage.values.firstWhere(
      (language) => language.name == id,
      orElse: () => throw ArgumentError.value(id, 'ui-language', 'not a design language'),
    );
  }
  return null;
}

/// Prints which host and shell the running tree actually mounted, once, after
/// the first frame.
///
/// The `[ui] design language` line says what the resolver *chose*; this says
/// what is on screen — the Fluent host chain — because "did the language
/// change the window" is a question about the mounted tree, and answering it
/// used to mean attaching a debugger.
void _reportHostChain() {
  final root = WidgetsBinding.instance.rootElement;
  if (root == null) {
    return;
  }
  final chain = <String>[];
  final structural = RegExp(r'(App|Window|Rail|NavigationView|Scaffold|Router|Overlay)$');
  void visit(Element element) {
    final name = element.widget.runtimeType.toString();
    if (structural.hasMatch(name)) {
      chain.add(name);
    }
    element.visitChildren(visit);
  }

  visit(root);
  debugPrint('[ui] host chain: ${chain.join(' > ')}');
}
