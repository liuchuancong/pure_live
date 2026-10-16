import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:live_device/src/network/adapter/ip_address.dart';
import 'package:live_device/src/network/adapter/network_adapter.dart';
import 'package:live_device/src/network/adapter/network_adapter_capabilities.dart';
import 'package:live_device/src/network/adapter/network_adapter_exception.dart';
import 'package:live_device/src/network/adapter/network_adapter_service.dart';

/// Default [NetworkAdapterService] implementation backed by `dart:io`.
///
/// There is no plugin here, and that is the point: the operating system already
/// knows every adapter and address, so this adapter reads it directly instead of
/// going through a channel that truncates the answer to one address.
final class PlatformNetworkAdapterService implements NetworkAdapterService {
  /// Creates a service that reads the host's interface table.
  const new();

  @override
  Future<List<NetworkAdapter>> read({bool includeLoopback = false, bool includeLinkLocal = false}) => _guard(() async {
    final interfaces = await io.NetworkInterface.list(
      includeLoopback: includeLoopback,
      includeLinkLocal: includeLinkLocal,
    );
    return interfaces.map(_toAdapter).toList(growable: false);
  });

  @override
  Future<NetworkAdapterCapabilities> getCapabilities() async {
    // `dart:io` is not part of a web build, so this service cannot answer there
    // at all; the flag exists so callers on the other platforms can still tell
    // enumeration apart from an empty interface table.
    if (kIsWeb) {
      return const NetworkAdapterCapabilities(canEnumerateAdapters: false, platformName: 'web');
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

    return NetworkAdapterCapabilities(canEnumerateAdapters: supported, platformName: platform.name);
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on NetworkAdapterException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(_normalizeError(error), stackTrace);
    }
  }

  NetworkAdapter _toAdapter(io.NetworkInterface interface) => NetworkAdapter(
    name: interface.name,
    index: interface.index,
    addresses: interface.addresses.map(_toAddress).toList(growable: false),
  );

  /// An `InterfaceAddress` is itself an `InternetAddress`, so its textual value,
  /// family and broadcast come off the same object.
  IpAddress _toAddress(io.InterfaceAddress address) => IpAddress(
    value: address.address,
    version: _versionOf(address),
    prefixLength: address.prefixLength,
    broadcast: address.broadcast?.address,
  );

  /// `InternetAddressType` is a class of constant instances rather than an enum,
  /// so there is no exhaustive switch to lean on here.
  IpAddressVersion _versionOf(io.InternetAddress address) {
    if (address.type == io.InternetAddressType.IPv4) {
      return IpAddressVersion.ipv4;
    }
    if (address.type == io.InternetAddressType.IPv6) {
      return IpAddressVersion.ipv6;
    }
    return IpAddressVersion.unknown;
  }

  NetworkAdapterException _normalizeError(Object error) {
    if (error is NetworkAdapterException) {
      return error;
    }

    final isUnsupported = error is UnsupportedError;

    return NetworkAdapterException(
      code: isUnsupported ? 'unsupported_on_platform' : 'network_adapter_read_failed',
      message: isUnsupported
          ? 'Network adapter enumeration is not available on this platform.'
          : 'Listing the network adapters failed.',
      details: <String, Object?>{'errorType': error.runtimeType.toString()},
      cause: error,
    );
  }
}
