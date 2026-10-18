// The named flow-state constructors spell their class name by convention
// here; the `.new` shorthand hurts readability more than the lint helps.
// riverpod's family types (ProviderFamily, NotifierProviderFamily) are not
// exported by flutter_riverpod, so the variable annotations the lint asks
// for cannot be written.
// ignore_for_file: unnecessary_type_name_in_constructor, specify_nonobvious_property_types

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart'
    show LiveAuthCapability, LiveAuthPollStatus, LiveAuthSession, LiveCredential, LiveSite, LiveSiteError;
import 'package:pure_live/app/providers/app_providers.dart' show sitesProvider;

import 'package:pure_live/features/login/login_repository.dart';

/// The sites the build can sign somebody into, in registration order.
///
/// The account hub's list and the login page's picker both read this, so a
/// platform that grows an auth adapter appears in both without a second edit —
/// the reference ships one cookie page per platform it can sign in, and a
/// hardcoded list is how that list goes stale.
final authSitesProvider = Provider<List<LiveSite>>(
  (ref) => [
    for (final site in ref.watch(sitesProvider).registry.all)
      if (site.capability<LiveAuthCapability>() != null) site,
  ],
);

/// The site whose login is the QR flow (the others sign in by paste).
///
/// `LiveAuthCapability` answers both flows and throws `UnsupportedError` from
/// the one a platform does not ship, which is not something a row can ask
/// without trying to start a session — so the flow a site signs in with stays
/// stated here until the capability says it.
const String qrLoginSite = 'bilibili';

/// Whether a site's row offers the QR scan or the cookie paste.
bool siteUsesQrLogin(String siteId) => siteId == qrLoginSite;

/// The auth capability of a sign-in site, null when the build ships no such
/// adapter or the adapter signs nobody in. The registry is static after
/// boot, so the entry never changes.
final authCapabilityProvider = Provider.family<LiveAuthCapability?, String>(
  (ref, siteId) => ref.watch(sitesProvider).registry.getById(siteId)?.capability<LiveAuthCapability>(),
);

/// A site's login persistence, one per process — the store it wraps caches
/// the vault's secrets in memory after its first read.
final loginRepositoryProvider = Provider.family<LoginRepository, String>(
  (ref, siteId) => LoginRepository(siteId: siteId),
);

/// The signed-in account of the site the family is read with, null while
/// signed out.
///
/// The first watch initialises lazily (the composition root has no login
/// hook): the stored credential is loaded and applied back onto the site, so
/// the site's requests carry the login from the first watch on. Both writing
/// paths go through this controller — a login (the bilibili QR exchange, a
/// pasted cookie) adopting its credential and the sign-out — which keeps the
/// published account and the applied cookies in step without invalidation
/// races.
final accountProvider = NotifierProvider.family<AccountController, LiveCredential?, String>(AccountController.new);

/// Keeps the [LiveCredential] the user signed in with for one site under the
/// provider the account surfaces watch.
final class AccountController extends Notifier<LiveCredential?> {
  /// Keeps the account of this site.
  AccountController(this.siteId);

  /// The site (`bilibili`, `douyu`, `huya`) this controller signs in.
  final String siteId;

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
    final repository = ref.read(loginRepositoryProvider(siteId));
    final credential = await repository.load();
    if (credential == null || _disposed) {
      return;
    }
    final auth = ref.read(authCapabilityProvider(siteId));
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

  /// Adopts the credential a successful login granted: applies it to the
  /// site, stores it, and publishes it as the signed-in account.
  Future<void> adopt(LiveCredential credential) async {
    final auth = ref.read(authCapabilityProvider(siteId));
    if (auth == null) {
      return;
    }
    await auth.applyCredential(credential);
    await ref.read(loginRepositoryProvider(siteId)).save(credential);
    if (!_disposed) {
      state = credential;
    }
  }

  /// Signs out: detaches the credential from the site and removes the stored
  /// document, so the next start-up does not sign the user back in.
  Future<void> signOut() async {
    try {
      await ref.read(authCapabilityProvider(siteId))?.clearCredential();
    } on Object catch (_) {
      // The site's detach is best effort: the stored secret must go either
      // way, or the next start-up signs the user back in.
    }
    await ref.read(loginRepositoryProvider(siteId)).clear();
    if (!_disposed) {
      state = null;
    }
  }
}

/// Every signed-in account by site id; the account page's list and the
/// settings row read this.
final signedInAccountsProvider = Provider<Map<String, LiveCredential>>((ref) {
  final accounts = <String, LiveCredential>{};
  for (final siteId in ref.watch(authSitesProvider).map((site) => site.manifest.id)) {
    final credential = ref.watch(accountProvider(siteId));
    if (credential != null) {
      accounts[siteId] = credential;
    }
  }
  return accounts;
});

/// How a cookie paste stands while the login page watches it.
enum CookiePastePhase {
  /// The field waits for the paste.
  editing,

  /// The paste is being verified against its site.
  verifying,

  /// The paste verified and the credential is applied.
  success,

  /// The site refused the paste; [CookiePasteState.message] is the site's
  /// own failure text, shown as-is.
  failure,
}

/// One snapshot of a cookie paste's state.
final class CookiePasteState {
  /// A state of [phase].
  const CookiePasteState({required this.phase, this.message, this.account});

  /// The field waits for the paste.
  const CookiePasteState.editing() : this(phase: CookiePastePhase.editing);

  /// The paste is being verified.
  const CookiePasteState.verifying() : this(phase: CookiePastePhase.verifying);

  /// The paste verified; [account] is the credential it granted.
  const CookiePasteState.success({required LiveCredential account})
    : this(phase: CookiePastePhase.success, account: account);

  /// The site refused the paste; [message] is its failure text.
  const CookiePasteState.failure({required String message}) : this(phase: CookiePastePhase.failure, message: message);

  /// How the paste stands.
  final CookiePastePhase phase;

  /// The site's failure text, set once [CookiePastePhase.failure] answers.
  final String? message;

  /// The granted credential, set once [CookiePastePhase.success] answers.
  final LiveCredential? account;
}

/// The cookie paste of the site the family is read with, null when the
/// build ships no such capability
/// — the login page degrades to an honest "unsupported" state instead of a
/// button that never lands.
///
/// The provider is auto-dispose, so leaving the page clears the field and
/// any failure text with it.
final cookiePasteProvider = NotifierProvider.autoDispose.family<CookiePasteController, CookiePasteState, String>(
  CookiePasteController.new,
);

/// Verifies a pasted browser cookie against its site and hands the granted
/// credential to [accountProvider] — apply, store, publish in one move.
final class CookiePasteController extends Notifier<CookiePasteState> {
  /// Pastes into this site.
  CookiePasteController(this.siteId);

  /// The site the paste signs in.
  final String siteId;

  bool _disposed = false;

  @override
  CookiePasteState build() {
    ref.onDispose(() => _disposed = true);
    return const CookiePasteState.editing();
  }

  /// Verifies [rawCookieHeader] and adopts the credential it grants; the
  /// site's refusal is surfaced with its own message, verbatim.
  Future<void> verify(String rawCookieHeader) async {
    final auth = ref.read(authCapabilityProvider(siteId));
    if (auth == null || _disposed) {
      return;
    }
    state = const CookiePasteState.verifying();
    try {
      final credential = await auth.applyPastedCookie(rawCookieHeader);
      await ref.read(accountProvider(siteId).notifier).adopt(credential);
      if (!_disposed) {
        state = CookiePasteState.success(account: credential);
      }
    } on Object catch (error) {
      if (!_disposed) {
        state = CookiePasteState.failure(message: _messageOf(error));
      }
    }
  }

  /// The failure text to show: a site refusal is a [LiveSiteError] whose
  /// message is the site's own text, anything else is shown as it reads.
  static String _messageOf(Object error) {
    final message = switch (error) {
      final LiveSiteError failure => failure.message,
      _ => null,
    };
    return message ?? '$error';
  }
}

/// The bilibili QR login's provider — the flow starts when the login page's
/// picker lands on bilibili and stops when the page is left.
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
    final auth = ref.read(authCapabilityProvider(qrLoginSite));
    if (_disposed || auth == null) {
      return;
    }
    _consecutiveErrors = 0;
    state = const LoginFlowState.generating();
    _session = auth.startQrLogin();
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
      final credential = await ref.read(authCapabilityProvider(qrLoginSite))!.exchange(session);
      await ref.read(accountProvider(qrLoginSite).notifier).adopt(credential);
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
