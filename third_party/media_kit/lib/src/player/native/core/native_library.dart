// This file is a part of media_kit (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:ffi';

import 'package:media_kit/ffi/ffi.dart';

abstract final class NativeLibrary {
  static String get path {
    if (_resolved == null) {
      throw Exception(
        'MediaKit.ensureInitialized must be called before using any API from package:media_kit.',
      );
    }
    return _resolved!;
  }

  static void ensureInitialized({String? libmpv}) {
    if (libmpv != null) {
      DynamicLibrary.open(libmpv);
      _resolved = libmpv;
      return;
    }
    try {
      final env = Platform.environment['LIBMPV_LIBRARY_PATH'];
      if (env != null) {
        DynamicLibrary.open(env);
        _resolved = env;
        return;
      }
    } catch (_) {}
    // Resolve the code asset after Flutter's platform-specific relocation.
    _resolved = _bundledLibraryPath();
    DynamicLibrary.open(_resolved!);
  }

  static String? _resolved;
}

@Native<UnsignedLong Function()>(
  assetId: 'package:media_kit/libmpv',
  symbol: 'mpv_client_api_version',
)
external int _clientApiVersion();

@Native<Int32 Function(Pointer<Void>, Pointer<Char>, Int32)>(
  assetId:
      'package:media_kit/src/player/native/core/native_event_loop_bindings.dart',
  symbol: 'media_kit_library_path',
)
external int _libraryPath(
  Pointer<Void> symbol,
  Pointer<Char> buffer,
  int capacity,
);

String _bundledLibraryPath() {
  const capacity = 131072;
  final buffer = calloc<Char>(capacity);
  try {
    if (_libraryPath(
          Native.addressOf<NativeFunction<UnsignedLong Function()>>(
            _clientApiVersion,
          ).cast(),
          buffer,
          capacity,
        ) !=
        0) {
      throw StateError('Cannot resolve the bundled libmpv module');
    }
    return buffer.cast<Utf8>().toDartString();
  } finally {
    calloc.free(buffer);
  }
}
