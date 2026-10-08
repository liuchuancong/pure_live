// Module: lib/src/credential_store.dart
// Purpose: The single reader and writer of credentials, plus the account lifecycle it owns.
// Author: liuchuancong
// Created: 2026-10-08
//
// docs/security/credential-storage.md makes this package the only party allowed to touch a credential: a
// provider gets a handle it can use for an authenticated request, never the plaintext. Clearing an account
// removes every trace of it in one call, because a v1 douyu session survived logout by leaving a second
// key behind.

import 'dart:async';

import 'package:pure_live_utils/pure_live_utils.dart';

import 'ports.dart';
import 'session.dart';

/// Where a session was lost, so the host can decide whether to prompt for a re-login.
final class AuthExpiry {
  const AuthExpiry({required this.session, required this.reason});

  final AuthSession session;
  final String reason;
}

/// Stores credentials in a [SecureStore] and their non-secret state in a [KeyValueStore].
final class CredentialStore {
  CredentialStore({
    required SecretVault secrets,
    required SessionBox settings,
    Clock? clock,
  }) : _secrets = secrets,
       _settings = settings,
       _clock = clock ?? systemClock;

  static const String _secretPrefix = authSecretKeyPrefix;
  static const String _sessionPrefix = authSessionKeyPrefix;

  final SecretVault _secrets;
  final SessionBox _settings;
  final Clock _clock;
  final StreamController<AuthExpiry> _expiry = StreamController<AuthExpiry>.broadcast();

  /// Emitted when a session is found expired or is marked as such. The host decides whether to show UI.
  Stream<AuthExpiry> get expiryEvents => _expiry.stream;

  Future<void> dispose() async => _expiry.close();

  /// Saves a credential and its session record, returning the handle callers must use from now on.
  Future<CredentialHandle> storeCredential({
    required String providerId,
    required String accountId,
    required AuthMethod method,
    required String secret,
    DateTime? expiresAt,
    AccountProfile? profile,
  }) async {
    final handle = CredentialHandle(
      providerId: providerId,
      accountId: accountId,
      key: _secretKey(providerId, accountId),
    );
    await _secrets.write(handle.key, secret);
    await _writeSession(
      handle,
      AuthSession(
        handle: handle,
        method: method,
        status: AccountStatus.loggedIn,
        // Persisted timestamps are UTC so a device moving time zones cannot extend or cut a session.
        expiresAt: expiresAt?.toUtc(),
        profile: profile,
      ),
    );
    return handle;
  }

  Future<String?> readSecret(CredentialHandle handle) => _secrets.read(handle.key);

  /// Reads a session and reports it as expired if the clock says so, without mutating storage.
  Future<AuthSession?> sessionOf(String providerId, String accountId) async {
    final stored = await _readSession(providerId, accountId);
    if (stored == null) {
      return null;
    }
    if (stored.isLoggedIn && stored.isExpiredAt(_clock())) {
      final expired = stored.withStatus(AccountStatus.expired);
      _emit(AuthExpiry(session: expired, reason: 'expired'));
      return expired;
    }
    return stored;
  }

  /// Moves an account to a new status, for example after a refresh or a logout elsewhere.
  Future<void> setStatus(CredentialHandle handle, AccountStatus status) async {
    final stored = await _readSession(handle.providerId, handle.accountId);
    if (stored == null) {
      return;
    }
    await _writeSession(handle, stored.withStatus(status));
    if (status != AccountStatus.loggedIn) {
      _emit(AuthExpiry(session: stored.withStatus(status), reason: 'status:${status.name}'));
    }
  }

  /// Every account that has a stored session, across providers.
  Future<List<AuthSession>> sessions() async {
    final sessions = <AuthSession>[];
    for (final key in await _settings.keys()) {
      if (!key.startsWith(_sessionPrefix)) {
        continue;
      }
      final pair = key.substring(_sessionPrefix.length).split('.');
      if (pair.length < 2) {
        continue;
      }
      final session = await sessionOf(pair.first, pair.sublist(1).join('.'));
      if (session != null) {
        sessions.add(session);
      }
    }
    return sessions;
  }

  /// Removes the credential and the session record, which carries the profile, in one operation.
  ///
  /// Callers must not clean up parts of this themselves: a leftover key is how a v1 douyu session survived
  /// logout.
  Future<void> clearAccount({required String providerId, required String accountId}) async {
    await _secrets.remove(_secretKey(providerId, accountId));
    await _settings.remove('$_sessionPrefix$providerId.$accountId');
  }

  /// Deletes everything this package owns; used by "sign out of all accounts" and by tests.
  Future<void> clearAll() async {
    for (final session in await sessions()) {
      await clearAccount(
        providerId: session.handle.providerId,
        accountId: session.handle.accountId,
      );
    }
  }

  /// Diagnostic view: identity and status only, never a secret.
  Future<List<Map<String, Object?>>> describeForDiagnostics() async {
    return (await sessions()).map((session) => session.toDiagnosticJson()).toList(growable: false);
  }

  String _secretKey(String providerId, String accountId) => '$_secretPrefix$providerId.$accountId';

  Future<void> _writeSession(CredentialHandle handle, AuthSession session) async {
    await _settings.write('$_sessionPrefix${handle.providerId}.${handle.accountId}', {
      'providerId': handle.providerId,
      'accountId': handle.accountId,
      'method': session.method.name,
      'status': session.status.name,
      if (session.expiresAt != null) 'expiresAt': session.expiresAt!.toUtc().toIso8601String(),
      if (session.profile != null) 'profile': session.profile!.toJson(),
    });
  }

  Future<AuthSession?> _readSession(String providerId, String accountId) async {
    final raw = await _settings.read('$_sessionPrefix$providerId.$accountId');
    if (raw is! Map) {
      return null;
    }
    final fields = Map<String, Object?>.from(raw);
    final profileJson = fields['profile'];
    return AuthSession(
      handle: CredentialHandle(
        providerId: providerId,
        accountId: accountId,
        key: _secretKey(providerId, accountId),
      ),
      method: _byName(AuthMethod.values, fields['method'] as String?) ?? AuthMethod.token,
      status: _byName(AccountStatus.values, fields['status'] as String?) ?? AccountStatus.unknown,
      expiresAt: fields['expiresAt'] == null ? null : DateTime.parse('${fields['expiresAt']}').toUtc(),
      profile: profileJson is Map ? AccountProfile.fromJson(Map<String, Object?>.from(profileJson)) : null,
    );
  }

  void _emit(AuthExpiry event) {
    if (!_expiry.isClosed) {
      _expiry.add(event);
    }
  }

  static T? _byName<T extends Enum>(List<T> values, String? name) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }
}

/// The key prefixes CredentialStore owns; a backup or sync filter excludes them by prefix, because
/// docs/security/credential-storage.md forbids shipping credentials to another device.
const String authSecretKeyPrefix = 'auth.secret.';
const String authSessionKeyPrefix = 'auth.session.';

const List<String> authOwnedKeyPrefixes = <String>[authSecretKeyPrefix, authSessionKeyPrefix];

/// True when [key] belongs to the auth package and must never be exported or synced.
bool isAuthOwnedKey(String key) => authOwnedKeyPrefixes.any(key.startsWith);
