// Module: test/data/credential_site_accounts_test.dart
// Purpose: Pins the account view: status truth, primary-account choice, capacity limits and complete
// sign-out.
// Author: liuchuancong
// Created: 2026-10-10

import 'package:pure_live_account/pure_live_account.dart';
import 'package:pure_live_auth/pure_live_auth.dart';
import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

void main() {
  late MemorySecretVault vault;
  late FixedClock clock;
  late CredentialStore store;
  late CredentialSiteAccounts accounts;

  setUp(() {
    vault = MemorySecretVault();
    clock = FixedClock(DateTime.utc(2026, 10, 10));
    store = CredentialStore(secrets: vault, settings: MemorySessionBox(), clock: clock);
    accounts = CredentialSiteAccounts(credentials: store);
  });

  Future<SiteAccount> _signIn(String accountId, {Duration? livesFor, String secret = 'cookie=value'}) =>
      accounts.signIn(
        siteId: 'huya',
        accountId: accountId,
        method: AuthMethod.cookie,
        secret: secret,
        expiresAt: livesFor == null ? null : clock().add(livesFor),
      );

  test('test_credentialSiteAccounts_signIn_listsAUsableAccount', () async {
    await _signIn('me', livesFor: const Duration(hours: 1));

    final listed = await accounts.accountsOf('huya');
    expect(listed.single.displayName, 'me');
    expect(listed.single.isUsable, isTrue);
    expect(listed.single.expiresAt, DateTime.utc(2026, 10, 10, 1));
    expect(listed.single.secretPresent, isTrue);
  });

  test('test_credentialSiteAccounts_expiredSession_isNeitherSignedInNorGone', () async {
    await _signIn('me', livesFor: const Duration(minutes: 5));
    clock.advance(const Duration(minutes: 10));

    final listed = await accounts.accountsOf('huya');
    expect(listed.single.status, AccountStatus.expired);
    expect(listed.single.isUsable, isFalse);
    expect(listed.single.canRefresh, isTrue);
    expect((await accounts.primaryAccount('huya'))!.accountId, 'me');
  });

  test('test_credentialSiteAccounts_accountsAreListedByIdNotByKeyOrder', () async {
    await _signIn('zebra');
    await _signIn('alpha');
    await _signIn('middle');

    expect((await accounts.accountsOf('huya')).map((account) => account.accountId), <String>[
      'alpha',
      'middle',
      'zebra',
    ]);
  });

  test('test_credentialSiteAccounts_primaryAccount_picksTheUsableOneLivingLongest', () async {
    final soon = await _signIn('soon', livesFor: const Duration(hours: 1));
    await _signIn('later', livesFor: const Duration(hours: 8));

    final primary = await accounts.primaryAccount('huya');
    expect(primary?.accountId, 'later');
    expect(primary?.isUsable, isTrue);
    expect(soon.status, AccountStatus.loggedIn);
  });

  test('test_credentialSiteAccounts_missingSecretIsReportedNotInvented', () async {
    final account = await _signIn('me');
    // The session record survived; the credential did not - a partial wipe, not a logout.
    await vault.remove(account.handle.key);

    final listed = await accounts.accountsOf('huya');
    expect(listed.single.secretPresent, isFalse);
    expect(listed.single.isUsable, isFalse);
    expect(listed.single.canRefresh, isFalse, reason: 'there is nothing left to refresh');
  });

  test('test_credentialSiteAccounts_signOutSite_removesEveryAccountOfThatSiteOnly', () async {
    await _signIn('one');
    await _signIn('two');
    await accounts.signIn(siteId: 'douyu', accountId: 'other', method: AuthMethod.token, secret: 'x');

    await accounts.signOutSite('huya');
    expect(await accounts.accountsOf('huya'), isEmpty);
    expect(await accounts.accountsOf('douyu'), hasLength(1));
    // The secret goes with the record: a leftover key is how a v1 session outlived its own logout.
    expect(await vault.keys(), isNot(contains('auth.secret.huya.one')));
  });

  test('test_credentialSiteAccounts_rejectsAnEmptyOrOversizedCredential', () async {
    expect(
      () => accounts.signIn(siteId: 'huya', accountId: 'me', method: AuthMethod.cookie, secret: ''),
      throwsA(isA<AccountInputFailure>()),
    );
    final small = CredentialSiteAccounts(credentials: store, maxSecretSize: ByteSize.kib(1));
    expect(
      small.signIn(siteId: 'huya', accountId: 'me', method: AuthMethod.cookie, secret: 'y' * 2000),
      throwsA(
        isA<AccountInputFailure>().having(
          (error) => error.reason,
          'reason',
          allOf(contains('2.0 KiB'), contains('1.0 KiB')),
        ),
      ),
      reason: 'the size and the ceiling both belong in the message, or the report is a guess',
    );
  });

  test('test_credentialSiteAccounts_rejectsNamelessIdentifiers', () {
    expect(
      () => accounts.signIn(siteId: '  ', accountId: 'me', method: AuthMethod.cookie, secret: 'x'),
      throwsArgumentError,
    );
    expect(() => accounts.accountsOf(' '), throwsArgumentError);
  });

  test('test_credentialSiteAccounts_markStatusOnAGoneAccount_isNamed', () async {
    final account = await _signIn('me');
    await accounts.signOut(account);

    expect(() => accounts.markStatus(account, AccountStatus.disabled), throwsA(isA<AccountNotFoundFailure>()));
  });

  test('test_credentialSiteAccounts_expiriesStreamNamesTheAccount', () async {
    await _signIn('me', livesFor: const Duration(minutes: 1));
    final seen = <SiteAccountExpiry>[];
    final subscription = accounts.expiries.listen(seen.add);

    clock.advance(const Duration(minutes: 2));
    await accounts.accountsOf('huya');
    await Future<void>.delayed(Duration.zero);

    expect(seen.single.accountId, 'me');
    expect(seen.single.siteId, 'huya');
    await subscription.cancel();
  });
}
