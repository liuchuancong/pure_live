// Module: test/key_value_permission_store_test.dart
// Purpose: Verify grants persist, stay scoped to their own extension, and remain re-askable when unanswered.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/contracts/platform-contracts.md section 15. The port's rule that a denial is a record rather than
// an absence is what makes the prefix shape load-bearing, so both are asserted here.
import 'dart:io';

import 'package:pure_live_permission/pure_live_permission.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:test/test.dart';

PermissionGrant _grant({
  String id = 'purelive.a',
  Permission permission = Permission.network,
  PermissionState state = PermissionState.granted,
  DateTime? grantedAt,
  DateTime? expiresAt,
  PermissionScope scope = PermissionScope.unrestricted,
}) {
  return PermissionGrant(
    extensionId: id,
    permission: permission,
    state: state,
    grantedAt: grantedAt ?? DateTime.utc(2026, 10, 9, 12),
    expiresAt: expiresAt,
    scope: scope,
  );
}

void main() {
  late MemoryKeyValueStore store;
  late KeyValuePermissionStore permissions;

  setUp(() {
    store = MemoryKeyValueStore();
    permissions = KeyValuePermissionStore(store);
  });

  group('test_keyValueStore_roundTrip', () {
    test('test_load_absent_returnsNull', () async {
      expect(await permissions.load('purelive.a', Permission.network), isNull);
    });

    test('test_load_afterSave_returnsTheWholeGrant', () async {
      final grant = _grant(
        expiresAt: DateTime.utc(2026, 10, 10),
        scope: const PermissionScope(hosts: <String>{'api.example.com', '*.cdn.example.com'}, paths: <String>{'/v1/'}),
      );

      await permissions.save(grant);
      final loaded = await permissions.load('purelive.a', Permission.network);

      expect(loaded, grant);
      expect(loaded!.scope.hosts, <String>{'api.example.com', '*.cdn.example.com'});
      expect(loaded.scope.paths, <String>{'/v1/'});
      expect(loaded.grantedAt, DateTime.utc(2026, 10, 9, 12));
      expect(loaded.expiresAt, DateTime.utc(2026, 10, 10));
    });

    test('test_load_limitedScope_stillAnswersItsOwnHost', () async {
      await permissions.save(_grant(scope: const PermissionScope(hosts: <String>{'api.example.com'})));

      final loaded = await permissions.load('purelive.a', Permission.network);

      expect(
        loaded!.isEffectiveAt(DateTime.utc(2026, 10, 9, 13), target: Uri.parse('https://api.example.com/v1/x')),
        isTrue,
      );
      expect(
        loaded.isEffectiveAt(DateTime.utc(2026, 10, 9, 13), target: Uri.parse('https://evil.example/v1/x')),
        isFalse,
      );
    });

    test('test_remove_dropsOnePermissionAndKeepsTheRest', () async {
      await permissions.save(_grant(permission: Permission.network));
      await permissions.save(_grant(permission: Permission.cookie));

      await permissions.remove('purelive.a', Permission.network);

      expect(await permissions.load('purelive.a', Permission.network), isNull);
      expect(await permissions.load('purelive.a', Permission.cookie), isNotNull);
    });

    test('test_grantsFor_listsOnlyThatExtensionsRecords', () async {
      await permissions.save(_grant(id: 'purelive.a', permission: Permission.network));
      await permissions.save(_grant(id: 'purelive.a', permission: Permission.cookie));
      await permissions.save(_grant(id: 'purelive.b', permission: Permission.network));

      final grants = await permissions.grantsFor('purelive.a');

      expect(grants, hasLength(2));
      expect(grants.every((grant) => grant.extensionId == 'purelive.a'), isTrue);
    });

    test('test_removeAll_clearsOneExtensionNotTheLookalikePrefix', () async {
      // The key separator is what makes this safe: `permission.purelive.a.` would also match purelive.ab,
      // so removing an extension would silently revoke a different one's grants.
      await permissions.save(_grant(id: 'purelive.a'));
      await permissions.save(_grant(id: 'purelive.ab'));

      await permissions.removeAll('purelive.a');

      expect(await permissions.load('purelive.a', Permission.network), isNull);
      expect(await permissions.load('purelive.ab', Permission.network), isNotNull);
      expect(await store.keys(), <String>['permission.purelive.ab/network']);
    });

    test('test_load_unreadableRecord_isDroppedRatherThanKept', () async {
      await store.write('permission.purelive.a/network', 'not a grant');

      expect(await permissions.load('purelive.a', Permission.network), isNull);
      expect(await store.keys(), isEmpty);
    });

    test('test_denied_staysDeniedAcrossStoreInstances', () async {
      await permissions.save(_grant(state: PermissionState.denied));

      final reopened = KeyValuePermissionStore(store);

      // A refusal is a record, not an absence: `unknown` may be asked again, `denied` means somebody already
      // said no, and losing that distinction would re-open a decision the user already made.
      expect((await reopened.load('purelive.a', Permission.network))!.state, PermissionState.denied);
    });
  });

  group('test_keyValueStore_onDisk', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('key_value_permission_store');
    });
    tearDown(() {
      dir.deleteSync(recursive: true);
    });

    test('test_grant_survivesTheFileBeingReopened', () async {
      final path = '${dir.path}${Platform.pathSeparator}permissions.json';
      await KeyValuePermissionStore(FileKeyValueStore(filePath: path))
          .save(_grant(state: PermissionState.granted, expiresAt: DateTime.utc(2026, 11, 1)));

      final reloaded = await KeyValuePermissionStore(FileKeyValueStore(filePath: path))
          .load('purelive.a', Permission.network);

      expect(reloaded!.state, PermissionState.granted);
      expect(reloaded.expiresAt, DateTime.utc(2026, 11, 1));
    });
  });

  group('test_withTheManager', () {
    test('test_request_grantedThenRecheckedThroughASecondManager', () async {
      // The property the composition root needs: answering once is enough for the rest of the record's life,
      // including across a restart, and the second manager never has to prompt again.
      final descriptor = ExtensionDescriptor(
        id: 'purelive.a',
        name: 'A',
        version: '1.0.0',
        protocol: 'pure_live_plugin',
        type: ExtensionType.external,
        permissions: const <Permission>{Permission.network},
      );
      var promptRuns = 0;
      PermissionPrompt countingPrompt() => _CountingPrompt(() => promptRuns++);

      final first = PolicyPermissionManager(store: KeyValuePermissionStore(store), prompt: countingPrompt());
      await first.register(descriptor);
      final granted = await first.request('purelive.a', Permission.network);

      expect(granted.allowed, isTrue);
      expect(promptRuns, 1);

      final second = PolicyPermissionManager(store: KeyValuePermissionStore(store), prompt: countingPrompt());
      await second.register(descriptor);

      expect((await second.check('purelive.a', Permission.network)).allowed, isTrue);
      expect(promptRuns, 1, reason: 'a stored grant must not re-ask');

      final widened = await second.request('purelive.a', Permission.network);
      expect(widened.allowed, isTrue);
      expect(promptRuns, 1);
    });

    test('test_unaskedPrompt_refusesWithoutBrickingThePermission', () async {
      // A stored `denied` is intentionally never re-prompted, so a placeholder prompt must not answer denied:
      // that would record a refusal nobody made and keep it forever once grants become durable.
      final descriptor = ExtensionDescriptor(
        id: 'purelive.a',
        name: 'A',
        version: '1.0.0',
        protocol: 'pure_live_plugin',
        type: ExtensionType.external,
        permissions: const <Permission>{Permission.network},
      );
      final unasked = PolicyPermissionManager(store: KeyValuePermissionStore(store), prompt: const UnaskedPrompts());
      await unasked.register(descriptor);

      final refused = await unasked.request('purelive.a', Permission.network);
      expect(refused.allowed, isFalse);
      expect(refused.state, PermissionState.unknown);

      // The question is still open: a later prompt that can answer does get to answer.
      final asked = PolicyPermissionManager(
        store: KeyValuePermissionStore(store),
        prompt: const GrantDeclaredPrompts(),
      );
      await asked.register(descriptor);

      expect((await asked.request('purelive.a', Permission.network)).allowed, isTrue);
    });
  });
}

final class _CountingPrompt implements PermissionPrompt {
  _CountingPrompt(this.onDecide);

  final void Function() onDecide;

  @override
  Future<PermissionState> decide(
    ExtensionDescriptor descriptor,
    Permission permission,
    PermissionScope requestedScope,
  ) async {
    onDecide();
    return descriptor.permissions.contains(permission) ? PermissionState.granted : PermissionState.denied;
  }
}
