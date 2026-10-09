// Module: test/runtime_assembly_test.dart
// Purpose: Verify the composition root wires one set of services and that a plugin's rows really reach disk.
// Author: liuchuancong
// Created: 2026-10-09
//
// These are root-level facts: the packages prove their own behaviour in their own tests, and what a root can
// get wrong is wiring - two permission managers where one was intended, a scheduler copied per context, a
// "persistent" view that was never given the store. None of that shows up in a package test.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/app/host.dart';
import 'package:pure_live/app/runtime.dart';
import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_extension/pure_live_extension.dart';
import 'package:pure_live_permission/pure_live_permission.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_resolver/pure_live_resolver.dart';
import 'package:pure_live_task/pure_live_task.dart';

final Directory _dir = Directory.systemTemp.createTempSync('pure_live_runtime');

ExtensionDescriptor _descriptor({
  String id = 'purelive.sample',
  String protocol = 'fake',
  String platformApiVersion = '',
  Set<Permission> permissions = const <Permission>{Permission.network, Permission.cookie},
}) {
  return ExtensionDescriptor(
    id: id,
    name: 'Sample',
    version: '1.0.0',
    protocol: protocol,
    platformApiVersion: platformApiVersion,
    type: ExtensionType.external,
    permissions: permissions,
  );
}

/// The instance the fake runtime hands back: it keeps the context so a test can read what was injected.
final class _CapturedInstance implements RuntimeInstance {
  _CapturedInstance(this.descriptor, this.context);

  @override
  final ExtensionDescriptor descriptor;
  final ExtensionContext context;

  @override
  List<Source> get sources => const <Source>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

final class _CapturingRuntime implements ExtensionRuntime {
  final Set<String> protocols = const <String>{'fake'};
  final List<ExtensionContext> contexts = <ExtensionContext>[];

  @override
  RuntimeDescriptor get descriptor =>
      RuntimeDescriptor(id: 'fake_runtime', name: 'Fake', version: '1.0.0', protocols: protocols);

  @override
  bool canHandle(ExtensionDescriptor descriptor) => protocols.contains(descriptor.protocol);

  @override
  Future<RuntimeInstance> load(ExtensionDescriptor descriptor, ExtensionContext context) async {
    contexts.add(context);
    return _CapturedInstance(descriptor, context);
  }
}

/// A task that records it ran, so the identity test can prove which scheduler answered.
final class _MarkerTask implements Task {
  _MarkerTask(this.descriptor, this.ran);

  @override
  final TaskDescriptor descriptor;
  final List<String> ran;

  @override
  Future<TaskResult> run(TaskContext context) async {
    ran.add(descriptor.id);
    return TaskResult.ok();
  }

  @override
  Future<void> cancel() async {}
}

Future<PureLiveRuntime> _boot({
  Set<String> supportedApiVersions = const <String>{},
  PermissionPrompt permissionPrompt = const UnaskedPrompts(),
}) async {
  final runtime = await PureLiveRuntime.boot(
    dataDirectory: _dir,
    supportedApiVersions: supportedApiVersions,
    permissionPrompt: permissionPrompt,
  );
  runtime.runtimes.register(_CapturingRuntime());
  return runtime;
}

/// Boots, registers and loads one extension, returning the runtime with the context it injected.
Future<(PureLiveRuntime, ExtensionContext)> _loaded({
  String id = 'purelive.sample',
  Set<Permission> permissions = const <Permission>{Permission.network, Permission.cookie},
  String platformApiVersion = '',
}) async {
  final runtime = await _boot();
  await runtime.gateway.register(_descriptor(id: id, permissions: permissions, platformApiVersion: platformApiVersion));
  await runtime.gateway.load(id);
  return (runtime, (runtime.runtimes.all.single as _CapturingRuntime).contexts.single);
}

void main() {
  tearDownAll(() {
    if (_dir.existsSync()) {
      _dir.deleteSync(recursive: true);
    }
  });

  group('test_runtime_wiring', () {
    test('test_boot_givesTheContextTheRuntimesOwnScheduler', () async {
      final (runtime, context) = await _loaded();
      final ran = <String>[];

      await (await context.tasks.submit(_MarkerTask(TaskDescriptor(id: 'marker', type: 'test'), ran))).result;

      expect(ran, <String>['marker']);
      // The same object, not a structurally equal copy: a second scheduler would run the plugin's work
      // outside the platform's limits.
      expect(identical(context.tasks, runtime.tasks), isTrue);
      expect(runtime.tasks.find('marker')?.state, TaskState.completed);
      expect(identical(context.permissions, runtime.permissions), isTrue);
    });

    test('test_boot_undeclaredPermission_stopsBeforeTheSocket', () async {
      // Proof that the gateway's network consults this runtime's permission manager: a denied call never
      // reaches NetworkClientTransport, so an ungranted plugin could not touch the network even once. A real
      // socket attempt would surface as a network error code instead of a permission one.
      final (runtime, context) = await _loaded(
        id: 'purelive.cookieonly',
        permissions: const <Permission>{Permission.cookie},
      );

      // The code is `permission.denied` (never requested) rather than `permission.restricted` (outside the
      // declared ceiling) because the gate asks `check`, which reports an absent grant as unknown-and-recoverable.
      // Which code belongs to which state is pinned in pure_live_permission's own tests, not here.
      await expectLater(
        context.network.send(
          'purelive.cookieonly',
          NetworkRequest(method: 'GET', uri: Uri.parse('https://example.test/never-requested')),
        ),
        throwsA(
          isA<ExtensionNetworkException>().having((e) => e.error.code, 'code', PlatformErrorCodes.permissionDenied),
        ),
      );
      expect(runtime.diagnostics.events, isNotEmpty);
    });

    test('test_boot_startsEmptyAndTheChainReadsTheSameRegistry', () async {
      final runtime = await _boot();

      expect(runtime.capabilities.isEmpty, isTrue);
      expect(runtime.resolvers.all, isEmpty);
      await expectLater(
        runtime.resolverChain.resolve(
          ResolveRequest(
            ref: ContentRef(sourceId: 's', contentId: 'c', kind: ContentKind.liveChannel),
          ),
        ),
        throwsA(isA<ResolverException>().having((e) => e.code, 'code', PlatformErrorCodes.resolverUnsupported)),
      );

      runtime.resolvers.register(_StubResolver());
      expect(
        await runtime.resolverChain.resolve(
          ResolveRequest(
            ref: ContentRef(sourceId: 's', contentId: 'c', kind: ContentKind.liveChannel),
          ),
        ),
        isNotNull,
      );
    });

    test('test_supportedApiVersions_isTheGateTheRootChooses', () async {
      final runtime = await _boot(supportedApiVersions: const <String>{'2'});

      await expectLater(
        runtime.gateway.register(_descriptor(id: 'purelive.old', platformApiVersion: '1')),
        throwsA(
          isA<ExtensionGatewayException>().having((e) => e.code, 'code', PlatformErrorCodes.extensionIncompatible),
        ),
      );
      expect(runtime.gateway.find('purelive.old')!.lifecycle, ExtensionLifecycleState.incompatible);

      await runtime.gateway.register(_descriptor(id: 'purelive.current', platformApiVersion: '2'));
      await runtime.gateway.load('purelive.current');
      expect(runtime.gateway.find('purelive.current')!.lifecycle, ExtensionLifecycleState.ready);
    });
  });

  group('test_runtime_durability', () {
    test('test_pluginRows_writtenThroughTheContext_landOnDiskAndOutliveTheRuntime', () async {
      final (first, context) = await _loaded(id: 'purelive.durable');
      await context.storage.write('quality', '1080p');
      await context.cache.write('repository', 'rows');
      await first.dispose();

      final file = File('${_dir.path}${Platform.pathSeparator}extensions.json');
      expect(file.existsSync(), isTrue);
      final stored = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      expect(stored.containsKey('extension.purelive.durable.storage.quality'), isTrue);
      expect(stored.containsKey('extension.purelive.durable.cache.repository'), isTrue);

      // A second boot is what a restart looks like; only the directory is shared.
      final (second, reloaded) = await _loaded(id: 'purelive.durable');
      expect(await reloaded.storage.read('quality'), '1080p');
      expect(await reloaded.cache.read('repository'), 'rows');
      await second.dispose();
    });

    test('test_twoExtensions_doNotShareRowsThroughTheOneStore', () async {
      final (runtime, one) = await _loaded(id: 'purelive.one');
      await one.storage.write('token', 'first');

      await runtime.gateway.register(_descriptor(id: 'purelive.two'));
      await runtime.gateway.load('purelive.two');
      final two = (runtime.runtimes.all.single as _CapturingRuntime).contexts.last;

      expect(await two.storage.read('token'), isNull);
      await runtime.dispose();
    });

    test('test_grantedPermission_stillHoldsAfterAReboot', () async {
      // The whole point of making grants durable: an answer given once is not asked again on the next boot,
      // and the second runtime does not even need a prompt that can answer.
      final first = await _boot(permissionPrompt: const GrantDeclaredPrompts());
      await first.gateway.register(_descriptor(id: 'purelive.grantor'));
      await first.gateway.load('purelive.grantor');
      final context = (first.runtimes.all.single as _CapturingRuntime).contexts.single;

      expect((await context.permissions.request('purelive.grantor', Permission.network)).allowed, isTrue);
      await first.dispose();

      final second = await _boot();
      await second.gateway.register(_descriptor(id: 'purelive.grantor'));

      final remembered = await second.permissions.check('purelive.grantor', Permission.network);
      expect(remembered.allowed, isTrue);
      expect(remembered.state, PermissionState.granted);
      await second.dispose();
    });
  });

  group('test_host', () {
    testWidgets('test_host_rendersTheAssembledRuntime', (tester) async {
      final runtime = await _boot();
      runtime.capabilities.register(
        ProviderRegistration(
          sourceId: 'purelive.sample.vod',
          extensionId: 'purelive.sample',
          provider: Object(),
          capabilities: const CapabilitySet(<CapabilityKind>{CapabilityKind.vod}),
        ),
      );

      await tester.pumpWidget(PureLiveApp(runtime: runtime));

      expect(find.text('运行时已装配'), findsOneWidget);
      expect(find.text('能力发现: 1 个 provider'), findsOneWidget);
      expect(find.textContaining('extension.purelive.sample'), findsNothing);
    });
  });
}

/// A resolver that answers one live reference, so the chain test can tell "wired" from "empty".
final class _StubResolver implements Resolver {
  @override
  ResolverDescriptor get descriptor => const ResolverDescriptor(id: 'stub', name: 'Stub', kind: ResolverKind.live);

  @override
  bool canResolve(ContentRef ref) => ref.kind == ContentKind.liveChannel;

  @override
  Future<ResolveResult> resolve(ResolveRequest request) async {
    final now = DateTime.utc(2026, 10, 9);
    return ResolveResult(
      source: request.ref,
      tickets: <MediaTicket>[
        MediaTicket(
          id: 'stub-ticket',
          uri: Uri.parse('https://example.test/stub.m3u8'),
          kind: MediaKind.live,
          protocol: MediaProtocol.hls,
          createdAt: now,
        ),
      ],
      createdAt: now,
    );
  }
}
