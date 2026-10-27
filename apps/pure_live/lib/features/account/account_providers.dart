import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart'
    show LiveAuthCapability, LiveAuthSession, LiveCredential, LiveSite, LiveSiteError, SiteIds;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/account/account_repository.dart';
import 'package:pure_live/features/account/account_state.dart';
import 'package:pure_live/features/account/bilibili_web_cookies.dart' show clearBilibiliWebCookies;
import 'package:pure_live/features/account/douyu_cookie_saved_at.dart' show douyuCookieSavedAtProvider;
import 'package:pure_live/shared/shared.dart';

/// The accounts repository (one secret store, one process).
final accountRepositoryProvider = FutureProvider<AccountRepository>((ref) => AccountRepository.open());

/// What the account pane holds: whether the repository has opened yet, the
/// stored credentials keyed by site id, and the sites whose stored document
/// cannot be read back.
typedef AccountsState = ({bool ready, Map<String, LiveCredential> credentials, Set<String> unreadable});

/// The pane's view of one platform: what it has stored, and whether the
/// stored document is one the app can open.
AccountSnapshot accountSnapshotOf(AccountsState state, String siteId) =>
    AccountSnapshot(credential: state.credentials[siteId], unreadable: state.unreadable.contains(siteId));

/// Mirrors the accounts repository into the widget tree, like the
/// recorder's task list: it lists once the repository opens and follows
/// the store's change stream. Sign-ins and sign-outs go through here so
/// the pane, the site adapters and the secret store move together.
final class AccountsController extends Notifier<AccountsState> {
  StreamSubscription<void>? _subscription;
  bool _restored = false;

  @override
  AccountsState build() {
    ref.watch(accountRepositoryProvider).whenData((repository) {
      _subscription ??= repository.watch().listen((_) => _refresh(repository));
      _refresh(repository);
      if (!_restored) {
        _restored = true;
        // Applying is in-memory, so every process start re-applies the
        // stored cookies onto the site adapters' requests.
        unawaited(_applyStored(repository));
      }
    });
    ref.onDispose(() => unawaited(_subscription?.cancel() ?? Future<void>.value()));
    return (ready: false, credentials: const {}, unreadable: const {});
  }

  /// The auth capability behind [siteId], or null when the site has none.
  LiveAuthCapability? authOf(String siteId) =>
      ref.read(sitesProvider).getById(siteId)?.capability<LiveAuthCapability>();

  /// Completes a QR sign-in: exchanges the confirmed [session] for the
  /// credential, applies it to the site and stores it. Answers the
  /// failure, or null when the sign-in landed.
  Future<Object?> completeQrLogin(String siteId, LiveAuthSession session) async {
    final auth = authOf(siteId);
    if (auth == null) return StateError('site $siteId has no auth capability');
    try {
      final credential = await auth.exchange(session);
      await _applyAndStore(auth, credential);
      return null;
    } on Object catch (error) {
      return error;
    }
  }

  /// Signs in with a pasted browser cookie: the site verifies the paste,
  /// the credential is applied to the site and stored. Answers the
  /// failure, or null when the sign-in landed.
  Future<Object?> signInWithCookie(String siteId, String rawCookie) async {
    final auth = authOf(siteId);
    if (auth == null) return StateError('site $siteId has no auth capability');
    try {
      final credential = await auth.applyPastedCookie(rawCookie);
      await _applyAndStore(auth, credential);
      return null;
    } on Object catch (error) {
      return error;
    }
  }

  /// Signs [siteId] out: the site detaches its applied credential and the
  /// stored copy leaves the secret store. Douyu also loses the renewal pair
  /// and the cookie's save time kept beside it, so the login is gone whole
  /// rather than leaving a renewable half-behind. Bilibili also loses the
  /// remembered copy of exactly this login (the roster entry it is) and the
  /// built-in browser's bilibili cookies, so neither can sign the viewer back
  /// in behind their own choice.
  Future<void> signOut(String siteId) async {
    final auth = authOf(siteId);
    if (auth != null) {
      try {
        await auth.clearCredential();
      } on Object {
        // The site runs as a guest regardless; the stored copy still leaves.
      }
    }
    final repository = ref.read(accountRepositoryProvider).value;
    if (repository == null) return;
    // Read what is being left before it goes: the roster matches on it.
    final leaving = repository.get(siteId);
    await repository.remove(siteId);
    if (siteId == 'douyu') {
      await repository.clearDouyuPair();
      await ref.read(douyuCookieSavedAtProvider.notifier).clear();
    }
    if (siteId == SiteIds.bilibili) {
      await repository.forgetBilibiliAccountsOf(
        uid: int.tryParse(leaving?.userId ?? ''),
        cookie: accountCookieLine(leaving),
      );
      try {
        await clearBilibiliWebCookies();
      } on Object {
        // Signed out all the same; the browser's leftovers are not the login.
      }
    }
    _refresh(repository);
  }

  /// The remembered bilibili sign-ins, most recently used first.
  ///
  /// Read off the vault, not carried in [AccountsState]: every roster write
  /// lands under `credentials/`, so watching the accounts state re-reads the
  /// list after a sign-in, a switch, a deletion or a sign-out.
  List<BilibiliAccount> bilibiliAccounts() =>
      ref.read(accountRepositoryProvider).value?.bilibiliAccounts() ?? const <BilibiliAccount>[];

  /// Makes the remembered bilibili sign-in [uid] the current login (K01.2):
  /// its cookie goes through the same sign-in a paste does — the platform is
  /// asked first, and one it says signs in nobody is not stored — and the
  /// entry is marked used so the roster's order follows. Answers the failure,
  /// or null when the switch landed.
  Future<Object?> switchBilibiliAccount(int uid) async {
    final repository = ref.read(accountRepositoryProvider).value;
    if (repository == null) return StateError('the secret store has not opened yet');
    final account = repository.bilibiliAccount(uid);
    if (account == null) return StateError('bilibili account $uid is not remembered');
    final failure = await signInWithCookie(SiteIds.bilibili, account.cookie);
    if (failure != null) return failure;
    await repository.touchBilibiliAccount(uid);
    return null;
  }

  /// Forgets the remembered bilibili sign-in [uid]. The current login is
  /// untouched: leaving that is [signOut]. Answers the failure, or null.
  Future<Object?> forgetBilibiliAccount(int uid) async {
    final repository = ref.read(accountRepositoryProvider).value;
    if (repository == null) return StateError('the secret store has not opened yet');
    try {
      await repository.forgetBilibiliAccount(uid);
    } on Object catch (error) {
      return error;
    }
    _refresh(repository);
    return null;
  }

  Future<void> _applyAndStore(LiveAuthCapability auth, LiveCredential credential) async {
    await auth.applyCredential(credential);
    final repository = ref.read(accountRepositoryProvider).value;
    if (repository == null) {
      // The site carries the credential for this session; storing waits
      // for the secret store to open.
      return;
    }
    await repository.save(credential);
    // A bilibili login is also remembered, so the next one can be switched
    // back to without a new scan. The login itself is stored either way.
    if (credential.siteId == SiteIds.bilibili) await _rememberBilibili(repository, credential);
    _refresh(repository);
  }

  /// Adds the just-stored bilibili login [credential] to the remembered
  /// sign-ins. A login whose uid the platform did not name, or whose cookie is
  /// not the one stored, is left out of the roster: an entry the app cannot
  /// switch back with would only take a slot. A failing secret store costs the
  /// same, and never the login itself.
  Future<void> _rememberBilibili(AccountRepository repository, LiveCredential credential) async {
    final uid = int.tryParse(credential.userId ?? '');
    final cookie = accountCookieLine(credential);
    if (uid == null || uid <= 0 || cookie.isEmpty) return;
    try {
      await repository.rememberBilibiliAccount(
        BilibiliAccount(
          uid: uid,
          name: credential.nickname ?? '',
          avatar: credential.avatar,
          cookie: cookie,
          usedAt: DateTime.now(),
        ),
      );
    } on Object {
      // Out of remembered sign-ins, never out of the login.
    }
  }

  Future<void> _applyStored(AccountRepository repository) async {
    for (final credential in repository.list().values) {
      final auth = authOf(credential.siteId);
      if (auth == null) continue;
      try {
        await auth.applyCredential(credential);
      } on Object {
        // A credential the site now refuses (a stale cookie) stays stored;
        // the next sign-in replaces it.
      }
    }
  }

  void _refresh(AccountRepository repository) {
    state = (ready: true, credentials: repository.list(), unreadable: repository.unreadableSites());
  }
}

/// The account pane's state.
final accountsProvider = NotifierProvider<AccountsController, AccountsState>(AccountsController.new);

/// Whether [auth] opens a QR login: the capability states it, so the answer
/// costs nothing and starts no session (probing by calling `startQrLogin`
/// would build a QR session just to read whether it is allowed).
bool siteSupportsQrLogin(LiveAuthCapability auth) => auth.supportsQrLogin;

/// The site's display name (its zh-CN manifest name, else its id).
String siteDisplayName(LiveSite site) => localizedSiteName(site);

/// What a sign-in failure says to the viewer: a site error carries its
/// own words (what the paste is missing, what the poll hit).
String signInFailureText(Object error) => switch (error) {
  final LiveSiteError error => error.message,
  _ => error.toString(),
};
