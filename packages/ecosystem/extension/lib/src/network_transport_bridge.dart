// Module: lib/src/network_transport_bridge.dart
// Purpose: The bridge that lets an extension's network exit actually reach the internet through the shared client.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/contracts/platform-contracts.md section 15 (ExtensionNetwork is a plugin's only exit, and the
// platform enforces host, timeout, size and concurrency around it). The enforcement lives in
// pure_live_permission's PolicyBackedExtensionNetwork; this file supplies the transport underneath it, so
// the HTTP implementation stays in the foundation layer and the contract stays testable without one.
//
// Failures cross here as PlatformErrorInfo-carrying exceptions rather than as NetworkFailure: an extension
// must not learn a foundation type, or every L0 change would be a plugin-visible break.

import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_permission/pure_live_permission.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

/// A [NetworkTransport] backed by [NetworkClient.sendBytes].
final class NetworkClientTransport implements NetworkTransport {
  /// A passed-in client is borrowed: it usually serves other callers, so closing it here would take their
  /// connection pool down too. Only a client this transport created is its to close.
  NetworkClientTransport({NetworkClient? client, bool? ownsClient})
    : _client = client ?? NetworkClient(),
      _ownsClient = ownsClient ?? (client == null);

  final NetworkClient _client;
  final bool _ownsClient;

  @override
  Future<NetworkResponse> send(NetworkRequest request) async {
    try {
      final raw = await _client.sendBytes(
        request.uri.toString(),
        method: request.method,
        body: request.body,
        headers: request.headers,
        // The policy already clamped this; passing it through is what makes NetworkLimits.maxTimeout real
        // rather than advisory.
        timeout: request.effectiveTimeout,
      );
      return NetworkResponse(statusCode: raw.statusCode, finalUri: raw.uri, headers: raw.headers, body: raw.bytes);
    } on NetworkFailure catch (failure) {
      throw ExtensionNetworkException(
        PlatformErrorInfo(
          code: failure.code,
          message: '${failure.method} ${failure.url} failed: ${failure.cause ?? failure.kind.name}',
          category: PlatformErrorCategory.network,
          retryable: failure.retryable,
          metadata: <String, Object?>{
            'platform.status_code': failure.statusCode,
            'network.failure_kind': failure.kind.name,
          },
        ),
      );
    }
  }

  /// Closes the underlying client when this transport created it.
  void dispose({bool force = false}) {
    if (_ownsClient) {
      _client.close(force: force);
    }
  }
}
