import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:live_device/src/network/wifi/wifi_info_capabilities.dart';
import 'package:live_device/src/network/wifi/wifi_info_exception.dart';
import 'package:live_device/src/network/wifi/wifi_info_service.dart';
import 'package:live_device/src/network/wifi/wifi_network_info.dart';
import 'package:network_info_plus/network_info_plus.dart' as plugin;

/// Default [WifiInfoService] implementation backed by `network_info_plus`.
///
/// The plugin exposes a singleton facade whose lookups differ per platform: some
/// are missing, some throw and some answer `null`. This adapter keeps that
/// facade and its error types private and turns a per-lookup gap into a `null`
/// value, so one unavailable detail never discards the details that did arrive.
final class PlatformWifiInfoService implements WifiInfoService {
  /// Creates a service using the plugin's shared network-info singleton.
  const new();

  plugin.NetworkInfo get _networkInfo => plugin.NetworkInfo();

  @override
  Future<WifiNetworkInfo> read() async {
    final ssid = await _readField('ssid', _networkInfo.getWifiName);
    final bssid = await _readField('bssid', _networkInfo.getWifiBSSID);
    final ipv4Address = await _readField('ipv4Address', _networkInfo.getWifiIP);
    final ipv6Address = await _readField('ipv6Address', _networkInfo.getWifiIPv6);
    final subnetMask = await _readField('subnetMask', _networkInfo.getWifiSubmask);
    final gatewayAddress = await _readField('gatewayAddress', _networkInfo.getWifiGatewayIP);
    final broadcastName = await _readField('broadcastName', _networkInfo.getWifiBroadcast);

    return WifiNetworkInfo(
      ssid: ssid,
      bssid: bssid,
      ipv4Address: ipv4Address,
      ipv6Address: ipv6Address,
      subnetMask: subnetMask,
      gatewayAddress: gatewayAddress,
      broadcastName: broadcastName,
    );
  }

  @override
  Future<WifiInfoCapabilities> getCapabilities() async {
    if (kIsWeb) {
      return const WifiInfoCapabilities(
        canReadSsid: false,
        canReadAddressing: false,
        canReadBroadcastName: false,
        requiresAndroidLocationPermission: false,
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

    return WifiInfoCapabilities(
      canReadSsid: isSupported,
      canReadAddressing: isSupported,
      canReadBroadcastName: isSupported,
      requiresAndroidLocationPermission: platform == TargetPlatform.android,
      platformName: platform.name,
    );
  }

  /// Reads one value, letting a lookup that this platform does not offer report
  /// nothing instead of failing the read; every other failure is rethrown.
  Future<String?> _readField(String field, Future<String?> Function() lookup) async {
    try {
      return await lookup();
    } on Object catch (error, stackTrace) {
      if (_isUnavailableLookup(error)) {
        return null;
      }
      Error.throwWithStackTrace(_normalizeError(field, error), stackTrace);
    }
  }

  /// A missing backend or an unimplemented lookup means the platform has no such
  /// detail, which is a value (`null`) rather than a failed read.
  static bool _isUnavailableLookup(Object error) =>
      error is UnsupportedError || error is UnimplementedError || error is MissingPluginException;

  WifiInfoException _normalizeError(String field, Object error) {
    if (error is WifiInfoException) {
      return error;
    }

    final isMissingApi = _isUnavailableLookup(error);

    return WifiInfoException(
      code: isMissingApi ? 'unsupported_on_platform' : 'wifi_info_read_failed',
      message: isMissingApi
          ? 'The Wi-Fi information API is not available on this platform.'
          : 'Reading the Wi-Fi "$field" value failed.',
      details: <String, Object?>{'field': field, 'errorType': error.runtimeType.toString()},
      cause: error,
    );
  }
}
