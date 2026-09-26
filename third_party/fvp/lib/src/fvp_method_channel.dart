/*
 * Copyright (c) 2023 WangBin <wbsecg1 at gmail.com>
 */
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'fvp_platform_interface.dart';

/// An implementation of [FvpPlatform] that uses method channels.
class MethodChannelFvp extends FvpPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('fvp');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<int> createTexture(
    int playerHandle,
    int width,
    int height,
    bool tunnel,
  ) async {
    final tex = await methodChannel.invokeMethod('CreateRT', {
      "player": playerHandle,
      "width": width,
      "height": height,
      "tunnel": tunnel,
    });
    return tex;
  }

  @override
  Future<void> releaseTexture(int playerHandle, int textureId) async {
    await methodChannel.invokeMethod('ReleaseRT', {
      "player": playerHandle,
      "texture": textureId,
    });
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {
    await methodChannel.invokeMethod('MixWithOthers', {"value": mixWithOthers});
  }
}
