import 'dart:async' show unawaited;
import 'dart:io' show Platform, exit;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_log/live_log.dart' show ErrorReporter;
import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/app/composition/app_services.dart';
import 'package:pure_live/app/engine/playback_engine.dart';
import 'package:pure_live/app/logging/app_log.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/theme/app_theme.dart';
import 'package:pure_live/app/theme/ui_configuration_mapper.dart';
import 'package:pure_live/platforms/desktop/entry/desktop_entry.dart';
import 'package:pure_live/platforms/desktop/entry/desktop_launch.dart';
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
    ErrorReporter.report(log.forCategory('flutter'), details.exception, details.stack, message: 'framework error');
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
      appPreferences: services.appPreferences,
      log: log.forCategory('shell'),
    );
    await desktopEntry.prepare();
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
        followRepositoryProvider.overrideWithValue(services.followRepository),
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
/// what is on screen — `FluentApp`, `CupertinoApp`, `MacosApp`, `MaterialApp`
/// or the token host — because "did the language change the window" is a question
/// about the mounted tree, and answering it used to mean attaching a debugger.
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
