import 'package:flutter/widgets.dart';
import 'package:screen_retriever_platform_interface/src/display.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:screen_retriever_platform_interface/src/screen_retriever_method_channel.dart';

abstract class ScreenRetrieverPlatform extends PlatformInterface {
  /// Constructs a ScreenRetrieverPlatform.
  ScreenRetrieverPlatform() : super(token: _token);

  static final Object _token = Object();

  static ScreenRetrieverPlatform _instance = MethodChannelScreenRetriever();

  /// The default instance of [ScreenRetrieverPlatform] to use.
  ///
  /// Defaults to [MethodChannelScreenRetriever].
  static ScreenRetrieverPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ScreenRetrieverPlatform] when
  /// they register themselves.
  static set instance(ScreenRetrieverPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<Map<Object?, Object?>> get onScreenEventReceiver {
    throw UnimplementedError('onScreenEventReceiver() has not been implemented.');
  }

  Future<Offset> getCursorScreenPoint() {
    throw UnimplementedError('getCursorScreenPoint() has not been implemented.');
  }

  Future<Display> getPrimaryDisplay() {
    throw UnimplementedError('getPrimaryDisplay() has not been implemented.');
  }

  Future<List<Display>> getAllDisplays() async {
    throw UnimplementedError('getAllDisplays() has not been implemented.');
  }
}
