// The named flow-state constructors spell their class name by convention
// here; the `.new` shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveAuthCapability, LiveAuthPollStatus, LiveAuthSession, LiveCredential;
import 'package:pure_live/app/providers/app_providers.dart' show sitesProvider;

import 'package:pure_live/features/login/login_repository.dart';

/// The bilibili site's auth capability, null when the build ships no bilibili
/// adapter. The registry is static after boot, so the entry never changes.
final bilibiliAuthProvider = Provider<LiveAuthCapability?>(
  (ref) => ref.watch(sitesProvider).registry.getById('bilibili')?.capability<LiveAuthCapability>(),
);

/// The login feature's persistence, one per process — the store it wraps
/// caches the vault's secrets in memory after its first read.
final loginRepositoryProvider = Provider<LoginRepository>((ref) => LoginRepository());

/// The signed-in bilibili account, null while signed out.
///
/// The first watch initialises lazily (the composition root has no login
/// hook): the stored credential is loaded and applied back onto the site, so
/// the site's requests carry the login from the first watch on. Both writing
/// paths go through this controller — the login flow adopting the exchanged
/// credential and the sign-out — which keeps the published account and the
/// applied cookies in step without invalidation races.
final accountProvider = NotifierProvider<AccountController, LiveCredential?>(AccountController.new);

/// Keeps the [LiveCredential] the user signed in with under the provider the
/// account surfaces watch.
final class AccountController extends Notifier<LiveCredential?> {
  bool _disposed = false;

  @override
  LiveCredential? build() {
    ref.onDispose(() => _disposed = true);
    unawaited(_hydrate());
    return null;
  }

  /// Loads the stored credential and applies it back onto the site.
  ///
  /// A credential the site refuses (an expired cookie, a changed format) is
  /// dropped together with its stored document — keeping it would fail every
  /// later start-up the same way.
  Future<void> _hydrate() async {
    final repository = ref.read(loginRepositoryProvider);
    final credential = await repository.load();
    if (credential == null || _disposed) {
      return;
    }
    final auth = ref.read(bilibiliAuthProvider);
    if (auth == null) {
      return;
    }
    try {
      await auth.applyCredential(credential);
    } on Object catch (_) {
      await repository.clear();
      return;
    }
    if (!_disposed) {
      state = credential;
    }
  }

  /// Adopts the credential a successful login exchanged: applies it to the
  /// site, stores it, and publishes it as the signed-in account.
  Future<void> adopt(LiveCredential credential) async {
    final auth = ref.read(bilibiliAuthProvider);
    if (auth == null) {
      return;
    }
    await auth.applyCredential(credential);
    await ref.read(loginRepositoryProvider).save(credential);
    if (!_disposed) {
      state = credential;
    }
  }

  /// Signs out: detaches the credential from the site and removes the stored
  /// document, so the next start-up does not sign the user back in.
  Future<void> signOut() async {
    try {
      await ref.read(bilibiliAuthProvider)?.clearCredential();
    } on Object catch (_) {
      // The site's detach is best effort: the stored secret must go either
      // way, or the next start-up signs the user back in.
    }
    await ref.read(loginRepositoryProvider).clear();
    if (!_disposed) {
      state = null;
    }
  }
}

/// The bilibili QR login's provider, null when the build ships no capability
/// — the login page degrades to an honest "unsupported" state instead of a
/// spinner that never lands.
final NotifierProvider<LoginFlowController, LoginFlowState> loginFlowProvider =
    NotifierProvider.autoDispose<LoginFlowController, LoginFlowState>(LoginFlowController.new);

/// How a QR login stands while the login page watches it.
enum LoginPhase {
  /// The QR is being issued; nothing to render yet.
  generating,

  /// The QR is on screen and polled; the platform has not confirmed it.
  scanning,

  /// The platform confirmed the login and the credential is applied.
  success,

  /// The QR expired; the user can start over with a fresh one.
  expired,

  /// The flow broke down (transport or exchange) and stopped polling.
  failure,
}

/// One snapshot of the login page's flow state.
final class LoginFlowState {
  /// A flow state of [phase].
  const LoginFlowState({required this.phase, this.qrContent = '', this.account});

  /// The QR is being issued.
  const LoginFlowState.generating() : this(phase: LoginPhase.generating);

  /// The QR is on screen and polled; [qrContent] encodes it (empty while the
  /// issue request is still in flight).
  const LoginFlowState.scanning({String qrContent = ''}) : this(phase: LoginPhase.scanning, qrContent: qrContent);

  /// The login landed; [account] is the credential the exchange granted.
  const LoginFlowState.success({required LiveCredential account, String qrContent = ''})
    : this(phase: LoginPhase.success, qrContent: qrContent, account: account);

  /// The QR expired.
  const LoginFlowState.expired({String qrContent = ''}) : this(phase: LoginPhase.expired, qrContent: qrContent);

  /// The flow broke down and stopped polling.
  const LoginFlowState.failure() : this(phase: LoginPhase.failure);

  /// How the login stands.
  final LoginPhase phase;

  /// The content to encode into the QR image; empty while unknown.
  final String qrContent;

  /// The signed-in credential, set once [LoginPhase.success] answers.
  final LiveCredential? account;
}

/// Drives the bilibili QR login the login page renders: starts a session,
/// polls it on a timer until it answers success or expired, and hands the
/// granted credential to [accountProvider].
///
/// The provider is auto-dispose, so leaving the page cancels the poll timer
/// with it; re-entering starts a fresh session rather than resurrecting a
/// stale QR.
final class LoginFlowController extends Notifier<LoginFlowState> {
  static const Duration _pollInterval = Duration(seconds: 2);

  // One failed round is a network hiccup; this many in a row is a broken
  // flow worth failing honestly instead of polling forever.
  static const int _errorTolerance = 3;

  LiveAuthSession? _session;
  Timer? _timer;
  bool _pollInFlight = false;
  int _consecutiveErrors = 0;
  bool _disposed = false;

  @override
  LoginFlowState build() {
    ref.onDispose(() {
      _disposed = true;
      _stop();
    });
    unawaited(start());
    return const LoginFlowState.generating();
  }

  /// Starts (or restarts, after an expiry or a failure) the login: a fresh
  /// session, a first poll that also carries the QR issue, then the timer.
  Future<void> start() async {
    _stop();
    if (_disposed || ref.read(bilibiliAuthProvider) == null) {
      return;
    }
    _consecutiveErrors = 0;
    state = const LoginFlowState.generating();
    _session = ref.read(bilibiliAuthProvider)!.startQrLogin();
    if (await _poll()) {
      _timer ??= Timer.periodic(_pollInterval, (_) => unawaited(_tick()));
    }
  }

  Future<void> _tick() async {
    if (_pollInFlight) {
      return; // A round still running: skip this tick, the timer stays armed.
    }
    if (!await _poll()) {
      _stop();
    }
  }

  /// One poll round; returns whether polling continues.
  Future<bool> _poll() async {
    final session = _session;
    if (session == null || _disposed) {
      return false;
    }
    _pollInFlight = true;
    try {
      final result = await session.poll();
      if (_disposed) {
        return false;
      }
      switch (result.status) {
        case LiveAuthPollStatus.pending:
          _consecutiveErrors = 0;
          state = LoginFlowState.scanning(qrContent: _qrOf(session));
          return true;
        case LiveAuthPollStatus.expired:
          state = LoginFlowState.expired(qrContent: _qrOf(session));
          return false;
        case LiveAuthPollStatus.success:
          await _complete(session);
          return false;
      }
    } on Object catch (_) {
      _consecutiveErrors++;
      if (_consecutiveErrors >= _errorTolerance) {
        if (!_disposed) {
          state = const LoginFlowState.failure();
        }
        return false;
      }
      return true;
    } finally {
      _pollInFlight = false;
    }
  }

  /// Exchanges the confirmed session for the credential and adopts it into
  /// [accountProvider] — apply, store, publish in one move.
  Future<void> _complete(LiveAuthSession session) async {
    try {
      final credential = await ref.read(bilibiliAuthProvider)!.exchange(session);
      await ref.read(accountProvider.notifier).adopt(credential);
      if (!_disposed) {
        state = LoginFlowState.success(account: credential, qrContent: _qrOf(session));
      }
    } on Object catch (_) {
      if (!_disposed) {
        state = const LoginFlowState.failure();
      }
    }
  }

  /// The session's QR content, empty while the issue request is still in
  /// flight (reading it earlier throws by contract).
  String _qrOf(LiveAuthSession session) {
    try {
      return session.qrContent;
    } on Object catch (_) {
      return '';
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }
}
