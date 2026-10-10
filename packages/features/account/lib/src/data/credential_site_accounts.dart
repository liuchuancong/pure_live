// Module: lib/src/data/credential_site_accounts.dart
// Purpose: The account surface's view, implemented over the auth package's credential store.
// Author: liuchuancong
// Created: 2026-10-10
//
// Everything the surface needs is already in `CredentialStore`; what this file adds is the shape it is read
// in and the checks the store cannot make. Two rules are enforced here because the store would otherwise
// accept the mistake silently: a credential larger than the vault can hold, and an id that is blank, which
// produces a session key that nothing can name.
//
// This package never sees plaintext beyond the one argument it forwards, and never deletes half an account:
// sign-out goes through `clearAccount`, which removes the secret and the session record together, because a
// v1 douyu session survived logout exactly by leaving the second key behind.

import 'dart:async';
import 'dart:convert';

import 'package:pure_live_auth/pure_live_auth.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

import '../domain/site_account.dart';

/// A [SiteAccountRepository] over [CredentialStore].
final class CredentialSiteAccounts implements SiteAccountRepository {
  CredentialSiteAccounts({required CredentialStore credentials, this.maxSecretSize = const ByteSize(65536)})
    : _credentials = credentials {
    if (maxSecretSize.bytes < 1) {
      throw AccountInputFailure('maxSecretSize must be at least one byte');
    }
  }

  final CredentialStore _credentials;

  /// The largest secret accepted into the vault, in bytes of utf-8.
  ///
  /// A site's cookie blob is normally a few kilobytes; an unbounded write is how one broken login flow
  /// fills secure storage and then fails every *other* site's login with a write error nobody connects back
  /// to the first one.
  final ByteSize maxSecretSize;

  @override
  Future<List<SiteAccount>> accountsOf(String siteId) async {
    final wanted = requireNonBlank(siteId, name: 'siteId');
    final sessions = await _credentials.sessions();
    final accounts = <SiteAccount>[];
    for (final session in sessions) {
      if (session.handle.providerId != wanted) {
        continue;
      }
      accounts.add(await _describe(session));
    }
    // Sorted by id, not by the store's key listing order, so a restart cannot shuffle the rows a user
    // learned to aim at with a d-pad.
    accounts.sort((left, right) => left.accountId.compareTo(right.accountId));
    return List<SiteAccount>.unmodifiable(accounts);
  }

  @override
  Future<SiteAccount?> primaryAccount(String siteId) async {
    final accounts = await accountsOf(siteId);
    if (accounts.isEmpty) {
      return null;
    }
    // A usable session wins; among those, the one that lives longest is the one the user last renewed. The
    // store keeps no "written at" field, so expiry is the only ordering fact available, and inventing a
    // recency proxy out of key order would be a rule that changes with the storage backend.
    final usable = accounts.where((account) => account.isUsable).toList(growable: false);
    if (usable.isEmpty) {
      // Fall back to the account most worth refreshing, so a screen can offer "renew" instead of only
      // "log in again" when the session merely aged out.
      return accounts.where((account) => account.canRefresh).head ?? accounts.first;
    }
    return usable.reduce((left, right) => _livesLonger(right, left) ? right : left);
  }

  @override
  Future<SiteAccount> signIn({
    required String siteId,
    required String accountId,
    required AuthMethod method,
    required String secret,
    DateTime? expiresAt,
    AccountProfile? profile,
  }) async {
    final namedSite = requireNonBlank(siteId, name: 'siteId');
    final namedAccount = requireNonBlank(accountId, name: 'accountId');
    if (secret.isEmpty) {
      throw AccountInputFailure('a credential for $namedSite/$namedAccount came back empty');
    }
    final size = utf8.encode(secret).length;
    if (size > maxSecretSize.bytes) {
      throw AccountInputFailure(
        'credential for $namedSite/$namedAccount is ${ByteSize(size).humanReadable}, '
        'over the ${maxSecretSize.humanReadable} this device allows',
      );
    }
    final handle = await _credentials.storeCredential(
      providerId: namedSite,
      accountId: namedAccount,
      method: method,
      secret: secret,
      expiresAt: expiresAt,
      profile: profile,
    );
    return SiteAccount(
      handle: handle,
      method: method,
      status: AccountStatus.loggedIn,
      secretPresent: true,
      expiresAt: expiresAt?.toUtc(),
      profile: profile,
    );
  }

  @override
  Future<void> markStatus(SiteAccount account, AccountStatus status) async {
    // The store's own status write ignores a missing record, so a row the user had already signed out of
    // would look like it worked. Named failure instead, because the surface reacts differently.
    final stillThere = (await accountsOf(account.siteId)).any((found) => found.accountId == account.accountId);
    if (!stillThere) {
      throw AccountNotFoundFailure(account.siteId, account.accountId);
    }
    await _credentials.setStatus(account.handle, status);
  }

  @override
  Future<void> signOut(SiteAccount account) =>
      _credentials.clearAccount(providerId: account.siteId, accountId: account.accountId);

  @override
  Future<void> signOutSite(String siteId) async {
    final accounts = await accountsOf(siteId);
    final failures = <Object>[];
    for (final account in accounts) {
      try {
        await signOut(account);
      } catch (error) {
        // A half-signed-out site is the state the user will blame us for: keep going, then report what was
        // left behind instead of stopping at the first key that refused to die.
        failures.add(error);
      }
    }
    if (failures.isNotEmpty) {
      throw AccountOperationFailure(
        'signing out $siteId left ${failures.length} of ${accounts.length} accounts behind',
      );
    }
  }

  @override
  Stream<SiteAccountExpiry> get expiries {
    // A mapped view of the store's broadcast stream: this repository owns no controller, so it can be
    // discarded without leaving a sink that never closes.
    return _credentials.expiryEvents.map(
      (event) => SiteAccountExpiry(
        siteId: event.session.handle.providerId,
        accountId: event.session.handle.accountId,
        reason: event.reason,
      ),
    );
  }

  Future<SiteAccount> _describe(AuthSession session) async {
    final secret = await _credentials.readSecret(session.handle);
    return SiteAccount(
      handle: session.handle,
      method: session.method,
      status: session.status,
      secretPresent: secret != null && secret.isNotEmpty,
      expiresAt: session.expiresAt,
      profile: session.profile,
    );
  }

  bool _livesLonger(SiteAccount left, SiteAccount right) {
    final a = left.expiresAt;
    final b = right.expiresAt;
    if (a == null) {
      return false;
    }
    if (b == null) {
      return true;
    }
    return a.isAfter(b);
  }
}
