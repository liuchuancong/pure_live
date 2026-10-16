import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:live_device/src/audio/volume/system_volume_capabilities.dart';
import 'package:live_device/src/audio/volume/system_volume_exception.dart';
import 'package:live_device/src/audio/volume/system_volume_service.dart';
import 'package:volume_controller/volume_controller.dart' as plugin;

/// Default [SystemVolumeService] implementation backed by `volume_controller`.
///
/// The underlying plugin exposes a singleton controller. This adapter keeps
/// that plugin API private and owns the listener subscription created for each
/// [watchVolume] stream.
///
/// Every call reaches the single default endpoint the plugin resolves — Windows
/// `GetDefaultAudioEndpoint(eRender, eMultimedia)`, macOS
/// `kAudioHardwarePropertyDefaultOutputDevice`, Linux the ALSA card named
/// `default` — and no endpoint selector is offered. The macOS helper in
/// particular has no master-volume path for many devices, so it averages the
/// per-channel volumes when reading and writes one value to every channel when
/// setting; that folding is passed through unchanged here.
final class PlatformSystemVolumeService implements SystemVolumeService {
  /// Creates a service using the plugin's shared system-volume controller.
  const new();

  plugin.VolumeController get _controller => plugin.VolumeController.instance;

  @override
  Future<int> getVolume() => _guard(() async {
    final volume = await _controller.getVolume();
    return _toPercentage(volume);
  });

  @override
  Future<int> setVolume(int percentage) {
    if (percentage < 0 || percentage > 100) {
      throw SystemVolumeException(
        code: 'invalid_volume_value',
        message: 'Volume must be between 0 and 100, got $percentage.',
        details: <String, Object?>{'value': percentage},
      );
    }

    return _guard(() async {
      await _controller.setVolume(percentage / 100);
      return percentage;
    });
  }

  @override
  Future<bool> isMuted() => _guard(_controller.isMuted);

  @override
  Future<void> setMuted({required bool muted}) => _guard(() => _controller.setMute(muted));

  @override
  Stream<int> watchVolume() {
    late final StreamController<int> events;
    // Held by the stream and cancelled from onCancel below, so this cannot be
    // cancelled in the function that creates it.
    // ignore: cancel_subscriptions
    StreamSubscription<double>? nativeSubscription;

    events = StreamController<int>(
      onListen: () {
        try {
          nativeSubscription = _controller.addListener((volume) {
            try {
              events.add(_toPercentage(volume));
            } on SystemVolumeException catch (error, stackTrace) {
              events.addError(error, stackTrace);
            }
          });
          nativeSubscription!.onError((Object error, StackTrace stackTrace) {
            events.addError(_normalizeError(error), stackTrace);
          });
        } on Object catch (error, stackTrace) {
          events.addError(_normalizeError(error), stackTrace);
          unawaited(events.close());
        }
      },
      onCancel: () async {
        final subscription = nativeSubscription;
        nativeSubscription = null;
        await subscription?.cancel();
      },
    );

    return events.stream;
  }

  @override
  Future<SystemVolumeCapabilities> getCapabilities() async {
    if (kIsWeb) {
      return const SystemVolumeCapabilities(
        canRead: false,
        canWrite: false,
        canObserve: false,
        canMute: false,
        canControlSystemUi: false,
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
    final canControlSystemUi = switch (platform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.fuchsia => false,
    };

    return SystemVolumeCapabilities(
      canRead: supported,
      canWrite: supported,
      canObserve: supported,
      canMute: supported,
      canControlSystemUi: canControlSystemUi,
      platformName: platform.name,
    );
  }

  @override
  bool setSystemUiVisible({required bool visible}) {
    final platform = defaultTargetPlatform;
    final supported = !kIsWeb && (platform == TargetPlatform.android || platform == TargetPlatform.iOS);
    if (!supported) {
      return false;
    }

    _controller.showSystemUI = visible;
    return true;
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on SystemVolumeException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(_normalizeError(error), stackTrace);
    }
  }

  int _toPercentage(double volume) {
    if (!volume.isFinite) {
      throw const SystemVolumeException(
        code: 'invalid_native_volume',
        message: 'The platform returned a non-finite volume value.',
      );
    }
    return (volume.clamp(0.0, 1.0) * 100).round();
  }

  SystemVolumeException _normalizeError(Object error) {
    if (error is SystemVolumeException) {
      return error;
    }

    return SystemVolumeException(
      code: 'system_volume_operation_failed',
      message: 'The system-volume operation failed.',
      details: <String, Object?>{'errorType': error.runtimeType.toString()},
      cause: error,
    );
  }
}
