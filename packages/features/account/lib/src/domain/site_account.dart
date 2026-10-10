// Module: lib/src/domain/site_account.dart
// Purpose: What a signed-in site looks like to the account surface, and the operations it offers.
// Author: liuchuancong
// Created: 2026-10-10
//
// docs/security/credential-storage.md says code outside the auth package never holds a credential: it holds
// a handle and asks the store for an authenticated request. So this domain is a *view* over handles and
// profiles - every type here is safe to log, cache or put on screen - and the only place a secret appears is
// as an argument to signIn, straight into the store.
//
// The status lives here rather than being recomputed by each screen because "signed in" has three meanings
// a UI must not confuse: no account at all, an account whose session expired (often refreshable), and an
// account the site disabled (never refreshable). A previous version of this file could report only the
// first two.

import 'package:pure_live_auth/pure_live_auth.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

/// One account of one site, as the surface renders it.
final class SiteAccount {
  const SiteAccount({
    required this.handle,
    required this.method,
    required this.status,
    required this.secretPresent,
    this.expiresAt,
    this.profile,
  });

  final CredentialHandle handle;
  final AuthMethod method;
  final AccountStatus status;

  /// True when the credential itself was found in the vault.
  ///
  /// A session record can outlive its secret - a user cleared app data partly, a vault migration failed -
  /// and that state is neither logged in nor logged out: it needs the re-login prompt without pretending the
  /// account disappeared.
  final bool secretPresent;

  final DateTime? expiresAt;
  final AccountProfile? profile;

  String get siteId => handle.providerId;
  String get accountId => handle.accountId;

  /// The label a row shows: what the user called themselves, else the id.
  String get displayName {
    final named = profile?.displayName ?? '';
    return named.isEmpty ? accountId : named;
  }

  bool get isUsable => status == AccountStatus.loggedIn && secretPresent;

  /// Worth a refresh attempt instead of a login prompt.
  ///
  /// `disabled` is excluded on purpose: the site ended that account, and a refresh loop against it is a
  /// request budget spent to be refused again.
  bool get canRefresh => secretPresent && (status == AccountStatus.expired || status == AccountStatus.unknown);

  @override
  String toString() => 'SiteAccount($siteId/$accountId $status${secretPresent ? '' : ' no-secret'})';
}

/// Why an account stopped being usable, as one event a host can route to one prompt.
final class SiteAccountExpiry {
  const SiteAccountExpiry({required this.siteId, required this.accountId, required this.reason});

  final String siteId;
  final String accountId;
  final String reason;
}

/// The account surface's view of the credential store.
abstract interface class SiteAccountRepository {
  /// Every account stored for [siteId].
  ///
  /// Ordered by the account id, not by insertion: a screen that lists accounts must show the same list in
  /// the same place after a restart, and the store's own order is whatever the key listing produced.
  Future<List<SiteAccount>> accountsOf(String siteId);

  /// The account a signed-in request should use for [siteId], or null when the site has none.
  Future<SiteAccount?> primaryAccount(String siteId);

  /// Stores a credential and returns the account it created.
  Future<SiteAccount> signIn({
    required String siteId,
    required String accountId,
    required AuthMethod method,
    required String secret,
    DateTime? expiresAt,
    AccountProfile? profile,
  });

  /// Marks an account with a new status, e.g. after a refresh succeeded or the site rejected it.
  Future<void> markStatus(SiteAccount account, AccountStatus status);

  /// Removes one account's credential and session together.
  Future<void> signOut(SiteAccount account);

  /// Removes every account of one site, for "sign out of 虎牙" as opposed to one account of it.
  ///
  /// Named separately from [signOut] because the previous single-account method was called with a site id
  /// and quietly picked one of that site's accounts.
  Future<void> signOutSite(String siteId);

  /// Expiry events, already folded to what a prompt needs.
  Stream<SiteAccountExpiry> get expiries;
}

/// Raised when an account operation cannot be carried out.
sealed class AccountFailure extends DomainFailure {
  AccountFailure(super.reason, {super.cause});
}

/// The operation could not be completed, with what is left behind named in [reason].
final class AccountOperationFailure extends AccountFailure {
  AccountOperationFailure(super.reason);
}

/// The named account did not exist, so the operation cannot be applied to it.
final class AccountNotFoundFailure extends AccountFailure {
  AccountNotFoundFailure(this.siteId, this.accountId) : super('no stored account for $siteId/$accountId');

  final String siteId;
  final String accountId;
}

/// The caller handed something that cannot identify an account.
final class AccountInputFailure extends AccountFailure {
  AccountInputFailure(super.reason);
}
