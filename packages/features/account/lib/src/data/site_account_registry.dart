// Module: lib/src/data/site_account_registry.dart
// Purpose: Per-site account management over the auth package's credential
// store: which sites have signed-in accounts, and the login/logout/refresh
// operations the account surface calls.
// Author: liuchuancong
// Created: 2026-10-10
//
// The shell knows site ids only as strings - the same ids the plugin system
// uses. Secrets live in the SecretVault the host injected (flutter_secure_
// storage in the app), never in this package.

import 'package:pure_live_auth/pure_live_auth.dart';

/// One site's signed-in state as the account surface renders it.
final class SiteAccountStatus {
  const SiteAccountStatus({required this.siteId, required this.accounts, this.expiresAt});

  final String siteId;

  /// Account ids with stored credentials for this site, oldest first.
  final List<String> accounts;

  /// When the newest session expires, when the site reported one.
  final DateTime? expiresAt;

  bool get isSignedIn => accounts.isNotEmpty;
}

/// The per-site account registry.
final class SiteAccountRegistry {
  SiteAccountRegistry({required CredentialStore credentialStore}) : _credentials = credentialStore;

  final CredentialStore _credentials;

  /// The account ids stored for [siteId], from the session list.
  Future<List<String>> accountsFor(String siteId) async {
    final sessions = await _credentials.sessions();
    return <String>[
      for (final session in sessions)
        if (session.handle.providerId == siteId) session.handle.accountId,
    ];
  }

  /// The aggregated status of every site in [siteIds].
  Future<List<SiteAccountStatus>> statuses(Iterable<String> siteIds) async {
    final out = <SiteAccountStatus>[];
    for (final siteId in siteIds) {
      out.add(SiteAccountStatus(siteId: siteId, accounts: await accountsFor(siteId)));
    }
    return out;
  }

  /// Stores a site credential (cookie text, token or secret the site's login
  /// flow produced). Returns the handle.
  Future<CredentialHandle> saveCredential({
    required String siteId,
    required String accountId,
    required AuthMethod method,
    required String secret,
    DateTime? expiresAt,
    AccountProfile? profile,
  }) {
    return _credentials.storeCredential(
      providerId: siteId,
      accountId: accountId,
      method: method,
      secret: secret,
      expiresAt: expiresAt,
      profile: profile,
    );
  }

  /// The newest credential handle for a site, or null when signed out.
  Future<CredentialHandle?> load(String siteId) async {
    final accounts = await accountsFor(siteId);
    if (accounts.isEmpty) {
      return null;
    }
    final session = await _credentials.sessionOf(siteId, accounts.last);
    return session == null
        ? null
        : CredentialHandle(providerId: siteId, accountId: accounts.last, key: '${siteId}:${accounts.last}');
  }

  /// Removes one site's newest credential: logout.
  Future<void> logout(String siteId) async {
    final accounts = await accountsFor(siteId);
    if (accounts.isEmpty) {
      return;
    }
    await _credentials.clearAccount(providerId: siteId, accountId: accounts.last);
  }
}
