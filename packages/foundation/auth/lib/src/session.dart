// Module: lib/src/session.dart
// Purpose: Account state, the non-secret profile and the credential handle that stands in for a secret.
// Author: liuchuancong
// Created: 2026-10-08
//
// Per docs/security/credential-storage.md, code outside this package never holds a credential: it holds a
// handle and asks the store for an authenticated request. That is why AccountProfile and AuthSession are
// safe to log, cache or sync while the secret is not.

/// How an account authenticated.
enum AuthMethod { cookie, token, oauth, qrCode, deviceLogin, anonymous }

/// Where an account stands. `expired` is distinct from `loggedOut`: the former can often be refreshed.
enum AccountStatus { unknown, loggedOut, loggedIn, expired, disabled }

/// A reference to a stored secret, never the secret itself.
final class CredentialHandle {
  const CredentialHandle({
    required this.providerId,
    required this.accountId,
    required this.key,
  });

  /// The storage key for this credential. Exposed for the store, not for logging.
  final String key;
  final String providerId;
  final String accountId;

  @override
  String toString() => 'CredentialHandle($providerId/$accountId)';

  @override
  bool operator ==(Object other) {
    return other is CredentialHandle &&
        other.providerId == providerId &&
        other.accountId == accountId &&
        other.key == key;
  }

  @override
  int get hashCode => Object.hash(providerId, accountId, key);
}

/// Display information about an account. Contains nothing that would be useful to an attacker.
final class AccountProfile {
  const AccountProfile({
    required this.providerId,
    required this.accountId,
    this.displayName = '',
    this.avatarUrl,
    this.vipLabel,
  });

  final String providerId;
  final String accountId;
  final String displayName;
  final String? avatarUrl;

  /// A membership tier label, shown in the UI and used by quality defaults.
  final String? vipLabel;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'providerId': providerId,
      'accountId': accountId,
      if (displayName.isNotEmpty) 'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (vipLabel != null) 'vipLabel': vipLabel,
    };
  }

  factory AccountProfile.fromJson(Map<String, Object?> json) => AccountProfile(
        providerId: json['providerId']! as String,
        accountId: json['accountId']! as String,
        displayName: json['displayName'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String?,
        vipLabel: json['vipLabel'] as String?,
      );
}

/// The state of one login, including when it stops being valid.
final class AuthSession {
  const AuthSession({
    required this.handle,
    required this.method,
    required this.status,
    this.expiresAt,
    this.profile,
  });

  final CredentialHandle handle;
  final AuthMethod method;
  final AccountStatus status;

  /// When the credential stops working; null means the provider never said.
  final DateTime? expiresAt;
  final AccountProfile? profile;

  bool get isLoggedIn => status == AccountStatus.loggedIn;

  /// Whether the session is past its expiry at [now].
  ///
  /// An unknown expiry is treated as valid: several providers never report one, and refusing those
  /// requests would log everyone out on restart.
  bool isExpiredAt(DateTime now) {
    final expiry = expiresAt;
    return expiry != null && !now.toUtc().isBefore(expiry);
  }

  AuthSession withStatus(AccountStatus next) => AuthSession(
        handle: handle,
        method: method,
        status: next,
        expiresAt: expiresAt,
        profile: profile,
      );

  /// A copy safe to put in a diagnostic report: identity and status, no credential.
  Map<String, Object?> toDiagnosticJson() {
    return <String, Object?>{
      'providerId': handle.providerId,
      'accountId': handle.accountId,
      'method': method.name,
      'status': status.name,
      if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
    };
  }
}
