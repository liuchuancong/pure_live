// Module: test/support/fakes.dart
// Purpose: The runtime, instance and source fakes the gateway tests drive, plus the wiring they need.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_extension/pure_live_extension.dart';
import 'package:pure_live_permission/pure_live_permission.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_task/pure_live_task.dart';

/// The calls a hosted extension made, in order, so a test can read the sequence instead of inferring it.
class InstanceLog {
  final List<String> calls = <String>[];
  final List<ExtensionContext> contexts = <ExtensionContext>[];

  bool get disposed => calls.contains('dispose');
}

class FakeInstance implements RuntimeInstance {
  FakeInstance(this.descriptor, this.log, {this.sourceCount = 1, this.failOn});

  @override
  final ExtensionDescriptor descriptor;
  final InstanceLog log;
  final int sourceCount;

  /// Which lifecycle step should throw, if any.
  final String? failOn;

  @override
  List<Source> get sources => List<Source>.generate(sourceCount, (index) => FakeSource(descriptor, index));

  @override
  Future<void> initialize() => _step('initialize');

  @override
  Future<void> start() => _step('start');

  @override
  Future<void> stop() => _step('stop');

  @override
  Future<void> dispose() => _step('dispose');

  Future<void> _step(String name) async {
    log.calls.add(name);
    if (failOn == name) {
      throw StateError('$name failed on purpose');
    }
  }
}

class FakeSource implements Source {
  FakeSource(this.extensionDescriptor, this.index) : _id = '${extensionDescriptor.id}.source_$index';

  final ExtensionDescriptor extensionDescriptor;
  final int index;
  final String _id;

  @override
  late final SourceDescriptor descriptor = SourceDescriptor(
    id: _id,
    extensionId: extensionDescriptor.id,
    runtimeId: 'fake_runtime',
    uri: 'https://example.test/$_id.json',
    name: extensionDescriptor.name,
    type: SourceType.url,
  );

  @override
  SourceState state = SourceState.created;

  @override
  Future<void> initialize() async {
    state = SourceState.ready;
  }

  @override
  Future<void> refresh() async {
    state = SourceState.refreshing;
  }

  @override
  Future<void> dispose() async {
    state = SourceState.disposed;
  }
}

class FakeRuntime implements ExtensionRuntime {
  FakeRuntime({
    String id = 'fake_runtime',
    this.protocols = const <String>{'fake'},
    this.log,
    this.sourceCount = 1,
    this.failOn,
    this.throwOnLoad = false,
  }) : descriptor = RuntimeDescriptor(id: id, name: id, version: '1.0.0', protocols: protocols);

  @override
  final RuntimeDescriptor descriptor;
  final Set<String> protocols;
  final InstanceLog? log;
  final int sourceCount;

  /// Mutable so a test can fail the first attempt and then succeed on the retry.
  String? failOn;
  final bool throwOnLoad;

  @override
  bool canHandle(ExtensionDescriptor descriptor) => protocols.contains(descriptor.protocol);

  @override
  Future<RuntimeInstance> load(ExtensionDescriptor descriptor, ExtensionContext context) async {
    if (throwOnLoad) {
      throw StateError('the manifest could not be read');
    }
    log?.contexts.add(context);
    return FakeInstance(descriptor, log ?? InstanceLog(), sourceCount: sourceCount, failOn: failOn);
  }
}

class FakeTransport implements NetworkTransport {
  @override
  Future<NetworkResponse> send(NetworkRequest request) async =>
      NetworkResponse(statusCode: 200, finalUri: request.uri, body: const <int>[1]);
}

/// The wiring a host would build, assembled from the real service packages.
class GatewayHarness {
  GatewayHarness({Set<String> supportedApiVersions = const <String>{}})
    : permissions = PolicyPermissionManager(store: InMemoryPermissionStore(), prompt: const GrantDeclaredPrompts()),
      tasks = InMemoryTaskScheduler(),
      runtimes = RuntimeRegistry() {
    final network = PolicyBackedExtensionNetwork(permissions: permissions, transport: FakeTransport());
    gateway = ManagedExtensionGateway(
      runtimes: runtimes,
      permissions: permissions,
      network: network,
      cookies: PolicyBackedCookieStore(permissions: permissions, jar: InMemoryCookieJar()),
      tasks: tasks,
      supportedApiVersions: supportedApiVersions,
    );
  }

  final PolicyPermissionManager permissions;
  final InMemoryTaskScheduler tasks;
  final RuntimeRegistry runtimes;

  late final ManagedExtensionGateway gateway;

  /// A descriptor carrying what the platform needs in order to host the extension at all.
  ExtensionDescriptor descriptor({
    String id = 'purelive.fake.one',
    String protocol = 'fake',
    String platformApiVersion = '',
    Set<Permission> permissions = const <Permission>{Permission.network, Permission.cookie},
  }) {
    return ExtensionDescriptor(
      id: id,
      name: id.split('.').last,
      version: '1.0.0',
      protocol: protocol,
      platformApiVersion: platformApiVersion,
      type: ExtensionType.external,
      permissions: permissions,
    );
  }

  Future<void> dispose() async {
    await tasks.dispose();
  }
}
