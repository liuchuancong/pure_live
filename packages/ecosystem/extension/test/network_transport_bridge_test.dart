// Module: test/network_transport_bridge_test.dart
// Purpose: Verify that the extension network exit reaches the shared client and comes back as platform types.
// Author: liuchuancong
// Created: 2026-10-09
//
// The adapter is scripted, so nothing here touches a socket. What is being proven is the crossing: the
// platform's NetworkRequest in, the platform's NetworkResponse out, the policy's timeout carried through to
// the client, and an L0 NetworkFailure surfaced as a platform error rather than as a foundation type.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live_extension/pure_live_extension.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_permission/pure_live_permission.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:test/test.dart';

final class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.onCall);

  final ResponseBody Function(RequestOptions options) onCall;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return onCall(options);
  }

  @override
  void close({bool force = false}) {}
}

final class _Grants implements PermissionManager {
  _Grants(this.allowed);

  bool allowed;

  @override
  Future<void> register(ExtensionDescriptor descriptor) async {}

  @override
  Future<PermissionDecision> check(ExtensionId extensionId, Permission permission, {Uri? target}) async {
    return allowed
        ? const PermissionDecision.allow(permission: Permission.network)
        : const PermissionDecision.deny(
            permission: Permission.network,
            state: PermissionState.denied,
            reason: 'not granted in this test',
          );
  }

  @override
  Future<PermissionDecision> request(
    ExtensionId extensionId,
    Permission permission, {
    PermissionScope scope = PermissionScope.unrestricted,
  }) async => check(extensionId, permission);

  @override
  Future<void> revoke(ExtensionId extensionId, Permission permission) async {}

  @override
  Future<void> refuse(ExtensionId extensionId, Permission permission) async {}

  @override
  Future<Set<Permission>> held(ExtensionId extensionId) async => const <Permission>{};
}

void main() {
  const extensionId = 'purelive.external.tvbox';
  final request = NetworkRequest(method: 'GET', uri: Uri.parse('https://api.example.test/v1/spider'));

  NetworkClient clientReturning(ResponseBody Function(RequestOptions) body, {NetworkSettings? settings}) {
    return NetworkClient(
      settings: settings ?? NetworkSettings(attempts: 1, retryDelay: Duration.zero),
      adapter: _ScriptedAdapter(body),
    );
  }

  test('test_send_bytesBodyAndHeadersComeBackAsPlatformTypes', () async {
    final transport = NetworkClientTransport(
      client: clientReturning(
        (_) => ResponseBody.fromString(
          '{"line":1}',
          200,
          headers: <String, List<String>>{
            'content-type': <String>['application/json'],
          },
        ),
      ),
    );

    final response = await transport.send(request);

    expect(response.statusCode, 200);
    expect(response.isSuccess, isTrue);
    expect(response.finalUri, Uri.parse('https://api.example.test/v1/spider'));
    expect(response.headers['content-type'], 'application/json');
    expect(utf8.decode(response.body), '{"line":1}');
  });

  test('test_send_methodAndHeadersPassThroughToTheClient', () async {
    final adapter = _ScriptedAdapter((_) => ResponseBody.fromString('ok', 200));
    final transport = NetworkClientTransport(
      client: NetworkClient(
        settings: const NetworkSettings(attempts: 1, retryDelay: Duration.zero),
        adapter: adapter,
      ),
    );

    await transport.send(
      NetworkRequest(
        method: 'POST',
        uri: request.uri,
        headers: const <String, String>{'x-device': 'tv'},
        body: '{"q":"x"}',
      ),
    );

    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.headers['x-device'], 'tv');
    expect(adapter.requests.single.responseType, ResponseType.bytes);
  });

  test('test_send_timeoutAskedByThePolicyReachesTheClient', () async {
    final adapter = _ScriptedAdapter((_) => ResponseBody.fromString('ok', 200));
    final transport = NetworkClientTransport(
      client: NetworkClient(
        settings: const NetworkSettings(attempts: 1, retryDelay: Duration.zero),
        adapter: adapter,
      ),
    );

    await transport.send(NetworkRequest(method: 'GET', uri: request.uri, timeout: const Duration(seconds: 4)));

    expect(adapter.requests.single.receiveTimeout, const Duration(seconds: 4));
  });

  test('test_send_networkFailure_becomesAPlatformErrorNotAnL0Type', () async {
    final transport = NetworkClientTransport(client: clientReturning((_) => ResponseBody.fromString('nope', 403)));

    await expectLater(
      transport.send(request),
      throwsA(isA<ExtensionNetworkException>().having((e) => e.code, 'code', PlatformErrorCodes.networkForbidden)),
    );
  });

  test('test_send_oversizedBody_isReportedAsThePlatformCode', () async {
    final transport = NetworkClientTransport(
      client: clientReturning(
        (_) => ResponseBody.fromBytes(List<int>.filled(4096, 1), 200),
        settings: NetworkSettings(attempts: 1, retryDelay: Duration.zero, maxResponseBytes: 1024),
      ),
    );

    await expectLater(
      transport.send(request),
      throwsA(
        isA<ExtensionNetworkException>()
            .having((e) => e.code, 'code', PlatformErrorCodes.networkResponseTooLarge)
            .having((e) => e.error.retryable, 'retryable', isFalse),
      ),
    );
  });

  test('test_policyBackedNetwork_withTheRealClient_stillRefusesUngrantedHostsFirst', () async {
    var reached = 0;
    final transport = NetworkClientTransport(
      client: clientReturning((options) {
        reached++;
        return ResponseBody.fromString('ok', 200);
      }),
    );
    final grants = _Grants(false);
    final network = PolicyBackedExtensionNetwork(permissions: grants, transport: transport);

    await expectLater(
      network.send(extensionId, request),
      throwsA(isA<ExtensionNetworkException>().having((e) => e.code, 'code', PlatformErrorCodes.permissionDenied)),
    );
    expect(reached, 0, reason: 'a refusal must not cost a socket');

    grants.allowed = true;
    expect(await network.send(extensionId, request), isA<NetworkResponse>());
    expect(reached, 1);
  });

  test('test_dispose_onlyClosesAClientTheTransportCreated', () async {
    var closes = 0;
    final adapter = _CountingAdapter(() => closes++);
    final client = NetworkClient(settings: const NetworkSettings(attempts: 1), adapter: adapter);

    NetworkClientTransport(client: client).dispose();
    expect(closes, 0, reason: 'a borrowed client belongs to its owner');

    NetworkClientTransport(client: client, ownsClient: true).dispose();
    expect(closes, 1);
  });
}

final class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter(this.onClose);

  final void Function() onClose;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('ok', 200);

  @override
  void close({bool force = false}) => onClose();
}
