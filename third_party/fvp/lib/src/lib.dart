// Copyright 2022-2026 Wang Bin. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:ffi';
import 'dart:io';

import 'generated_bindings.dart';

abstract class Libmdk {
  static DynamicLibrary _load() {
    String name;
    switch (Platform.operatingSystem) {
      case 'windows':
        name = 'mdk.dll';
      case 'macos':
        name = 'mdk.framework/mdk';
      case 'ios':
        name = 'mdk.framework/mdk';
      case 'linux':
        name = 'libmdk.so.0';
      case 'android':
      case 'ohos':
        name = 'libmdk.so';
      default:
        throw Exception(
          'Unsupported operating system: ${Platform.operatingSystem}.',
        );
    }
    try {
      return DynamicLibrary.open(name);
    } catch (e) {
      rethrow;
    }
  }

  static final instance = NativeLibrary(_load());
}

abstract class Libfvp {
  static DynamicLibrary _load() {
    String name;
    if (Platform.isWindows) {
      name = 'fvp.dll';
    } else if (Platform.isIOS || Platform.isMacOS) {
      name = 'fvp.framework/fvp';
    } else if (Platform.isAndroid ||
        Platform.isLinux ||
        Platform.operatingSystem == 'ohos') {
      name = 'libfvp.so';
    } else {
      throw Exception(
        'Unsupported operating system: ${Platform.operatingSystem}.',
      );
    }
    try {
      return DynamicLibrary.open(name);
    } catch (e) {
      rethrow;
    }
  }

  static final instance = _load();
  static final setKey = instance
      .lookupFunction<
        Void Function(Pointer<Char>),
        void Function(Pointer<Char>)
      >('MdkSetKey');
  static final registerPort = instance
      .lookupFunction<
        Void Function(Int64, Pointer<Void>, Int64),
        void Function(int, Pointer<Void>, int)
      >('MdkCallbacksRegisterPort');
  static final unregisterPort = instance
      .lookupFunction<Void Function(Int64), void Function(int)>(
        'MdkCallbacksUnregisterPort',
      );
  static final registerType = instance
      .lookupFunction<
        Void Function(Int64, Int, Bool),
        void Function(int, int, bool)
      >('MdkCallbacksRegisterType');
  static final unregisterType = instance
      .lookupFunction<Void Function(Int64, Int), void Function(int, int)>(
        'MdkCallbacksUnregisterType',
      );
  static final replyType = instance
      .lookupFunction<
        Void Function(Int64, Int, Pointer<Void>),
        void Function(int, int, Pointer<Void>)
      >('MdkCallbacksReplyType');
  static final prepare = instance
      .lookupFunction<
        Bool Function(Int64, Int64, Int64, Pointer<Void>, Int64),
        bool Function(int, int, int, Pointer<Void>, int)
      >('MdkPrepare');
  static final seek = instance
      .lookupFunction<
        Bool Function(Int64, Int64, Int64, Pointer<Void>, Int64),
        bool Function(int, int, int, Pointer<Void>, int)
      >('MdkSeek');
  static final snapshot = instance
      .lookupFunction<
        Bool Function(Int64, Int64, Int, Int, Pointer<Void>, Int64),
        bool Function(int, int, int, int, Pointer<Void>, int)
      >('MdkSnapshot');
  static final isEmulator = instance
      .lookupFunction<Bool Function(), bool Function()>('MdkIsEmulator');
  static final getVid = instance
      .lookupFunction<
        Pointer<Void> Function(Int64),
        Pointer<Void> Function(int)
      >('MdkGetPlayerVid');
}
