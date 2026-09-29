/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:ffi';
import 'dart:collection';

import 'package:media_kit/ffi/ffi.dart';

import 'package:media_kit/src/player/native/utils/isolates.dart';

/// {@template android_asset_loader}
///
/// AndroidAssetLoader
/// ------------------
///
/// This class is used to access assets bundled with the application on Android.
/// The implementation depends on the mediakitandroidhelper library.
///
/// Learn more: https://github.com/media-kit/media-kit-android-helper
///
/// {@endtemplate}
abstract class AndroidAssetLoader {
  /// Copies an asset bundled with the application to the external files directory & returns it absolute path.
  static Future<String> load(String asset) async {
    final lookup = _loaded[asset];
    if (lookup != null) {
      return lookup;
    }
    final path = await compute(_copyAssetToFilesDir, asset);
    _loaded[asset] = path;
    return path;
  }

  /// Copies an asset bundled with the application to the files directory & returns it absolute path.
  static String loadSync(String asset) {
    final lookup = _loaded[asset];
    if (lookup != null) {
      return lookup;
    }
    final path = _copyAssetToFilesDir(asset);
    _loaded[asset] = path;
    return path;
  }

  /// The native implementation for [load] & [loadSync].
  static String _copyAssetToFilesDir(String asset) {
    final lib = DynamicLibrary.open('libmediakitandroidhelper.so');
    final fn = lib.lookupFunction<FnCXX, FnDart>(
      'MediaKitAndroidHelperCopyAssetToFilesDir',
    );
    final name = asset.toNativeUtf8();
    final result = List.generate(4096, (index) => ' ').join('').toNativeUtf8();
    fn.call(name.cast(), result.cast());
    final path = result.cast<Utf8>().toDartString().trim();
    calloc.free(name);
    calloc.free(result);
    return path;
  }

  /// Stores the names of previously loaded assets. This avoids redundant FFI calls.
  static final HashMap<String, String> _loaded = HashMap<String, String>();
}

// Type definitions for native functions in the shared library.

// C/C++:

typedef FnCXX = Void Function(Pointer<Utf8> asset, Pointer<Utf8> result);

// Dart:

typedef FnDart = void Function(Pointer<Utf8> asset, Pointer<Utf8> result);
