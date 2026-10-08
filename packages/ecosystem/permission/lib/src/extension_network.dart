// Module: lib/src/extension_network.dart
// Purpose: The extension network exit: permission check, host scope, timeout, size and concurrency limits.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-contracts.md section 15 ("插件唯一网络出口") and section 18 (the 15s network
// boundary), plus docs/architecture/platform-infrastructure.md section 7.2, which requires a third party
// source to reach the network only through this exit so host, timeout, response size and concurrency can be
// enforced in one place.

import 'package:pure_live_platform/pure_live_platform.dart';

import 'permission_manager.dart';

/// A request refused by the platform, never by the site.
///
/// It carries a [PlatformErrorInfo] rather than a string so the recovery ladder
/// (docs/media/recovery.md) can branch on the code: permission.denied asks the user, permission.restricted
/// disables the source, network.response_too_large does not retry at all.
final class ExtensionNetworkException implements Exception {
  const ExtensionNetworkException(this.error);

  final PlatformErrorInfo error;

  String get code => error.code;

  static ExtensionNetworkException denied(PermissionDecision decision) =>
      ExtensionNetworkException(decision.toErrorInfo());

  static ExtensionNetworkException _withCode(String code, String message, PlatformErrorCategory category) =>
      ExtensionNetworkException(PlatformErrorInfo(code: code, message: message, category: category));

  static ExtensionNetworkException responseTooLarge(int size, int limit) => _withCode(
    PlatformErrorCodes.networkResponseTooLarge,
    'response of $size bytes exceeds the platform limit of $limit',
    PlatformErrorCategory.network,
  );

  static ExtensionNetworkException tooManyRequests(int limit) => _withCode(
    PlatformErrorCodes.networkRateLimited,
    'more than $limit extension requests are in flight; this one is queued out',
    PlatformErrorCategory.network,
  );

  static ExtensionNetworkException redirectEscapedScope(Uri landed, String scope) => _withCode(
    PlatformErrorCodes.permissionRestricted,
    'the response landed on $landed, outside the granted scope $scope',
    PlatformErrorCategory.permission,
  );

  @override
  String toString() => 'ExtensionNetworkException(${error.code}: ${error.message})';
}

/// The bounds the platform puts on every extension request.
final class NetworkLimits {
  const NetworkLimits({
    this.maxTimeout = const Duration(seconds: 30),
    this.maxResponseBytes = 8 * 1024 * 1024,
    this.maxConcurrentRequests = 8,
  });

  /// Hard ceiling on what an extension may ask for. The default per-request timeout stays on
  /// [NetworkRequest.effectiveTimeout]; this only clamps a request that asked for more.
  final Duration maxTimeout;

  /// Response body cap. A source that needs more is downloading, not querying, and belongs to the task
  /// system with its own budget.
  final int maxResponseBytes;

  /// Concurrent in-flight requests per network instance, so one slow source cannot occupy the exit.
  final int maxConcurrentRequests;
}

/// The transport underneath the policy. The wiring layer implements this over the foundation network client
/// so this package stays free of a HTTP dependency and the policy stays testable offline.
abstract interface class NetworkTransport {
  Future<NetworkResponse> send(NetworkRequest request);
}

/// The only network surface an extension is given.
abstract interface class ExtensionNetwork {
  Future<NetworkResponse> send(ExtensionId extensionId, NetworkRequest request);
}

/// An ExtensionNetwork that enforces the permission grant and the platform limits on every call.
final class PolicyBackedExtensionNetwork implements ExtensionNetwork {
  PolicyBackedExtensionNetwork({
    required PermissionManager permissions,
    required NetworkTransport transport,
    this.limits = const NetworkLimits(),
  }) : _permissions = permissions,
       _transport = transport;

  final PermissionManager _permissions;
  final NetworkTransport _transport;
  final NetworkLimits limits;

  int _inFlight = 0;

  /// Requests currently occupying the exit. Exposed so a diagnostics view and a test can read the same
  /// number the gate acts on instead of guessing from timings.
  int get inFlight => _inFlight;

  @override
  Future<NetworkResponse> send(ExtensionId extensionId, NetworkRequest request) async {
    final decision = await _permissions.check(extensionId, Permission.network, target: request.uri);
    if (!decision.allowed) {
      throw ExtensionNetworkException.denied(decision);
    }

    final bounded = _clampTimeout(request);
    if (_inFlight >= limits.maxConcurrentRequests) {
      throw ExtensionNetworkException.tooManyRequests(limits.maxConcurrentRequests);
    }

    _inFlight++;
    try {
      final response = await _transport.send(bounded);
      // A redirect is the one way a granted host reaches an ungranted one, so the landing host is checked
      // against the grant rather than the request the caller wrote.
      if (!decision.scope.allowsUri(response.finalUri)) {
        throw ExtensionNetworkException.redirectEscapedScope(response.finalUri, '${decision.scope}');
      }
      if (response.bodySize > limits.maxResponseBytes) {
        throw ExtensionNetworkException.responseTooLarge(response.bodySize, limits.maxResponseBytes);
      }
      return response;
    } finally {
      _inFlight--;
    }
  }

  NetworkRequest _clampTimeout(NetworkRequest request) {
    final asked = request.timeout;
    if (asked == null || asked <= limits.maxTimeout) {
      return request;
    }
    return NetworkRequest(
      method: request.method,
      uri: request.uri,
      headers: request.headers,
      body: request.body,
      timeout: limits.maxTimeout,
      followRedirects: request.followRedirects,
    );
  }
}
