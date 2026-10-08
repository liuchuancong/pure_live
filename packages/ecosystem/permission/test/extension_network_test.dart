// Module: test/extension_network_test.dart
// Purpose: Verify that the extension network exit enforces the grant, the scope and the platform limits.
// Author: liuchuancong
// Created: 2026-10-08
import 'dart:async';

import 'package:pure_live_permission/pure_live_permission.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:test/test.dart';

const String _id = 'purelive.external.lxmusic';
final Uri _granted = Uri.parse('https://api.example.com/v1/search');

ExtensionDescriptor _descriptor() => ExtensionDescriptor(
  id: _id,
  name: 'LX Music',
  version: '1.0.0',
  protocol: 'lxmusic',
  type: ExtensionType.external,
  permissions: const <Permission>{Permission.network},
);

/// Records what the policy handed down and answers with a canned response.
class _FakeTransport implements NetworkTransport {
  _FakeTransport();

  NetworkResponse? response;
  NetworkRequest? last;
  final List<NetworkRequest> sent = <NetworkRequest>[];

  /// Set when a test needs the request to hang so the concurrency gate can be observed.
  Completer<NetworkResponse>? gate;

  @override
  Future<NetworkResponse> send(NetworkRequest request) async {
    last = request;
    sent.add(request);
    final waiter = gate;
    if (waiter != null) {
      return waiter.future;
    }
    return response ?? NetworkResponse(statusCode: 200, finalUri: request.uri, body: const <int>[1, 2, 3]);
  }
}

void main() {
  late InMemoryPermissionStore store;
  late PolicyPermissionManager permissions;
  late _FakeTransport transport;
  late PolicyBackedExtensionNetwork network;

  Future<void> grantNetwork({PermissionScope scope = PermissionScope.unrestricted}) async {
    await store.save(
      PermissionGrant(
        extensionId: _id,
        permission: Permission.network,
        state: PermissionState.granted,
        grantedAt: DateTime.utc(2026, 10, 8),
        scope: scope,
      ),
    );
  }

  setUp(() async {
    store = InMemoryPermissionStore();
    permissions = PolicyPermissionManager(store: store);
    await permissions.register(_descriptor());
    transport = _FakeTransport();
    network = PolicyBackedExtensionNetwork(permissions: permissions, transport: transport);
  });

  test('test_send_withoutANetworkGrant_isRefusedBeforeTheTransport', () async {
    await expectLater(
      network.send(_id, NetworkRequest(method: 'GET', uri: _granted)),
      throwsA(isA<ExtensionNetworkException>().having((e) => e.code, 'code', PlatformErrorCodes.permissionDenied)),
    );
    expect(transport.sent, isEmpty);
  });

  test('test_send_unregisteredExtension_isRefused', () async {
    await grantNetwork();

    await expectLater(
      network.send('purelive.external.never-registered', NetworkRequest(method: 'GET', uri: _granted)),
      throwsA(isA<ExtensionNetworkException>()),
    );
    expect(transport.sent, isEmpty);
  });

  test('test_send_hostOutsideTheGrant_isRefused', () async {
    await grantNetwork(scope: const PermissionScope(hosts: <String>{'api.example.com'}));

    expect(await network.send(_id, NetworkRequest(method: 'GET', uri: _granted)), isA<NetworkResponse>());
    await expectLater(
      network.send(_id, NetworkRequest(method: 'GET', uri: Uri.parse('https://other.com/v1'))),
      throwsA(isA<ExtensionNetworkException>().having((e) => e.code, 'code', PlatformErrorCodes.permissionRestricted)),
    );
  });

  test('test_send_grantedHost_reachesTheTransportAndReturnsTheResponse', () async {
    await grantNetwork();
    final expected = NetworkResponse(statusCode: 204, finalUri: _granted);
    transport.response = expected;

    final response = await network.send(_id, NetworkRequest(method: 'GET', uri: _granted));

    expect(response, expected);
    expect(transport.last?.uri, _granted);
    expect(network.inFlight, 0);
  });

  test('test_send_timeoutBeyondTheCeiling_isClampedBeforeSending', () async {
    await grantNetwork();
    network = PolicyBackedExtensionNetwork(
      permissions: permissions,
      transport: transport,
      limits: const NetworkLimits(maxTimeout: Duration(seconds: 5)),
    );

    await network.send(_id, NetworkRequest(method: 'GET', uri: _granted, timeout: const Duration(seconds: 120)));

    expect(transport.last?.timeout, const Duration(seconds: 5));
  });

  test('test_send_timeoutInsideTheCeiling_isLeftAlone', () async {
    await grantNetwork();

    await network.send(_id, NetworkRequest(method: 'GET', uri: _granted, timeout: const Duration(seconds: 3)));

    expect(transport.last?.timeout, const Duration(seconds: 3));
    expect(transport.last?.uri, _granted);
  });

  test('test_send_redirectLandsOutsideTheGrant_isRefusedAfterTheFact', () async {
    // The grant names one host; a redirect to another is the escape this check exists for.
    await grantNetwork(scope: const PermissionScope(hosts: <String>{'api.example.com'}));
    transport.response = NetworkResponse(
      statusCode: 200,
      finalUri: Uri.parse('https://tracker.example.net/payload'),
      body: const <int>[1],
    );

    await expectLater(
      network.send(_id, NetworkRequest(method: 'GET', uri: _granted)),
      throwsA(
        isA<ExtensionNetworkException>()
            .having((e) => e.code, 'code', PlatformErrorCodes.permissionRestricted)
            .having((e) => e.toString(), 'text', contains('tracker.example.net')),
      ),
    );
  });

  test('test_send_responseOverTheSizeCap_isRefused', () async {
    await grantNetwork();
    network = PolicyBackedExtensionNetwork(
      permissions: permissions,
      transport: transport,
      limits: const NetworkLimits(maxResponseBytes: 2),
    );

    await expectLater(
      network.send(_id, NetworkRequest(method: 'GET', uri: _granted)),
      throwsA(
        isA<ExtensionNetworkException>().having((e) => e.code, 'code', PlatformErrorCodes.networkResponseTooLarge),
      ),
    );
    expect(network.inFlight, 0);
  });

  test('test_send_concurrencyCap_refusesTheExtraRequestAndReleasesAfterwards', () async {
    await grantNetwork();
    final gate = Completer<NetworkResponse>();
    transport.gate = gate;
    network = PolicyBackedExtensionNetwork(
      permissions: permissions,
      transport: transport,
      limits: const NetworkLimits(maxConcurrentRequests: 2),
    );

    final first = network.send(_id, NetworkRequest(method: 'GET', uri: _granted));
    final second = network.send(_id, NetworkRequest(method: 'GET', uri: _granted));
    await Future<void>.delayed(Duration.zero);
    expect(network.inFlight, 2);

    await expectLater(
      network.send(_id, NetworkRequest(method: 'GET', uri: _granted)),
      throwsA(isA<ExtensionNetworkException>().having((e) => e.code, 'code', PlatformErrorCodes.networkRateLimited)),
    );

    gate.complete(NetworkResponse(statusCode: 200, finalUri: _granted));
    await Future.wait(<Future<NetworkResponse>>[first, second]);
    expect(network.inFlight, 0);
  });
}
