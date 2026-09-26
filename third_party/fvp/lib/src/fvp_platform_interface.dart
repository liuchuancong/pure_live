/*
 * Copyright (c) 2023 WangBin <wbsecg1 at gmail.com>
 */
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'fvp_method_channel.dart';

abstract class FvpPlatform extends PlatformInterface {
  /// Constructs a FvpPlatform.
  FvpPlatform() : super(token: _token);

  static final Object _token = Object();

  static FvpPlatform _instance = MethodChannelFvp();

  /// The default instance of [FvpPlatform] to use.
  ///
  /// Defaults to [MethodChannelFvp].
  static FvpPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FvpPlatform] when
  /// they register themselves.
  static set instance(FvpPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<int> createTexture(
    int playerHandle,
    int width,
    int height,
    bool tunnel,
  ) {
    throw UnimplementedError('createTexture() has not been implemented.');
  }

  Future<void> releaseTexture(int playerHandle, int textureId) {
    throw UnimplementedError('releaseTexture() has not been implemented.');
  }

  Future<void> setMixWithOthers(bool mixWithOthers) async {
    throw UnimplementedError('setMixWithOthers() has not been implemented.');
  }
}
