/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:safe_local_storage/safe_local_storage.dart';

import 'package:media_kit/src/player/native/utils/android_asset_loader.dart';

/// {@template asset_loader}
///
/// AssetLoader
/// -----------
///
/// A utility to load Flutter assets.
///
/// {@endtemplate}
class AssetLoader {
  static String load(String uri) {
    final key = encodeAssetKey(uri);
    final String asset;
    if (Platform.isWindows) {
      asset = path.normalize(
        path.join(
          path.dirname(Platform.resolvedExecutable),
          'data',
          'flutter_assets',
          key,
        ),
      );
    } else if (Platform.isLinux) {
      asset = path.normalize(
        path.join(
          path.dirname(Platform.resolvedExecutable),
          'data',
          'flutter_assets',
          key,
        ),
      );
    } else if (Platform.isMacOS) {
      asset = path.normalize(
        path.join(
          path.dirname(Platform.resolvedExecutable),
          '..',
          'Frameworks',
          'App.framework',
          'Resources',
          'flutter_assets',
          key,
        ),
      );
    } else if (Platform.isIOS) {
      asset = path.normalize(
        path.join(
          path.dirname(Platform.resolvedExecutable),
          'Frameworks',
          'App.framework',
          'flutter_assets',
          key,
        ),
      );
    } else if (Platform.isAndroid) {
      asset = path.normalize(
        AndroidAssetLoader.loadSync(
          path.join(
            'flutter_assets',
            key,
          ),
        ),
      );
    } else if (Platform.operatingSystem == 'ohos') {
      asset = path.normalize(
        path.join(
          path.dirname(Platform.resolvedExecutable),
          '..',
          '..',
          'resources',
          'rawfile',
          'flutter_assets',
          key,
        ),
      );
    } else {
      throw UnimplementedError(
        '$_kAssetScheme is not supported on ${Platform.operatingSystem}',
      );
    }
    if (!File(asset).existsSync_()) {
      throw Exception('Unable to load asset: $asset');
    }
    return asset;
  }

  static String encodeAssetKey(String uri) {
    String key = uri.split(_kAssetScheme).last;
    if (key.startsWith('/')) {
      key = key.substring(1);
    }
    // https://github.com/media-kit/media-kit/issues/121
    return key.split('/').map((e) => Uri.encodeComponent(e)).join('/');
  }

  /// URI scheme used to identify Flutter assets.
  static const String _kAssetScheme = 'asset://';
}
