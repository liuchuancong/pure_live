// Module: test/permission_manager_test.dart
// Purpose: Verify the minimum-privilege rules of PolicyPermissionManager: ceiling, prompts, scopes, expiry.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_permission/pure_live_permission.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:test/test.dart';

const String _id = 'purelive.external.tvbox';

ExtensionDescriptor _descriptor({
  String id = _id,
  Set<Permission> declared = const <Permission>{Permission.network, Permission.cookie},
}) {
  return ExtensionDescriptor(
    id: id,
    name: 'TVBox',
    version: '1.0.0',
    protocol: 'tvbox',
    type: ExtensionType.external,
    permissions: declared,
  );
}

/// Counts consultations so a test can assert the manager did not ask when it had no standing to.
class _RecordingPrompt implements PermissionPrompt {
  _RecordingPrompt(this.answer);

  PermissionState answer;
  final List<Permission> asked = <Permission>[];

  @override
  Future<PermissionState> decide(
    ExtensionDescriptor descriptor,
    Permission permission,
    PermissionScope requestedScope,
  ) async {
    asked.add(permission);
    return answer;
  }
}

void main() {
  final fixedNow = DateTime.utc(2026, 10, 8, 12);
  DateTime clock() => fixedNow;

  late InMemoryPermissionStore store;
  late _RecordingPrompt prompt;
  late PolicyPermissionManager manager;

  Future<PolicyPermissionManager> buildManager({
    PermissionPrompt? withPrompt,
    Set<Permission> declared = const <Permission>{Permission.network, Permission.cookie},
  }) async {
    final built = PolicyPermissionManager(store: store, prompt: withPrompt ?? prompt, clock: clock);
    await built.register(_descriptor(declared: declared));
    return built;
  }

  setUp(() {
    store = InMemoryPermissionStore();
    prompt = _RecordingPrompt(PermissionState.granted);
    manager = PolicyPermissionManager(store: store, prompt: prompt, clock: clock);
  });

  group('check', () {
    test('test_check_neverRequested_reportsUnknown', () async {
      final decision = await manager.check(_id, Permission.network);

      expect(decision.allowed, isFalse);
      expect(decision.state, PermissionState.unknown);
      expect(decision.code, PlatformErrorCodes.permissionDenied);
      expect(decision.reason, contains('never been requested'));
    });

    test('test_check_recordedDenial_reportsDeniedNotUnknown', () async {
      await store.save(
        PermissionGrant(
          extensionId: _id,
          permission: Permission.cookie,
          state: PermissionState.denied,
          grantedAt: fixedNow,
        ),
      );

      final decision = await manager.check(_id, Permission.cookie);

      expect(decision.state, PermissionState.denied);
      expect(decision.reason, contains('denied'));
    });

    test('test_check_targetOutsideHostScope_reportsRestricted', () async {
      await store.save(
        PermissionGrant(
          extensionId: _id,
          permission: Permission.network,
          state: PermissionState.granted,
          grantedAt: fixedNow,
          scope: const PermissionScope(hosts: <String>{'api.example.com'}),
        ),
      );

      final inside = await manager.check(_id, Permission.network, target: Uri.parse('https://api.example.com/v1'));
      final outside = await manager.check(_id, Permission.network, target: Uri.parse('https://other.com/v1'));

      expect(inside.allowed, isTrue);
      expect(outside.allowed, isFalse);
      expect(outside.state, PermissionState.restricted);
      expect(outside.code, PlatformErrorCodes.permissionRestricted);
      expect(outside.toErrorInfo().recoverable, isFalse);
    });

    test('test_check_expiredGrant_reportsUnknownSoItCanBeAskedAgain', () async {
      await store.save(
        PermissionGrant(
          extensionId: _id,
          permission: Permission.network,
          state: PermissionState.granted,
          grantedAt: fixedNow.subtract(const Duration(days: 1)),
          expiresAt: fixedNow.subtract(const Duration(hours: 1)),
        ),
      );

      final decision = await manager.check(_id, Permission.network);

      expect(decision.allowed, isFalse);
      expect(decision.state, PermissionState.unknown);
      expect(decision.toErrorInfo().recoverable, isTrue);
      expect(decision.reason, contains('expired'));
    });
  });

  group('request', () {
    setUp(() async {
      manager = await buildManager();
    });

    test('test_request_unregisteredExtension_isRefusedWithoutPrompting', () async {
      final decision = await manager.request('purelive.external.unknown', Permission.network);

      expect(decision.allowed, isFalse);
      expect(decision.state, PermissionState.restricted);
      expect(prompt.asked, isEmpty);
    });

    test('test_request_permissionOutsideTheDescriptor_isRefusedWithoutPrompting', () async {
      // The descriptor is the ceiling: talking to a prompt must not widen it.
      final decision = await manager.request(_id, Permission.device);

      expect(decision.allowed, isFalse);
      expect(decision.state, PermissionState.restricted);
      expect(prompt.asked, isEmpty);
      expect(store.length, 0);
    });

    test('test_request_declaredPermission_recordsTheGrantAndCheckAgrees', () async {
      final requested = await manager.request(_id, Permission.network);
      final checked = await manager.check(_id, Permission.network);

      expect(requested.allowed, isTrue);
      expect(checked.allowed, isTrue);
      expect(prompt.asked, const <Permission>[Permission.network]);
      expect(await manager.held(_id), <Permission>{Permission.network});
    });

    test('test_request_promptRefuses_recordsTheRefusalAndDoesNotRePrompt', () async {
      prompt.answer = PermissionState.denied;

      final first = await manager.request(_id, Permission.network);
      final second = await manager.request(_id, Permission.network);

      expect(first.allowed, isFalse);
      expect(second.state, PermissionState.denied);
      expect(prompt.asked, hasLength(1));
      expect(await manager.held(_id), isEmpty);
    });

    test('test_request_existingGrantCoveringTheScope_isReusedWithoutPrompting', () async {
      await manager.request(_id, Permission.network);
      prompt.asked.clear();

      final again = await manager.request(
        _id,
        Permission.network,
        scope: const PermissionScope(hosts: <String>{'api.example.com'}),
      );

      expect(again.allowed, isTrue);
      expect(prompt.asked, isEmpty);
    });

    test('test_request_wideningHostList_repromptsAndKeepsTheOriginalHost', () async {
      await manager.request(_id, Permission.network, scope: const PermissionScope(hosts: <String>{'a.com'}));
      prompt.asked.clear();

      final widened = await manager.request(
        _id,
        Permission.network,
        scope: const PermissionScope(hosts: <String>{'b.com'}),
      );

      expect(prompt.asked, const <Permission>[Permission.network]);
      expect(widened.scope.hosts, <String>{'a.com', 'b.com'});
      // Merging rather than replacing is what keeps a source working on the host it already used.
      expect(
        await manager.check(_id, Permission.network, target: Uri.parse('https://a.com/x')),
        isA<PermissionDecision>().having((d) => d.allowed, 'allowed', isTrue),
      );
      expect(
        await manager.check(_id, Permission.network, target: Uri.parse('https://b.com/x')),
        isA<PermissionDecision>().having((d) => d.allowed, 'allowed', isTrue),
      );
    });

    test('test_request_pathScopedGrant_coversOnlyThatPathPrefix', () async {
      await manager.request(
        _id,
        Permission.network,
        scope: const PermissionScope(hosts: <String>{'example.com'}, paths: <String>{'/api/'}),
      );

      expect(
        await manager.check(_id, Permission.network, target: Uri.parse('https://example.com/api/v1')),
        isA<PermissionDecision>().having((d) => d.allowed, 'allowed', isTrue),
      );
      expect(
        await manager.check(_id, Permission.network, target: Uri.parse('https://example.com/admin')),
        isA<PermissionDecision>().having((d) => d.allowed, 'allowed', isFalse),
      );
    });
  });

  group('revoke and refuse', () {
    setUp(() async {
      manager = await buildManager();
      await manager.request(_id, Permission.network);
    });

    test('test_revoke_removesTheRecordSoTheNextRequestPromptsAgain', () async {
      await manager.revoke(_id, Permission.network);
      prompt.asked.clear();

      expect((await manager.check(_id, Permission.network)).allowed, isFalse);
      expect(
        await manager.request(_id, Permission.network),
        isA<PermissionDecision>().having((d) => d.allowed, 'allowed', isTrue),
      );
      expect(prompt.asked, const <Permission>[Permission.network]);
    });

    test('test_refuse_blocksFurtherRequestsUntilRevoked', () async {
      await manager.refuse(_id, Permission.network);

      final refused = await manager.request(_id, Permission.network);
      expect(refused.allowed, isFalse);
      expect(refused.state, PermissionState.denied);
      expect(await manager.held(_id), isEmpty);

      await manager.revoke(_id, Permission.network);
      expect(
        await manager.request(_id, Permission.network),
        isA<PermissionDecision>().having((d) => d.allowed, 'allowed', isTrue),
      );
    });
  });

  group('defaults', () {
    test('test_manager_withoutAPrompt_failsClosed', () async {
      final closed = PolicyPermissionManager(store: store, clock: clock);
      await closed.register(_descriptor());

      final decision = await closed.request(_id, Permission.network);

      expect(decision.allowed, isFalse);
      expect(decision.state, PermissionState.denied);
    });

    test('test_grantDeclaredPrompt_approvesOnlyWhatTheDescriptorDeclared', () async {
      final builtin = PolicyPermissionManager(store: store, prompt: const GrantDeclaredPrompts(), clock: clock);
      await builtin.register(_descriptor(declared: const <Permission>{Permission.network}));

      expect(
        await builtin.request(_id, Permission.network),
        isA<PermissionDecision>().having((d) => d.allowed, 'allowed', isTrue),
      );
      expect(
        // cookie was never declared, so it is refused before any prompt is involved.
        await builtin.request(_id, Permission.cookie),
        isA<PermissionDecision>().having((d) => d.state, 'state', PermissionState.restricted),
      );
    });

    test('test_held_ignoresGrantsOfOtherExtensions', () async {
      final other = PolicyPermissionManager(store: store, prompt: prompt, clock: clock);
      await other.register(_descriptor(id: 'purelive.external.lxmusic'));
      await other.request('purelive.external.lxmusic', Permission.cookie);

      expect(await manager.held('purelive.external.lxmusic'), <Permission>{Permission.cookie});
      expect(await manager.held(_id), isEmpty);
    });
  });
}
