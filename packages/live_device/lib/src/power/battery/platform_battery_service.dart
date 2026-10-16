import 'dart:async';

import 'package:battery_plus/battery_plus.dart' as plugin;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:live_device/src/power/battery/battery_capabilities.dart';
import 'package:live_device/src/power/battery/battery_exception.dart';
import 'package:live_device/src/power/battery/battery_service.dart';
import 'package:live_device/src/power/battery/battery_status.dart';

/// Default [BatteryService] implementation backed by `battery_plus`.
///
/// The plugin exposes a singleton battery object and its own charging-state
/// enum. This adapter keeps both private and owns error normalization, so
/// callers should depend on [BatteryService] rather than this class.
final class PlatformBatteryService implements BatteryService {
  /// Creates a service using the plugin's shared battery object.
  const new();

  /// The plugin constructor is a factory that returns a cached singleton, so
  /// reading it through a getter allocates nothing per call.
  plugin.Battery get _battery => plugin.Battery();

  @override
  Future<int> readLevel() => _guard(() async {
    final level = await _battery.batteryLevel;
    // A negative value means "no battery", which callers rely on; anything the
    // platform reports above the documented range is clamped.
    if (level < 0) return -1;
    return level > 100 ? 100 : level;
  });

  @override
  Future<BatteryStatus> readStatus() => _guard(() async {
    final state = await _battery.batteryState;
    return _toStatus(state);
  });

  @override
  Future<bool> isInPowerSaveMode() => _guard(() => _battery.isInBatterySaveMode);

  @override
  Stream<BatteryStatus> watchStatus() => _battery.onBatteryStateChanged
      .map(_toStatus)
      .transform(
        StreamTransformer<BatteryStatus, BatteryStatus>.fromHandlers(
          handleError: (error, stackTrace, sink) {
            sink.addError(_normalizeError(error), stackTrace);
          },
        ),
      );

  @override
  Future<BatteryCapabilities> getCapabilities() async {
    if (kIsWeb) {
      return const BatteryCapabilities(
        canReadLevel: true,
        canReadStatus: true,
        canObserve: true,
        canReadPowerSaveMode: false,
        aggregatesPowerSources: false,
        platformName: 'web',
      );
    }

    final platform = defaultTargetPlatform;
    final supported = switch (platform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      TargetPlatform.fuchsia => false,
    };
    // Battery-saver status is not exposed on the Linux Dart backend, on web or
    // on fuchsia; those platforms raise an unimplemented error at runtime.
    final canReadPowerSaveMode = switch (platform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.macOS || TargetPlatform.windows => true,
      TargetPlatform.linux || TargetPlatform.fuchsia => false,
    };
    // linux/macos/windows each see more than one power source but expose only a
    // single folded value (UPower DisplayDevice, sources[0], GetSystemPowerStatus),
    // so an extra battery or UPS is invisible there; android/ios/fuchsia are
    // single-battery by API and collapse nothing.
    final aggregatesPowerSources = switch (platform) {
      TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows => true,
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => false,
    };

    return BatteryCapabilities(
      canReadLevel: supported,
      canReadStatus: supported,
      canObserve: supported,
      canReadPowerSaveMode: canReadPowerSaveMode,
      aggregatesPowerSources: aggregatesPowerSources,
      platformName: platform.name,
    );
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on BatteryException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(_normalizeError(error), stackTrace);
    }
  }

  static BatteryStatus _toStatus(plugin.BatteryState state) => switch (state) {
    plugin.BatteryState.full => BatteryStatus.full,
    plugin.BatteryState.charging => BatteryStatus.charging,
    plugin.BatteryState.connectedNotCharging => BatteryStatus.connectedNotCharging,
    plugin.BatteryState.discharging => BatteryStatus.discharging,
    plugin.BatteryState.unknown => BatteryStatus.unknown,
  };

  BatteryException _normalizeError(Object error) {
    if (error is BatteryException) {
      return error;
    }

    final isMissingApi = error is MissingPluginException || error is UnimplementedError;

    return BatteryException(
      code: isMissingApi ? 'unsupported_on_platform' : 'battery_operation_failed',
      message: isMissingApi ? 'The battery API is not available on this platform.' : 'The battery operation failed.',
      details: <String, Object?>{'errorType': error.runtimeType.toString()},
      cause: error,
    );
  }
}
