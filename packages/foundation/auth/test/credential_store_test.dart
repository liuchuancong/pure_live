// Module: test/credential_store_test.dart
// Purpose: Verify the credential lifecycle: storage isolation, expiry reporting and complete logout.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_auth/pure_live_auth.dart';

import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

void main() {
  late MemorySecretVault secrets;
  late MemorySessionBox settings;
  late FixedClock clock;
  late CredentialStore store;

  setUp(() {
    secrets = MemorySecretVault();
    settings = MemorySessionBox();
    clock = FixedClock(DateTime.utc(2026, 10, 8, 12));
    store = CredentialStore(secrets: secrets, settings: settings, clock: clock);
  });

  tearDown(() async => store.dispose());

  Future<CredentialHandle> login({
    String provider = 'bilibili',
    String account = 'uid-1',
    DateTime? expiresAt,
    String secret = 'mid-secret',
  }) {
    return store.storeCredential(
      providerId: provider,
      accountId: account,
      method: AuthMethod.cookie,
      secret: secret,
      expiresAt: expiresAt,
      profile: AccountProfile(providerId: provider, accountId: account, displayName: 'me'),
    );
  }

  test('test_storeCredential_secretLandsInSecureStoreOnly', () async {
    final handle = await login();

    expect(await store.readSecret(handle), 'mid-secret');
    // The settings store keeps state, never the credential.
    expect(await settings.read(handle.key), isNull);
    final sessionText = (await settings.read('auth.session.bilibili.uid-1'))! as Map<Object?, Object?>;
    expect(sessionText.values.join(' '), isNot(contains('mid-secret')));
  });

  test('test_storeCredential_localExpiry_isPersistedAsUtc', () async {
    final local = DateTime(2026, 10, 8, 18);
    final handle = await login(expiresAt: local);

    final session = await store.sessionOf(handle.providerId, handle.accountId);
    expect(session!.expiresAt, local.toUtc());
    expect(session.expiresAt!.isUtc, isTrue);
  });

  test('test_sessionOf_beforeExpiry_isLoggedIn', () async {
    await login(expiresAt: DateTime.utc(2026, 10, 8, 13));

    final session = await store.sessionOf('bilibili', 'uid-1');
    expect(session!.status, AccountStatus.loggedIn);
    expect(session.isLoggedIn, isTrue);
  });

  test('test_sessionOf_afterExpiry_reportsExpiredAndEmitsOnce', () async {
    await login(expiresAt: DateTime.utc(2026, 10, 8, 13));
    final events = <AuthExpiry>[];
    final sub = store.expiryEvents.listen(events.add);

    clock.advance(const Duration(hours: 2));
    final session = await store.sessionOf('bilibili', 'uid-1');
    await Future<void>.delayed(Duration.zero);

    expect(session!.status, AccountStatus.expired);
    expect(events, hasLength(1));
    expect(events.single.reason, 'expired');
    await sub.cancel();
  });

  test('test_sessionOf_withoutExpiry_staysValid', () async {
    // Several providers never report an expiry; treating unknown as expired would log everyone out.
    await login();

    clock.advance(const Duration(days: 400));
    final session = await store.sessionOf('bilibili', 'uid-1');

    expect(session!.status, AccountStatus.loggedIn);
  });

  test('test_setStatus_loggedOut_emitsAnExpiryWithTheReason', () async {
    final handle = await login();
    final events = <AuthExpiry>[];
    final sub = store.expiryEvents.listen(events.add);

    await store.setStatus(handle, AccountStatus.loggedOut);
    await Future<void>.delayed(Duration.zero);

    expect(events.single.reason, 'status:loggedOut');
    await sub.cancel();
  });

  test('test_clearAccount_removesSecretSessionAndProfile', () async {
    final handle = await login();
    await store.clearAccount(providerId: 'bilibili', accountId: 'uid-1');

    expect(await store.readSecret(handle), isNull);
    expect(await store.sessionOf('bilibili', 'uid-1'), isNull);
    expect(await secrets.keys(), isEmpty);
    expect(await settings.keys(), isEmpty);
  });

  test('test_clearAccount_leavesOtherProvidersAlone', () async {
    await login(provider: 'bilibili', account: 'uid-1');
    await login(provider: 'douyu', account: 'dn-2');

    await store.clearAccount(providerId: 'bilibili', accountId: 'uid-1');

    expect(await store.sessionOf('douyu', 'dn-2'), isNotNull);
    expect(await store.sessionOf('bilibili', 'uid-1'), isNull);
  });

  test('test_sessions_listsEveryProviderAccount', () async {
    await login(provider: 'bilibili', account: 'uid-1');
    await login(provider: 'huya', account: 'hy-9');

    final sessions = await store.sessions();

    expect(sessions.map((session) => session.handle.providerId), <String>['bilibili', 'huya']);
  });

  test('test_clearAll_emptiesEverything', () async {
    await login(provider: 'bilibili', account: 'uid-1');
    await login(provider: 'huya', account: 'hy-9');

    await store.clearAll();

    expect(await store.sessions(), isEmpty);
    expect(await secrets.keys(), isEmpty);
  });

  test('test_describeForDiagnostics_containsNoCredential', () async {
    await login(secret: 'super-private-value');

    final described = await store.describeForDiagnostics();

    expect(described.single['providerId'], 'bilibili');
    expect(described.single['status'], 'loggedIn');
    expect(described.map((row) => row.values.join(' ')).join(' '), isNot(contains('super-private')));
  });

  test('test_isAuthOwnedKey_matchesOnlyAuthPrefixes', () {
    expect(isAuthOwnedKey('auth.secret.bilibili.uid-1'), isTrue);
    expect(isAuthOwnedKey('auth.session.bilibili.uid-1'), isTrue);
    expect(isAuthOwnedKey('player.engine'), isFalse);
    expect(isAuthOwnedKey('cache.auth.token'), isFalse);
  });

  test('test_sessionOf_unknownAccount_returnsNull', () async {
    expect(await store.sessionOf('nope', 'nada'), isNull);
  });

  test('test_setStatus_forUnknownAccount_isANoOp', () async {
    const handle = CredentialHandle(providerId: 'x', accountId: 'y', key: 'auth.secret.x.y');

    await store.setStatus(handle, AccountStatus.disabled);

    expect(await store.sessions(), isEmpty);
  });
}
