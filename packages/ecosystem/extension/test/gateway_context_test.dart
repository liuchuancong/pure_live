// Module: test/gateway_context_test.dart
// Purpose: Verify what the gateway injects: one scoped context per extension and the permission ceiling.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_extension/pure_live_extension.dart';
import 'package:pure_live_permission/pure_live_permission.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_task/pure_live_task.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  late GatewayHarness harness;
  late InstanceLog log;

  setUp(() {
    harness = GatewayHarness();
    log = InstanceLog();
    harness.runtimes.register(FakeRuntime(log: log));
  });

  tearDown(() async {
    await harness.dispose();
  });

  Future<ExtensionContext> loadContext({String id = 'purelive.fake.one'}) async {
    // A test that loads twice would otherwise see both contexts in one log.
    log.contexts.clear();
    await harness.gateway.register(harness.descriptor(id: id));
    await harness.gateway.load(id);
    return log.contexts.single;
  }

  test('test_load_contextCarriesTheDescriptorOfTheExtensionBeingLoaded', () async {
    final context = await loadContext(id: 'purelive.external.tvbox');

    expect(context.extensionId, 'purelive.external.tvbox');
    expect(context.descriptor.protocol, 'fake');
    expect(context.network, isA<ExtensionNetwork>());
    expect(context.cookies, isA<ExtensionCookieStore>());
    expect(context.permissions, isA<PermissionManager>());
    expect(context.tasks, isA<TaskScheduler>());
    expect(context.cache, isA<ExtensionCache>());
    expect(context.storage, isA<ExtensionStorage>());
    expect(context.diagnostics, isA<DiagnosticTracer>());
  });

  test('test_register_setsThePermissionCeilingFromTheDescriptor', () async {
    final context = await loadContext();

    final declared = await context.permissions.request('purelive.fake.one', Permission.network);
    final undeclared = await context.permissions.request('purelive.fake.one', Permission.device);

    expect(declared.allowed, isTrue);
    expect(undeclared.allowed, isFalse);
    expect(undeclared.state, PermissionState.restricted);
  });

  test('test_extensionCannotUseAnotherExtensionsCache', () async {
    final first = await loadContext(id: 'purelive.fake.one');
    final second = await loadContext(id: 'purelive.fake.two');

    await first.cache.write('repository', 'rows');
    expect(await second.cache.read('repository'), isNull);
    expect(await first.cache.read('repository'), 'rows');
  });

  test('test_extensionCannotReadAnotherExtensionsCookies', () async {
    final first = await loadContext(id: 'purelive.fake.one');
    final second = await loadContext(id: 'purelive.fake.two');
    final site = Uri.parse('https://example.test/');

    await first.permissions.request('purelive.fake.one', Permission.cookie);
    await second.permissions.request('purelive.fake.two', Permission.cookie);
    await first.cookies.set('purelive.fake.one', const Cookie(name: 'sid', value: 'secret', domain: 'example.test'));

    expect(await first.cookies.cookiesFor('purelive.fake.one', site), hasLength(1));
    expect(await second.cookies.cookiesFor('purelive.fake.two', site), isEmpty);
  });

  test('test_extensionNetworkRequest_requiresItsOwnHostGrant', () async {
    final context = await loadContext();
    final request = NetworkRequest(method: 'GET', uri: Uri.parse('https://api.example.test/v1'));

    await expectLater(
      context.network.send('purelive.fake.one', request),
      throwsA(isA<ExtensionNetworkException>().having((e) => e.code, 'code', PlatformErrorCodes.permissionDenied)),
    );

    await context.permissions.request('purelive.fake.one', Permission.network);
    expect(await context.network.send('purelive.fake.one', request), isA<NetworkResponse>());
  });

  test('test_cache_respectsTtlOnRead', () async {
    final context = await loadContext();

    await context.cache.write('live', 'value', ttl: const Duration(milliseconds: -1));

    expect(await context.cache.read('live'), isNull);
    expect(await context.cache.keys(), isEmpty);
  });

  test('test_cache_writeWithoutTtl_staysUntilRemoved', () async {
    final context = await loadContext();

    await context.cache.write('key', 7);
    await context.cache.remove('key');

    expect(await context.cache.read('key'), isNull);
    expect(await context.cache.keys(), isEmpty);
  });

  test('test_storage_persistsAcrossCacheClears', () async {
    final context = await loadContext();

    await context.storage.write('preference', 'dark');
    await context.cache.clear();

    expect(await context.storage.read('preference'), 'dark');
    expect(await context.storage.keys(), <String>['preference']);
    await context.storage.remove('preference');
    expect(await context.storage.read('preference'), isNull);
  });

  test('test_unload_thenReload_getsAFreshCache', () async {
    final first = await loadContext();
    await first.cache.write('repository', 'rows');

    await harness.gateway.start('purelive.fake.one');
    await harness.gateway.unload('purelive.fake.one');
    final second = await loadContext();

    expect(await second.cache.read('repository'), isNull, reason: 'a reload must not inherit the old run');
  });

  test('test_taskScheduler_isTheOneTheHostWired', () async {
    final context = await loadContext();
    final order = <String>[];

    final handle = await context.tasks.submit(_ProbeTask(TaskDescriptor(id: 'epg.update', type: 'epg.update'), order));
    await handle.result;

    expect(order, <String>['epg.update']);
    expect(harness.tasks.find('epg.update')?.state, TaskState.completed);
  });
}

class _ProbeTask implements Task {
  _ProbeTask(this.descriptor, this.order);

  @override
  final TaskDescriptor descriptor;
  final List<String> order;

  @override
  Future<TaskResult> run(TaskContext context) async {
    order.add(descriptor.id);
    return TaskResult.ok();
  }

  @override
  Future<void> cancel() async {}
}
