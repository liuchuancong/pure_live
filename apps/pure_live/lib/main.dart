import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import 'package:pure_live/src/app.dart';
import 'package:pure_live/src/services.dart';

/// Whether this build is a TV build.
///
/// Declared, never inferred: a launcher, a native bridge or the release
/// pipeline passes `--dart-define=PURE_LIVE_TV=true`, and only then does the
/// app present a remote-control UI. Guessing from the platform would put a TV
/// layout on Android phones, which is the one mistake a runtime switch cannot
/// repair.
const bool _declaredTvBuild = bool.fromEnvironment('PURE_LIVE_TV');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final PureLiveServices services;
  try {
    services = _declaredTvBuild ? await PureLiveServices.boot(declaredTvBuild: true) : await PureLiveServices.boot();
  } on Object catch (error, stack) {
    // Boot failed before there is a log file to write to. The window still
    // opens, with the reason on it: an app that exits silently on a bad data
    // directory is indistinguishable from one that crashed for no reason.
    runApp(BootFailureApp(error: error, stackTrace: stack));
    return;
  }
  final log = services.log.forCategory('app.lifecycle')
    ..info(
      'Pure Live started',
      fields: {
        'platform': services.runtime.environment.runtime.kind.name,
        'formFactor': services.runtime.environment.runtime.formFactor.name,
        'designLanguage': services.preferences.value.appearance.designLanguageId,
      },
    );

  // Framework and platform failures reach the same log as everything else:
  // a bug report without them is a report about the wrong thing.
  final previousHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    log.error('uncaught framework error', error: details.exception, stackTrace: details.stack);
    previousHandler?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    log.fatal('uncaught platform error', error: error, stackTrace: stack);
    return true;
  };

  runApp(PureLiveApp(services: services));
}

/// Shown when the app could not boot.
///
/// Deliberately not built from `live_uikit`: the failure may well be the
/// storage the theme's preferences live in, so this screen depends on nothing
/// the boot touched.
class BootFailureApp extends StatelessWidget {
  /// A failure screen for [error].
  const new({required this.error, this.stackTrace, super.key});

  /// What went wrong.
  final Object error;

  /// Where it went wrong, collapsed but available.
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text('Pure Live could not start.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
              if (stackTrace case final stack?) ...[
                const SizedBox(height: 16),
                const Text('Details', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(child: Text('$stack', style: const TextStyle(fontSize: 12))),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
