import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

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

  final services = _declaredTvBuild
      ? await PureLiveServices.boot(declaredTvBuild: true)
      : await PureLiveServices.boot();
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
