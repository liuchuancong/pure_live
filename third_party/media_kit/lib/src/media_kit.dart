/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.

import 'package:universal_platform/universal_platform.dart';

import 'package:media_kit/src/player/native/player/player.dart';
import 'package:media_kit/src/player/web/player/player.dart';

/// {@template media_kit}
///
/// package:media_kit
/// -----------------
/// A complete video & audio library for Flutter & Dart.
///
/// {@endtemplate}
abstract class MediaKit {
  static bool _initialized = false;

  /// {@macro media_kit}
  static void ensureInitialized({String? libmpv}) {
    if (_initialized) return;

    try {
      if (UniversalPlatform.isWindows) {
        nativeEnsureInitialized(libmpv: libmpv);
      } else if (UniversalPlatform.isLinux) {
        nativeEnsureInitialized(libmpv: libmpv);
      } else if (UniversalPlatform.isMacOS) {
        nativeEnsureInitialized(libmpv: libmpv);
      } else if (UniversalPlatform.isIOS) {
        nativeEnsureInitialized(libmpv: libmpv);
      } else if (UniversalPlatform.isAndroid) {
        nativeEnsureInitialized(libmpv: libmpv);
      } else if (UniversalPlatform.operatingSystem == 'ohos') {
        nativeEnsureInitialized(libmpv: libmpv);
      } else if (UniversalPlatform.isWeb) {
        webEnsureInitialized(libmpv: libmpv);
      }
      _initialized = true;
    } catch (_) {
      print(
        '\n'
        '${'-' * 80}\n'
        'media_kit: ERROR: MediaKit.ensureInitialized\n'
        'This indicates that one or more required dependencies could not be located.\n'
        '\n'
        'Refer to "Installation" section of the README for further details:\n'
        'GitHub  : https://github.com/media-kit/media-kit#installation\n'
        'pub.dev : https://pub.dev/packages/media_kit#installation\n'
        '\n'
        'TIP: Copy-paste required packages from the above link to your pubspec.yaml.\n'
        '\n'
        'If you recently added the packages, make sure to re-run the project ("hot-restart" & "hot-reload" is not sufficient for native plugins).\n'
        '${'-' * 80}\n',
      );
      rethrow;
    }
  }
}
