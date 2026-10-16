import 'dart:async';

import 'package:device_screen_brightness/device_screen_brightness.dart' as plugin;
import 'package:live_device/src/display/brightness/screen_brightness_capabilities.dart';
import 'package:live_device/src/display/brightness/screen_brightness_exception.dart';
import 'package:live_device/src/display/brightness/screen_brightness_scope.dart';
import 'package:live_device/src/display/brightness/screen_brightness_service.dart';

/// `live_device` implementation backed by `device_screen_brightness`.
///
/// Keep plugin-specific behavior and exceptions inside this class; application
/// and feature packages should depend on [ScreenBrightnessService] instead.
final class PlatformScreenBrightnessService implements ScreenBrightnessService {
  /// Creates the default platform-backed implementation.
  const new();

  @override
  Future<int> getBrightness({ScreenBrightnessScope scope = ScreenBrightnessScope.application}) =>
      _guard(() => plugin.DeviceScreenBrightness.getBrightness(mode: _toMode(scope)));

  @override
  Future<int> setBrightness(int percentage, {ScreenBrightnessScope scope = ScreenBrightnessScope.application}) {
    if (percentage < 0 || percentage > 100) {
      throw ScreenBrightnessException(
        code: 'invalid_brightness_value',
        message: 'Brightness must be between 0 and 100, got $percentage.',
        details: <String, Object?>{'value': percentage},
      );
    }

    return _guard(() => plugin.DeviceScreenBrightness.setBrightness(percentage, mode: _toMode(scope)));
  }

  @override
  Future<int> increase({ScreenBrightnessScope scope = ScreenBrightnessScope.application}) =>
      _guard(() => plugin.DeviceScreenBrightness.incrementBrightness(mode: _toMode(scope)));

  @override
  Future<int> decrease({ScreenBrightnessScope scope = ScreenBrightnessScope.application}) =>
      _guard(() => plugin.DeviceScreenBrightness.decrementBrightness(mode: _toMode(scope)));

  @override
  Stream<int> watchBrightness({ScreenBrightnessScope scope = ScreenBrightnessScope.application}) =>
      plugin.DeviceScreenBrightness.streamBrightness(mode: _toMode(scope)).transform(
        StreamTransformer<int, int>.fromHandlers(
          handleError: (error, stackTrace, sink) {
            if (error is plugin.DeviceScreenBrightnessException) {
              sink.addError(_toPublicException(error), stackTrace);
            } else {
              sink.addError(error, stackTrace);
            }
          },
        ),
      );

  @override
  Future<ScreenBrightnessCapabilities> getCapabilities() => _guard(() async {
    final native = await plugin.DeviceScreenBrightness.getCapabilities();

    return ScreenBrightnessCapabilities(
      canRead: native.canRead,
      canWrite: native.canWrite,
      canObserve: native.canObserve,
      writeSupport: switch (native.writeSupport) {
        plugin.BrightnessWriteSupport.supported => ScreenBrightnessWriteSupport.supported,
        plugin.BrightnessWriteSupport.bestEffort => ScreenBrightnessWriteSupport.bestEffort,
        plugin.BrightnessWriteSupport.unsupported => ScreenBrightnessWriteSupport.unsupported,
      },
      supportedScopes: native.supportedModes.map(_fromMode),
      requiresSystemPermission: native.requiresWriteSettingsPermission,
      backend: native.backend,
    );
  });

  @override
  Future<bool> hasPermission({ScreenBrightnessScope scope = ScreenBrightnessScope.system}) {
    if (scope == ScreenBrightnessScope.application) {
      return Future<bool>.value(true);
    }
    return _guard(plugin.DeviceScreenBrightness.hasPermission);
  }

  @override
  Future<bool> requestPermission({ScreenBrightnessScope scope = ScreenBrightnessScope.system}) async {
    if (scope == ScreenBrightnessScope.application) {
      return true;
    }

    await _guard(plugin.DeviceScreenBrightness.requestPermission);
    return await hasPermission(scope: scope);
  }

  static plugin.BrightnessMode _toMode(ScreenBrightnessScope scope) => switch (scope) {
    ScreenBrightnessScope.application => plugin.BrightnessMode.app,
    ScreenBrightnessScope.system => plugin.BrightnessMode.system,
  };

  static ScreenBrightnessScope _fromMode(plugin.BrightnessMode mode) => switch (mode) {
    plugin.BrightnessMode.app => ScreenBrightnessScope.application,
    plugin.BrightnessMode.system => ScreenBrightnessScope.system,
  };

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on plugin.DeviceScreenBrightnessException catch (error, stackTrace) {
      Error.throwWithStackTrace(_toPublicException(error), stackTrace);
    }
  }

  ScreenBrightnessException _toPublicException(plugin.DeviceScreenBrightnessException error) =>
      ScreenBrightnessException(
        code: error.code,
        message: error.message,
        details: Map<String, Object?>.unmodifiable(error.details),
        cause: error,
      );
}
