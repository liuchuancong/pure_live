import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart' as plugin;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:live_device/src/network/connectivity/network_connectivity.dart';
import 'package:live_device/src/network/connectivity/network_connectivity_capabilities.dart';
import 'package:live_device/src/network/connectivity/network_connectivity_exception.dart';
import 'package:live_device/src/network/connectivity/network_connectivity_service.dart';
import 'package:live_device/src/network/connectivity/network_interface.dart';

/// Default [NetworkConnectivityService] implementation backed by `connectivity_plus`.
///
/// The plugin exposes a singleton whose event stream is single-subscription and
/// already de-duplicated. This adapter keeps that plugin type, its result enum
/// and its list shape private, and owns exactly one native subscription per
/// stream returned from [watch].
final class PlatformNetworkConnectivityService implements NetworkConnectivityService {
  /// Creates a service using the plugin's shared connectivity singleton.
  const new();

  plugin.Connectivity get _connectivity => plugin.Connectivity();

  @override
  Future<NetworkConnectivity> read() => _guard(() async {
    final results = await _connectivity.checkConnectivity();
    return NetworkConnectivity(interfaces: networkInterfacesFromResults(results));
  });

  @override
  Stream<NetworkConnectivity> watch() {
    late final StreamController<NetworkConnectivity> events;
    // Held by the stream and cancelled from onCancel below, so this cannot be
    // cancelled in the function that creates it.
    // ignore: cancel_subscriptions
    StreamSubscription<List<plugin.ConnectivityResult>>? nativeSubscription;

    events = StreamController<NetworkConnectivity>(
      onListen: () {
        try {
          nativeSubscription = _connectivity.onConnectivityChanged.listen(
            (results) => events.add(NetworkConnectivity(interfaces: networkInterfacesFromResults(results))),
            onError: (Object error, StackTrace stackTrace) {
              events.addError(_normalizeError(error), stackTrace);
            },
            onDone: () => unawaited(events.close()),
          );
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
  Future<NetworkConnectivityCapabilities> getCapabilities() async {
    if (kIsWeb) {
      return const NetworkConnectivityCapabilities(
        canRead: true,
        canObserve: true,
        reportsCellular: false,
        reportsWifi: true,
        platformName: 'web',
      );
    }

    final platform = defaultTargetPlatform;
    final isSupported = switch (platform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      TargetPlatform.fuchsia => false,
    };
    final reportsCellular = switch (platform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.fuchsia => false,
    };

    return NetworkConnectivityCapabilities(
      canRead: isSupported,
      canObserve: isSupported,
      reportsCellular: reportsCellular,
      reportsWifi: isSupported,
      platformName: platform.name,
    );
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on NetworkConnectivityException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(_normalizeError(error), stackTrace);
    }
  }

  NetworkConnectivityException _normalizeError(Object error) {
    if (error is NetworkConnectivityException) {
      return error;
    }

    final isMissingApi = error is MissingPluginException || error is UnimplementedError;

    return NetworkConnectivityException(
      code: isMissingApi ? 'unsupported_on_platform' : 'network_connectivity_operation_failed',
      message: isMissingApi
          ? 'The network-connectivity API is not available on this platform.'
          : 'The network-connectivity operation failed.',
      details: <String, Object?>{'errorType': error.runtimeType.toString()},
      cause: error,
    );
  }
}

/// Maps the interfaces named by a connectivity report to [NetworkInterface]
/// values, de-duplicated.
///
/// This is the only place the plugin's result values are read. The helper is
/// kept out of the exported `live_device` API so callers cannot reach a plugin
/// type; it is public only so the table below can be tested without a platform
/// channel.
@visibleForTesting
Set<NetworkInterface> networkInterfacesFromResults(Iterable<plugin.ConnectivityResult> results) =>
    results.map(_networkInterfaceFromResult).toSet();

NetworkInterface _networkInterfaceFromResult(plugin.ConnectivityResult result) => switch (result) {
  plugin.ConnectivityResult.bluetooth => NetworkInterface.bluetooth,
  plugin.ConnectivityResult.wifi => NetworkInterface.wifi,
  plugin.ConnectivityResult.ethernet => NetworkInterface.ethernet,
  plugin.ConnectivityResult.mobile => NetworkInterface.cellular,
  plugin.ConnectivityResult.none => NetworkInterface.none,
  plugin.ConnectivityResult.vpn => NetworkInterface.vpn,
  plugin.ConnectivityResult.satellite => NetworkInterface.satellite,
  plugin.ConnectivityResult.other => NetworkInterface.other,
};
