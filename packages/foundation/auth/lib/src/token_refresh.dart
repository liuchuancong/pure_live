// Module: lib/src/token_refresh.dart
// Purpose: Renew an account's credential before it dies, once per account at a time, and back off when the
// provider says no.
// Author: liuchuancong
// Created: 2026-10-11
//
// The reason this exists as its own type: every provider that can refresh has the same loop - read the
// session, decide it is close enough to expiry, renew, store, and on failure stop hammering - and every one of
// them gets a different detail wrong. The usual three are a stampede (ten retryable requests for one expired
// token), a refresh scheduled after the token already died, and a provider that keeps being asked after it has
// refused five times in a row.

import 'dart:async';
import 'dart:math';

import 'package:pure_live_utils/pure_live_utils.dart';

import 'credential_store.dart';
import 'session.dart';

/// What a renewer returned.
final class RenewedCredential {
  const RenewedCredential({required this.secret, this.expiresAt, this.profile});

  final String secret;

  /// Null means the provider did not say, which the coordinator reads as "unchanged", not as "never expires".
  final DateTime? expiresAt;

  /// Supplied only when the renewal also learned something about the account.
  final AccountProfile? profile;
}

/// A provider's answer to being asked to renew.
typedef CredentialRenewer = Future<RenewedCredential> Function(AuthSession session, String secret);

/// Why a refresh attempt ended the way it did.
enum RefreshStatus {
  /// A new credential is stored and the session is live again.
  renewed,

  /// Nothing was due: the credential is not close to expiry.
  notNeeded,

  /// The provider refused in a way asking again cannot fix; the account is marked expired.
  permanentFailure,

  /// The provider refused or the network failed; a retry is allowed after the backoff.
  retryableFailure,

  /// No secret is stored, so there is nothing to renew.
  noSecret,

  /// Anonymous accounts do not renew.
  notApplicable,

  /// A refresh for this account is already running, and this call joined it.
  coalesced,

  /// The previous failure's backoff has not elapsed yet.
  coolingDown,
}

/// One refresh decision, reported to whoever watches.
final class RefreshOutcome {
  const RefreshOutcome({
    required this.handle,
    required this.status,
    this.expiresAt,
    this.nextRetryAt,
    this.consecutiveFailures = 0,
    this.error,
  });

  final CredentialHandle handle;
  final RefreshStatus status;
  final DateTime? expiresAt;
  final DateTime? nextRetryAt;
  final int consecutiveFailures;
  final Object? error;

  bool get didRenew => status == RefreshStatus.renewed;
  bool get needsAttention => status == RefreshStatus.permanentFailure;

  @override
  String toString() =>
      'RefreshOutcome(${handle.providerId}/${handle.accountId} ${status.name}'
      '${expiresAt == null ? '' : ' until ${expiresAt!.toIso8601String()}'}'
      '${consecutiveFailures == 0 ? '' : ' failures=$consecutiveFailures'})';
}

/// A refresh that cannot be attempted, named for the reason.
///
/// [retryable] is the whole point of the type: a provider that answered "this refresh token is invalid" must
/// not be asked again on the next screen, while a timeout must.
final class RefreshFailure extends DomainFailure {
  const RefreshFailure(super.reason, {this.retryable = true, super.cause});

  final bool retryable;

  /// A refusal that repeating cannot fix.
  const RefreshFailure.permanent(super.reason, {super.cause}) : retryable = false;

  @override
  String toString() => 'RefreshFailure(${retryable ? 'retryable' : 'permanent'}: $reason)';
}

/// Renews credentials for the accounts a [CredentialStore] holds.
final class TokenRefreshCoordinator {
  TokenRefreshCoordinator({
    required this.store,
    required CredentialRenewer renew,
    this.lead = const Duration(minutes: 1),
    this.jitterRatio = 0.2,
    this.maxBackoff = const Duration(minutes: 15),
    this.backoffBase = const Duration(seconds: 20),
    this.failureLimit = 5,
    Clock? clock,
    Random? random,
  }) : _renew = renew,
       _clock = clock ?? systemClock,
       _random = random ?? Random() {
    if (failureLimit < 1) {
      throw const RefreshFailure('failureLimit must be at least 1');
    }
    if (backoffBase <= Duration.zero || maxBackoff < backoffBase) {
      throw const RefreshFailure('backoffBase must be positive and no larger than maxBackoff');
    }
  }

  final CredentialStore store;
  final CredentialRenewer _renew;

  /// How before expiry a renewal starts.
  ///
  /// A credential fetched at the last possible second is a request that fails halfway through, and the
  /// player that asked for it cannot tell that from a dead stream.
  final Duration lead;

  /// The fraction of [lead] scattered across accounts, so an app with ten accounts does not present ten
  /// renewals to one provider at the same instant every cycle.
  final double jitterRatio;

  final Duration backoffBase;
  final Duration maxBackoff;

  /// Consecutive failures after which the account is marked expired and left alone until something resets it.
  final int failureLimit;

  final Clock _clock;
  final Random _random;

  final Map<String, Future<RefreshOutcome>> _running = <String, Future<RefreshOutcome>>{};
  final Map<String, _FailureRecord> _failures = <String, _FailureRecord>{};
  final StreamController<RefreshOutcome> _outcomes = StreamController<RefreshOutcome>.broadcast();

  /// Every decision this coordinator made, including the ones it declined to make.
  Stream<RefreshOutcome> get outcomes => _outcomes.stream;

  Future<void> dispose() => _outcomes.close();

  /// The secret for [handle], renewed first if it is close to expiry.
  ///
  /// This is the entry point callers want: asking for a secret and getting one that still works, with the
  /// timing decision taken in one place rather than at each read site.
  Future<String?> authorizedSecret(CredentialHandle handle) async {
    final outcome = await refreshIfExpiring(handle);
    if (outcome.status == RefreshStatus.permanentFailure || outcome.status == RefreshStatus.coolingDown) {
      final session = await store.sessionOf(handle.providerId, handle.accountId);
      if (session == null || !session.isLoggedIn) {
        return null;
      }
    }
    return store.readSecret(handle);
  }

  /// Renews [handle] when its expiry is inside the lead window, and reports why when it does not.
  Future<RefreshOutcome> refreshIfExpiring(CredentialHandle handle) async {
    final session = await store.sessionOf(handle.providerId, handle.accountId);
    if (session == null) {
      return _publish(RefreshOutcome(handle: handle, status: RefreshStatus.noSecret));
    }
    if (session.method == AuthMethod.anonymous) {
      return _publish(RefreshOutcome(handle: handle, status: RefreshStatus.notApplicable));
    }
    final expiry = session.expiresAt;
    if (expiry == null) {
      // A credential that never says when it dies is renewed on demand only: guessing a lifetime would
      // either waste a provider's rate limit or produce the surprise this class exists to avoid.
      return _publish(RefreshOutcome(handle: handle, status: RefreshStatus.notNeeded));
    }
    final now = _clock().toUtc();
    final due = expiry.subtract(_jitteredLead());
    if (now.isBefore(due)) {
      return _publish(
        RefreshOutcome(handle: handle, status: RefreshStatus.notNeeded, expiresAt: expiry, nextRetryAt: due),
      );
    }
    return forceRefresh(handle);
  }

  /// Renews [handle] regardless of timing, which is what a 401 handler calls after a request already failed.
  Future<RefreshOutcome> forceRefresh(CredentialHandle handle) {
    final key = '${handle.providerId}/${handle.accountId}';
    final running = _running[key];
    if (running != null) {
      return running.then(
        (outcome) => RefreshOutcome(
          handle: handle,
          status: RefreshStatus.coalesced,
          expiresAt: outcome.expiresAt,
          nextRetryAt: outcome.nextRetryAt,
          consecutiveFailures: outcome.consecutiveFailures,
        ),
      );
    }
    final work = _refresh(handle, key);
    _running[key] = work;
    return work.whenComplete(() {
      if (identical(_running[key], work)) {
        _running.remove(key);
      }
    });
  }

  Future<RefreshOutcome> _refresh(CredentialHandle handle, String key) async {
    final now = _clock().toUtc();
    final record = _failures[key];
    if (record != null && record.isCoolingDownAt(now)) {
      return _publish(
        RefreshOutcome(
          handle: handle,
          status: RefreshStatus.coolingDown,
          nextRetryAt: record.retryAt,
          consecutiveFailures: record.attempts,
        ),
      );
    }

    final session = await store.sessionOf(handle.providerId, handle.accountId);
    final secret = await store.readSecret(handle);
    if (session == null || secret == null || secret.isEmpty) {
      return _publish(RefreshOutcome(handle: handle, status: RefreshStatus.noSecret));
    }

    try {
      final renewed = await _renew(session, secret);
      final expiresAt = renewed.expiresAt ?? session.expiresAt;
      await store.storeCredential(
        providerId: handle.providerId,
        accountId: handle.accountId,
        method: session.method,
        secret: renewed.secret,
        expiresAt: expiresAt,
        profile: renewed.profile ?? session.profile,
      );
      _failures.remove(key);
      return _publish(
        RefreshOutcome(handle: handle, status: RefreshStatus.renewed, expiresAt: expiresAt, consecutiveFailures: 0),
      );
    } on Object catch (error) {
      return _refused(handle, key, error, permanent: error is RefreshFailure && !error.retryable);
    }
  }

  RefreshOutcome _refused(CredentialHandle handle, String key, Object error, {required bool permanent}) {
    final now = _clock().toUtc();
    final record = (_failures[key] ?? _FailureRecord(attempts: 0, retryAt: now)).bump(
      now: now,
      backoffBase: backoffBase,
      maxBackoff: maxBackoff,
    );
    _failures[key] = record;

    if (permanent || record.attempts >= failureLimit) {
      // Marking the account expired is what stops every screen from trying again: the status is the shared
      // signal, and an account that is expired renders "please log in" instead of a spinner.
      unawaited(store.setStatus(handle, AccountStatus.expired));
      _failures.remove(key);
      return _publish(
        RefreshOutcome(
          handle: handle,
          status: RefreshStatus.permanentFailure,
          consecutiveFailures: record.attempts,
          error: error,
        ),
      );
    }
    return _publish(
      RefreshOutcome(
        handle: handle,
        status: RefreshStatus.retryableFailure,
        nextRetryAt: record.retryAt,
        consecutiveFailures: record.attempts,
        error: error,
      ),
    );
  }

  /// Forgets an account's failure history, which is what "the user just did something" means to a backoff.
  void resetBackoff(CredentialHandle handle) => _failures.remove('${handle.providerId}/${handle.accountId}');

  /// Whether this account is inside its backoff window right now.
  bool isCoolingDown(CredentialHandle handle) {
    final record = _failures['${handle.providerId}/${handle.accountId}'];
    return record != null && record.isCoolingDownAt(_clock().toUtc());
  }

  Duration _jitteredLead() {
    if (jitterRatio <= 0) {
      return lead;
    }
    final spread = (lead.inMilliseconds * jitterRatio).round();
    if (spread <= 0) {
      return lead;
    }
    // The jitter shortens the lead rather than extending it, so the worst case is still a renewal before the
    // credential dies - a longer lead would mean asking early, which is what a provider's rate limit notices.
    return Duration(milliseconds: lead.inMilliseconds - _random.nextInt(spread + 1));
  }

  RefreshOutcome _publish(RefreshOutcome outcome) {
    if (!_outcomes.isClosed) {
      _outcomes.add(outcome);
    }
    return outcome;
  }
}

final class _FailureRecord {
  const _FailureRecord({required this.attempts, required this.retryAt});

  final int attempts;
  final DateTime retryAt;

  bool isCoolingDownAt(DateTime now) => now.toUtc().isBefore(retryAt.toUtc());

  /// The next attempt count and the window that goes with it, doubled per failure and capped.
  ///
  /// Doubling without a cap turns one offline evening into a coordinator that will not retry for a day; no
  /// growth at all turns a refusing provider into a hammer.
  _FailureRecord bump({required DateTime now, required Duration backoffBase, required Duration maxBackoff}) {
    final next = attempts + 1;
    final exponent = next > 12 ? 12 : next - 1;
    var delay = backoffBase * (1 << exponent);
    if (delay > maxBackoff) {
      delay = maxBackoff;
    }
    return _FailureRecord(attempts: next, retryAt: now.toUtc().add(delay));
  }
}
