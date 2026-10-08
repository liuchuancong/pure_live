// Module: test/gateway_lifecycle_test.dart
// Purpose: Verify the gateway's lifecycle machine, runtime selection and the errors its transitions throw.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_extension/pure_live_extension.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  late GatewayHarness harness;

  setUp(() {
    harness = GatewayHarness();
  });

  tearDown(() async {
    await harness.dispose();
  });

  Future<void> registerAndLoad({
    String id = 'purelive.fake.one',
    InstanceLog? log,
    int sourceCount = 1,
    String? failOn,
  }) async {
    harness.runtimes.register(FakeRuntime(log: log ?? InstanceLog(), sourceCount: sourceCount, failOn: failOn));
    await harness.gateway.register(harness.descriptor(id: id));
    await harness.gateway.load(id);
  }

  group('happy path', () {
    test('test_registerLoadStartStopUnload_walksTheDocumentedStates', () async {
      final log = InstanceLog();
      harness.runtimes.register(FakeRuntime(log: log));
      final descriptor = harness.descriptor();
      final seen = <ExtensionLifecycleState>[];
      harness.gateway.changes.listen((status) => seen.add(status.lifecycle));

      await harness.gateway.register(descriptor);
      await harness.gateway.load(descriptor.id);
      await harness.gateway.start(descriptor.id);
      await harness.gateway.stop(descriptor.id);
      await harness.gateway.unload(descriptor.id);
      await Future<void>.delayed(Duration.zero);

      expect(seen, <ExtensionLifecycleState>[
        ExtensionLifecycleState.identified,
        ExtensionLifecycleState.loading,
        ExtensionLifecycleState.validating,
        ExtensionLifecycleState.ready,
        ExtensionLifecycleState.running,
        ExtensionLifecycleState.stopping,
        ExtensionLifecycleState.ready,
        ExtensionLifecycleState.unloaded,
      ]);
      expect(log.calls, <String>['initialize', 'start', 'stop', 'dispose']);
      expect(harness.gateway.find(descriptor.id), isNull);
      expect(harness.gateway.getAll(), isEmpty);
    });

    test('test_load_exposesTheRuntimeAndItsSources', () async {
      await registerAndLoad(sourceCount: 2);
      await harness.gateway.start('purelive.fake.one');

      final handle = harness.gateway.find('purelive.fake.one')!;

      expect(handle.runtimeId, 'fake_runtime');
      expect(handle.lifecycle, ExtensionLifecycleState.running);
      expect(handle.isRunning, isTrue);
      expect(handle.isUsable, isTrue);
      expect(handle.health, RuntimeHealth.healthy);
      expect(handle.sources.map((source) => source.descriptor.id), <String>{
        'purelive.fake.one.source_0',
        'purelive.fake.one.source_1',
      });
      expect('$handle', contains('running'));
    });

    test('test_find_unknownId_returnsNullAndTransitionsThrowNotFound', () async {
      expect(harness.gateway.find('never'), isNull);
      await expectLater(
        harness.gateway.load('never'),
        throwsA(isA<ExtensionGatewayException>().having((e) => e.code, 'code', PlatformErrorCodes.extensionNotFound)),
      );
    });
  });

  group('selection', () {
    test('test_register_protocolWithoutRuntime_isRecordedAsIncompatible', () async {
      harness.runtimes.register(FakeRuntime());
      final descriptor = harness.descriptor(protocol: 'xmltv');

      await expectLater(
        harness.gateway.register(descriptor),
        throwsA(
          isA<ExtensionGatewayException>()
              .having((e) => e.code, 'code', PlatformErrorCodes.extensionIncompatible)
              .having((e) => e.toString(), 'text', contains('xmltv')),
        ),
      );

      final handle = harness.gateway.find(descriptor.id)!;
      expect(handle.lifecycle, ExtensionLifecycleState.incompatible);
      expect(handle.health, RuntimeHealth.unavailable);
      expect(handle.error?.code, PlatformErrorCodes.extensionIncompatible);
      await expectLater(
        harness.gateway.load(descriptor.id),
        throwsA(isA<ExtensionGatewayException>().having((e) => e.code, 'code', 'extension.state_invalid')),
      );
    });

    test('test_register_firstMatchingRuntimeWins', () async {
      final secondLog = InstanceLog();
      harness.runtimes.register(FakeRuntime(id: 'runtime_a', log: InstanceLog()));
      harness.runtimes.register(FakeRuntime(id: 'runtime_b', log: secondLog));

      await harness.gateway.register(harness.descriptor());

      expect(harness.gateway.find('purelive.fake.one')!.runtimeId, 'runtime_a');
      expect(secondLog.calls, isEmpty);
    });

    test('test_register_replacesARuntimeWithTheSameId', () async {
      final replacedLog = InstanceLog();
      harness.runtimes.register(FakeRuntime(id: 'runtime_a', log: replacedLog));
      harness.runtimes.register(FakeRuntime(id: 'runtime_a', log: InstanceLog()));

      expect(harness.runtimes.all, hasLength(1));
      expect(harness.runtimes.byId('runtime_a'), isNotNull);
      expect(harness.runtimes.byId('missing'), isNull);

      await harness.gateway.register(harness.descriptor());
      await harness.gateway.load('purelive.fake.one');

      expect(replacedLog.calls, isEmpty, reason: 'the upgraded runtime is the one that must load it');
    });

    test('test_register_unsupportedApiVersion_isIncompatible', () async {
      harness = GatewayHarness(supportedApiVersions: const <String>{'2'});
      harness.runtimes.register(FakeRuntime(log: InstanceLog()));

      await expectLater(
        harness.gateway.register(harness.descriptor(platformApiVersion: '1')),
        throwsA(
          isA<ExtensionGatewayException>().having((e) => e.code, 'code', PlatformErrorCodes.extensionIncompatible),
        ),
      );
      expect(harness.gateway.find('purelive.fake.one')!.lifecycle, ExtensionLifecycleState.incompatible);

      // The accepted revision loads normally, so the gate is a check and not a blanket refusal.
      await harness.gateway.register(harness.descriptor(id: 'purelive.fake.two', platformApiVersion: '2'));
      await harness.gateway.load('purelive.fake.two');
      expect(harness.gateway.find('purelive.fake.two')!.lifecycle, ExtensionLifecycleState.ready);
    });

    test('test_register_sameTwice_isRefusedUntilUnload', () async {
      harness.runtimes.register(FakeRuntime(log: InstanceLog()));
      final descriptor = harness.descriptor();
      await harness.gateway.register(descriptor);

      await expectLater(
        harness.gateway.register(descriptor),
        throwsA(isA<ExtensionGatewayException>().having((e) => e.code, 'code', 'extension.already_registered')),
      );

      await harness.gateway.unload(descriptor.id);
      await harness.gateway.register(descriptor);
      expect(harness.gateway.find(descriptor.id)!.lifecycle, ExtensionLifecycleState.identified);
    });
  });

  group('failures', () {
    test('test_load_runtimeThrows_becomesLoadFailedAndLeavesOthersAlone', () async {
      harness.runtimes.register(FakeRuntime(id: 'runtime_broken', throwOnLoad: true, log: InstanceLog()));
      harness.runtimes.register(FakeRuntime(id: 'runtime_good', protocols: const <String>{'good'}, log: InstanceLog()));

      final broken = harness.descriptor(id: 'purelive.fake.broken');
      await harness.gateway.register(broken);
      await expectLater(
        harness.gateway.load(broken.id),
        throwsA(isA<ExtensionGatewayException>().having((e) => e.code, 'code', PlatformErrorCodes.extensionLoadFailed)),
      );
      expect(harness.gateway.find(broken.id)!.lifecycle, ExtensionLifecycleState.error);
      expect(harness.gateway.find(broken.id)!.error?.retryable, isTrue);

      final healthy = harness.descriptor(id: 'purelive.fake.healthy', protocol: 'good');
      await harness.gateway.register(healthy);
      await harness.gateway.load(healthy.id);
      expect(harness.gateway.find(healthy.id)!.lifecycle, ExtensionLifecycleState.ready);
    });

    test('test_load_initializeThrows_disposesTheInstanceAndRecordsTheError', () async {
      final log = InstanceLog();
      harness.runtimes.register(FakeRuntime(log: log, failOn: 'initialize'));

      await harness.gateway.register(harness.descriptor());
      await expectLater(harness.gateway.load('purelive.fake.one'), throwsA(isA<ExtensionGatewayException>()));

      expect(log.calls, <String>['initialize', 'dispose']);
      expect(harness.gateway.find('purelive.fake.one')!.lifecycle, ExtensionLifecycleState.error);
      expect(harness.gateway.find('purelive.fake.one')!.sources, isEmpty);
    });

    test('test_load_afterAnError_canBeRetried', () async {
      // The failure branch is LOAD -> ERROR -> DIAGNOSTICS -> RETRY, so an error must not be a dead end.
      final log = InstanceLog();
      final runtime = FakeRuntime(log: log, failOn: 'initialize');
      harness.runtimes.register(runtime);
      final descriptor = harness.descriptor();
      await harness.gateway.register(descriptor);
      await expectLater(harness.gateway.load(descriptor.id), throwsA(anything));

      runtime.failOn = null;
      await harness.gateway.load(descriptor.id);

      expect(harness.gateway.find(descriptor.id)!.lifecycle, ExtensionLifecycleState.ready);
      expect(
        log.calls.where((call) => call == 'dispose'),
        hasLength(1),
        reason: 'the failed attempt is released first',
      );
    });

    test('test_start_beforeLoad_isRefusedAsStateInvalid', () async {
      harness.runtimes.register(FakeRuntime(log: InstanceLog()));
      await harness.gateway.register(harness.descriptor());

      await expectLater(
        harness.gateway.start('purelive.fake.one'),
        throwsA(isA<ExtensionGatewayException>().having((e) => e.code, 'code', 'extension.state_invalid')),
      );
    });

    test('test_start_instanceThrows_isRecordedAsError', () async {
      await registerAndLoad(failOn: 'start');

      await expectLater(harness.gateway.start('purelive.fake.one'), throwsA(isA<ExtensionGatewayException>()));

      expect(harness.gateway.find('purelive.fake.one')!.lifecycle, ExtensionLifecycleState.error);
      expect(harness.gateway.find('purelive.fake.one')!.health, RuntimeHealth.unavailable);
    });
  });

  group('disable', () {
    test('test_disable_stopsDisposesAndRefusesReloadUntilReregistered', () async {
      final log = InstanceLog();
      await registerAndLoad(log: log);
      await harness.gateway.start('purelive.fake.one');

      await harness.gateway.disable('purelive.fake.one');

      expect(harness.gateway.find('purelive.fake.one')!.lifecycle, ExtensionLifecycleState.disabled);
      expect(log.calls.contains('dispose'), isTrue);
      await expectLater(
        harness.gateway.load('purelive.fake.one'),
        throwsA(isA<ExtensionGatewayException>().having((e) => e.code, 'code', 'extension.disabled')),
      );

      // Disabled keeps the record, unlike unload, so a management screen can still name it.
      expect(harness.gateway.getAll(), hasLength(1));
    });

    test('test_disable_withoutAnInstance_doesNotThrow', () async {
      harness.runtimes.register(FakeRuntime(log: InstanceLog()));
      await harness.gateway.register(harness.descriptor());

      await harness.gateway.disable('purelive.fake.one');

      expect(harness.gateway.find('purelive.fake.one')!.lifecycle, ExtensionLifecycleState.disabled);
    });
  });

  group('diagnostics', () {
    test('test_transitions_emitEventsNamedAfterTheState', () async {
      harness.runtimes.register(FakeRuntime(log: InstanceLog()));
      await registerAndLoad();

      final tracer = harness.gateway.diagnostics as InMemoryDiagnosticTracer;
      final names = tracer.events.map((event) => event.name).toList(growable: false);

      expect(
        names,
        containsAll(<String>[
          'extension.registered',
          'extension.identified',
          'extension.loading',
          'extension.validating',
          'extension.ready',
        ]),
      );
      expect(tracer.events.every((event) => event.extensionId == 'purelive.fake.one'), isTrue);
    });

    test('test_incompatibleTransition_isRecordedAtErrorLevel', () async {
      await expectLater(
        harness.gateway.register(harness.descriptor(protocol: 'no_such_protocol')),
        throwsA(isA<ExtensionGatewayException>()),
      );

      final tracer = harness.gateway.diagnostics as InMemoryDiagnosticTracer;
      final event = tracer.events.where((event) => event.name == 'extension.incompatible').single;

      expect(event.level, DiagnosticLevel.error);
      expect(event.error?.code, PlatformErrorCodes.extensionIncompatible);
    });
  });
}
