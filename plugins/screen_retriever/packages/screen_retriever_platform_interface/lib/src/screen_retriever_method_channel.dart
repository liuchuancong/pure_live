import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:screen_retriever_platform_interface/src/display.dart';
import 'package:screen_retriever_platform_interface/src/screen_retriever_platform.dart';

/// An implementation of [ScreenRetrieverPlatform] that uses method channels.
class MethodChannelScreenRetriever extends ScreenRetrieverPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(
    'dev.leanflutter.plugins/screen_retriever',
  );

  /// The event channel used to receive events from the native platform.
  @visibleForTesting
  final eventChannel = const EventChannel(
    'dev.leanflutter.plugins/screen_retriever_event',
  );

  @override
  Stream<Map<Object?, Object?>> get onScreenEventReceiver {
    return eventChannel.receiveBroadcastStream().cast<Map<Object?, Object?>>();
  }

  // The default arguments used for [methodChannel.invokeMethod].
  Map<String, dynamic> get _defaultArguments {
    MediaQueryData mediaQueryData = MediaQueryData.fromView(
      WidgetsBinding.instance.platformDispatcher.views.single,
    );
    final Map<String, dynamic> arguments = {
      'devicePixelRatio': mediaQueryData.devicePixelRatio,
    };
    return arguments;
  }

  @override
  Future<Offset> getCursorScreenPoint() async {
    final result = await methodChannel.invokeMethod(
      'getCursorScreenPoint',
      _defaultArguments,
    );
    if (result == null) {
      throw Exception('Unable to get cursor screen point.');
    }
    return Offset(result['dx'], result['dy']);
  }

  @override
  Future<Display> getPrimaryDisplay() async {
    final Map<Object?, Object?>? result = await methodChannel.invokeMethod(
      'getPrimaryDisplay',
      _defaultArguments,
    );
    if (result == null) {
      throw Exception('Unable to get primary display.');
    }
    return Display.fromJson(result.cast<String, dynamic>());
  }

  @override
  Future<List<Display>> getAllDisplays() async {
    final result = await methodChannel.invokeMethod(
      'getAllDisplays',
      _defaultArguments,
    );

    List<Display> displayList = [];
    if (result['displays'] != null) {
      displayList = (result['displays'] as List)
          .map((item) => Display.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (displayList.isEmpty) {
      throw Exception('Unable to get all displays.');
    }
    return displayList;
  }
}
