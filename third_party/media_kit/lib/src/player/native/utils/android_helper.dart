// This file is a part of media_kit (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the LICENSE file.

import 'dart:ffi';
import 'dart:io';

import 'package:media_kit/ffi/ffi.dart';

abstract final class AndroidHelper {
  static void ensureInitialized({required String libmpv}) {
    if (!Platform.isAndroid) return;

    final vm = _library
        .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
          'MediaKitAndroidHelperGetJavaVM',
        )();
    if (vm == nullptr) {
      throw StateError(
        'Android JNI is not initialized. Register the media_kit plugin before creating a Player.',
      );
    }

    final mpv = DynamicLibrary.open(libmpv);
    final int result;
    if (mpv.providesSymbol('mpv_lavc_set_java_vm')) {
      result = mpv
          .lookupFunction<
            Int32 Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('mpv_lavc_set_java_vm')(vm);
    } else {
      // Custom builds may link FFmpeg dynamically instead of exporting mpv's shim.
      result = DynamicLibrary.open('libavcodec.so')
          .lookupFunction<
            Int32 Function(Pointer<Void>, Pointer<Void>),
            int Function(Pointer<Void>, Pointer<Void>)
          >('av_jni_set_java_vm')(vm, nullptr);
    }
    if (result < 0) {
      throw StateError('Could not initialize libmpv JNI: $result');
    }
  }

  static String? get filesDir {
    if (!Platform.isAndroid) return null;
    final path = _getFilesDir();
    return path == nullptr ? null : path.toDartString();
  }

  static bool get isEmulator => Platform.isAndroid && _isEmulator() == 1;

  static int get apiLevel => Platform.isAndroid ? _getApiLevel() : -1;

  static final _library = DynamicLibrary.open('libmediakitandroidhelper.so');
  static final _getFilesDir = _library
      .lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
        'MediaKitAndroidHelperGetFilesDir',
      );
  static final _isEmulator = _library
      .lookupFunction<Int8 Function(), int Function()>(
        'MediaKitAndroidHelperIsEmulator',
      );
  static final _getApiLevel = _library
      .lookupFunction<Int32 Function(), int Function()>(
        'MediaKitAndroidHelperGetAPILevel',
      );
}
