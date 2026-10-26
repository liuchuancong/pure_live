import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart'
    show LiveAuthCapability, LiveAuthSession, LiveCredential, LiveSite, LiveSiteError;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/account/account_repository.dart';
import 'package:pure_live/shared/shared.dart';

/// The accounts repository (one secret store, one process).
final accountRepositoryProvider = FutureProvider<AccountRepository>((ref) => AccountRepository.open());

/// What the account pane holds: whether the repository has opened yet and
/// the stored credentials keyed by site id.
typedef AccountsState = ({bool ready, Map<String, LiveCredential> credentials});

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
    return (ready: false, credentials: const {});
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
  /// stored copy leaves the secret store.
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
    await repository.remove(siteId);
    _refresh(repository);
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
    _refresh(repository);
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
    state = (ready: true, credentials: repository.list());
  }
}

/// The account pane's state.
final accountsProvider = NotifierProvider<AccountsController, AccountsState>(AccountsController.new);

/// Whether [auth] opens a QR login: the capability's contract has
/// `startQrLogin` throw `UnsupportedError` (synchronously) for a platform
/// without a QR flow, so the probe is a cheap, offline call.
bool siteSupportsQrLogin(LiveAuthCapability auth) {
  try {
    auth.startQrLogin();
    return true;
  } on Object {
    // UnsupportedError says the site has no QR flow; so does any other
    // start failure, for the flow cannot open.
    return false;
  }
}

/// The site's display name (its zh-CN manifest name, else its id).
String siteDisplayName(LiveSite site) => localizedSiteName(site);

/// What a sign-in failure says to the viewer: a site error carries its
/// own words (what the paste is missing, what the poll hit).
String signInFailureText(Object error) => switch (error) {
  final LiveSiteError error => error.message,
  _ => error.toString(),
};
