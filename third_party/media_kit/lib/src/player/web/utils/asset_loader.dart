/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'package:media_kit/src/values.dart';

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
    return encodeAssetKey(uri);
  }

  static String encodeAssetKey(String uri) {
    String key = uri.split(_kAssetScheme).last;
    if (key.startsWith('/')) {
      key = key.substring(1);
    }

    // https://github.com/media-kit/media-kit/issues/531
    // https://github.com/media-kit/media-kit/issues/121
    if (kReleaseMode) {
      return 'assets/${key.split('/').map((e) => Uri.encodeComponent(Uri.encodeComponent(e))).join('/')}';
    }
    return key.split('/').map(Uri.encodeComponent).join('/');
  }

  /// URI scheme used to identify Flutter assets.
  static const String _kAssetScheme = 'asset://';
}
