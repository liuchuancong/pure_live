import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:live_device/src/display/refresh_rate/display_refresh_rate.dart';
import 'package:live_device/src/display/refresh_rate/display_refresh_rate_capabilities.dart';
import 'package:live_device/src/display/refresh_rate/display_refresh_rate_exception.dart';
import 'package:live_device/src/display/refresh_rate/display_refresh_rate_preference.dart';
import 'package:live_device/src/display/refresh_rate/display_refresh_rate_service.dart';
import 'package:refresh_rate/refresh_rate.dart' as plugin;

/// Default [DisplayRefreshRateService] implementation backed by `refresh_rate`.
///
/// The plugin drives a static facade that caches the latest display snapshot
/// and reports its own enums. This adapter keeps that facade, its snapshot type
/// and its error types private; callers should depend on
/// [DisplayRefreshRateService] instead.
final class PlatformDisplayRefreshRateService implements DisplayRefreshRateService {
  /// Creates a service that uses the plugin's static display facade.
  const new();

  @override
  Future<DisplayRefreshRate> read() => _guard(() async {
    final info = await plugin.RefreshRate.refresh();
    return _toSnapshot(info);
  });

  @override
  Stream<DisplayRefreshRate> watch() => plugin.RefreshRate.onChanged
      .map(_toSnapshot)
      .transform(
        StreamTransformer<DisplayRefreshRate, DisplayRefreshRate>.fromHandlers(
          handleError: (error, stackTrace, sink) {
            sink.addError(_normalizeError(error), stackTrace);
          },
        ),
      );

  @override
  Future<DisplayRefreshRateCapabilities> getCapabilities() => _guard(() async {
    final native = await plugin.RefreshRate.capabilities();

    return DisplayRefreshRateCapabilities(
      canQuery: native.query,
      canRequestPreferredRates: native.windowPreferences || native.engineControl,
      canMatchContent: native.contentMatching,
      canObserve: native.callbackObservation,
      platformName: _platformName(),
    );
  });

  @override
  Future<DisplayRefreshRatePreference> preferMaximum() => _guard(() => _submit(plugin.RefreshRate.preferMax()));

  @override
  Future<DisplayRefreshRatePreference> preferDefault() => _guard(() => _submit(plugin.RefreshRate.preferDefault()));

  @override
  Future<DisplayRefreshRatePreference> matchContent({required double hz}) {
    if (!hz.isFinite || hz <= 0) {
      throw DisplayRefreshRateException(
        code: 'invalid_refresh_rate',
        message: 'Content refresh rate must be a positive finite value, got $hz.',
        details: <String, Object?>{'value': hz},
      );
    }

    return _guard(() => _submit(plugin.RefreshRate.matchContent(hz)));
  }

  static String _platformName() => kIsWeb ? 'web' : defaultTargetPlatform.name;

  Future<DisplayRefreshRatePreference> _submit(Future<plugin.RateRequestResult> request) async =>
      _toPreference((await request).status);

  /// Thermal and power evidence is only available through the plugin's cached
  /// statics, so it is read at the moment this snapshot is assembled.
  static DisplayRefreshRate _toSnapshot(plugin.DisplayInfo info) => DisplayRefreshRate(
    currentHz: info.currentRate,
    supportedHz: info.supportedRates,
    maxHz: _toHz(info.maxRate),
    isLowPowerMode: plugin.RefreshRate.isLowPowerMode,
    thermalState: _toThermalState(plugin.RefreshRate.thermalState),
    monitorCount: info.monitorCount,
  );

  /// The plugin uses `0` for "no qualified value"; `null` is the public answer.
  static double? _toHz(double value) => value.isFinite && value > 0 ? value : null;

  static DisplayThermalState _toThermalState(plugin.ThermalState state) => switch (state) {
    plugin.ThermalState.nominal => DisplayThermalState.nominal,
    plugin.ThermalState.fair => DisplayThermalState.fair,
    plugin.ThermalState.serious => DisplayThermalState.serious,
    plugin.ThermalState.critical => DisplayThermalState.critical,
    plugin.ThermalState.unknown => DisplayThermalState.unknown,
  };

  /// A request replaced by a newer one is not a distinct outcome for callers, so
  /// the plugin's superseded status collapses into [DisplayRefreshRatePreference.failed].
  static DisplayRefreshRatePreference _toPreference(plugin.RequestStatus status) => switch (status) {
    plugin.RequestStatus.submitted => DisplayRefreshRatePreference.submitted,
    plugin.RequestStatus.unsupported => DisplayRefreshRatePreference.unsupported,
    plugin.RequestStatus.unavailable => DisplayRefreshRatePreference.unavailable,
    plugin.RequestStatus.failed || plugin.RequestStatus.superseded => DisplayRefreshRatePreference.failed,
  };

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on DisplayRefreshRateException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(_normalizeError(error), stackTrace);
    }
  }

  DisplayRefreshRateException _normalizeError(Object error) {
    if (error is DisplayRefreshRateException) {
      return error;
    }

    final isMissingApi = error is MissingPluginException || error is UnimplementedError;

    return DisplayRefreshRateException(
      code: isMissingApi ? 'unsupported_on_platform' : 'refresh_rate_operation_failed',
      message: isMissingApi
          ? 'The display refresh-rate API is not available on this platform.'
          : 'The display refresh-rate operation failed.',
      details: <String, Object?>{'errorType': error.runtimeType.toString()},
      cause: error,
    );
  }
}
