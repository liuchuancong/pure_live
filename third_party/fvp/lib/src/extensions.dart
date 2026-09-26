// Copyright 2022-2024 Wang Bin. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'lib.dart';

import 'package:path/path.dart' as path;

extension PlatformEx on Platform {
  static bool isAndroidEmulator() {
    if (!Platform.isAndroid) {
      return false;
    }
    // lsmod: goldfish_pipe, virtio_pci
    return Libfvp.isEmulator();
  }

  // TODO: check content /proc/device-tree/model?
  static bool isRockchip() {
    if (!Platform.isLinux) {
      return false;
    }
    return File('/dev/mpp_service').existsSync();
  }

  static bool isRaspberryPi() {
    if (!Platform.isLinux) {
      return false;
    }
    return File('/dev/vchiq').existsSync();
  }

  static String assetUri(String asset, {String? package}) {
    final key = asset;
    switch (Platform.operatingSystem) {
      case 'windows':
        return path.join(
          path.dirname(Platform.resolvedExecutable),
          'data',
          'flutter_assets',
          key,
        );
      case 'linux':
        return path.join(
          path.dirname(Platform.resolvedExecutable),
          'data',
          'flutter_assets',
          key,
        );
      case 'macos':
        return path.join(
          path.dirname(Platform.resolvedExecutable),
          '..',
          'Frameworks',
          'App.framework',
          'Resources',
          'flutter_assets',
          key,
        );
      case 'ios':
        return path.join(
          path.dirname(Platform.resolvedExecutable),
          'Frameworks',
          'App.framework',
          'flutter_assets',
          key,
        );
      case 'android':
        return 'assets://flutter_assets/$key';
      case 'ohos':
        return 'rawfile://flutter_assets/$key';
    }
    return asset;
  }
}

extension NullTerminatedU8PtrArray on Pointer<Pointer<Utf8>> {
  void free() {
    for (int i = 0; ; ++i) {
      final p = this[i];
      if (p == nullptr) {
        break;
      }
      malloc.free(p);
    }
    calloc.free(this);
  }
}

extension CStringList on List<String> {
  Pointer<Pointer<Utf8>> toC() {
    List<Pointer<Utf8>> ul = map((s) => s.toNativeUtf8()).toList();

    final pp = calloc<Pointer<Utf8>>(ul.length);
    //final Pointer<Pointer<Utf8>> pp = calloc.allocate(ul.length * sizeOf<Pointer<Utf8>>());

    asMap().forEach((index, _) {
      pp[index] = ul[index];
    });
    return pp;
  }

  Pointer<Pointer<Utf8>> toCZ() {
    List<Pointer<Utf8>> ul = map((s) => s.toNativeUtf8()).toList();

    final pp = calloc<Pointer<Utf8>>(ul.length + 1);

    for (int i = 0; i < length; ++i) {
      pp[i] = ul[i];
    }
    pp[ul.length] = nullptr; // optional if use calloc?
    return pp;
  }
}
