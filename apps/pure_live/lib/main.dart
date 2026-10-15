import 'dart:async';
import 'dart:io' show exit;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_uikit/styling.dart';

import 'package:pure_live/app/adapters.dart';
import 'package:pure_live/app/appearance_mapping.dart';
import 'package:pure_live/app/delegates.dart';
import 'package:pure_live/app/providers.dart';
import 'package:pure_live/platform/desktop_boot.dart';
import 'package:pure_live/storage/services.dart';
import 'package:pure_live/user_data/preferences/preferences.dart' show Preferences;

/// Whether this build targets the ten-foot (TV) form factor. Declared at build
/// time — `flutter build apk --dart-define=PURE_LIVE_TV=true` — because a TV is
/// a different composition, not a wider window (design doc §1.2): the shell
/// drops the rail, the geometry scale rises, and focus is the only pointer.
const bool appIsTv = bool.fromEnvironment('PURE_LIVE_TV');

/// PureLive — the application entry.
///
/// `main` boots [AppServices] (storage, preferences and the site registry) and
/// runs [PureLiveApp]. The active [UiConfig] is derived from the persisted
/// appearance and fed to a root `LiveConfigProvider`, so every screen — and any
/// route pushed on the navigator — reads the same resolved [LiveTheme].
Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  // The lock before anything is drawn: a second copy of this app must reach the
  // instance that is already running instead of opening a window nobody asked
  // for. On a phone this says nothing and costs nothing.
  final claim = await DesktopBootstrap.claimInstance(arguments);
  if (claim.shouldExit) {
    // Returning from `main` does not end a desktop Flutter process: the runner's
    // message loop is already going and keeps going, which is how "the app is
    // already running" turns into a second silent process in the task list. The
    // handoff has been delivered by now, so leave immediately.
    exit(0);
  }
  final services = await AppServices.boot();
  // The shell comes up before the tree: it restores the window's remembered place
  // and decides whether this start shows a window at all, and neither question
  // wants to be answered after the first frame has already been painted in the
  // wrong place.
  final desktop = await DesktopBootstrap.start(services: services, arguments: arguments, claim: claim);
  runApp(
    ProviderScope(
      overrides: [appServicesProvider.overrideWithValue(services)],
      child: PureLiveApp(desktop: desktop),
    ),
  );
}

/// The root application: watches preferences and re-skins the whole app —
/// including pushed routes — whenever the saved appearance changes.
class PureLiveApp extends ConsumerWidget {
  /// The root app over the booted services and the [desktop] shell handle.
  const new({this.desktop, super.key});

  /// The desktop shell this process runs under, null on a platform with none.
  ///
  /// Held by the tree rather than by a global, so a hot restart rebuilds it and
  /// the settings screen can reach it without the app inventing a second one.
  final DesktopBootstrap? desktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(appServicesProvider);
    return StreamBuilder<Preferences>(
      stream: services.preferences.changes,
      initialData: services.preferences.value,
      builder: (context, snapshot) => LiveConfigProvider(
        config: uiConfigFromAppearance(snapshot.data!.appearance),
        // Report, never silently swallow, a language whose adapter isn't registered
        // — the core hands the event here; the app owns the logging (§3.10).
        diagnostics: (diagnostic) => debugPrint('[live_uikit] $diagnostic'),
        // The composition root registers every third-party adapter; the core
        // itself never depends on a UI library.
        registry: appLanguageRegistry,
        child: LiveLayoutBuilder(
          isTv: appIsTv,
          builder: (context, environment) => MaterialApp.router(
            title: 'Pure Live',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: const [Locale('en'), Locale('zh')],
            routerConfig: ref.watch(appRouterProvider),
          ),
        ),
      ),
    );
  }
}
