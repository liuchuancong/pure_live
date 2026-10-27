import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show DouyuAccount, DouyuLoginStore, LiveCredential;
import 'package:pure_live/features/account/account_providers.dart' show accountRepositoryProvider, accountsProvider;
import 'package:pure_live/features/account/account_repository.dart' show AccountRepository;
import 'package:pure_live/features/account/account_state.dart' show AccountSnapshot, accountCookieLine;
import 'package:pure_live/features/account/douyu_cookie_saved_at.dart' show douyuCookieSavedAtProvider;

/// The Douyu site id the store is keyed on (matches the manifest id, and so
/// the vault's `credentials/douyu` document).
const String _douyuSiteId = 'douyu';

/// Douyu's renewal data kept beside the cookie: the pair a lapsed login is
/// renewed with, and the save time that turns an opaque web token into a date.
typedef DouyuRenewal = ({String? ltp0, String? did, DateTime? savedAt});

/// The app's [DouyuLoginStore] over its secret vault and settings.
///
/// The adapter reads it to decide whether a stored login needs renewing (the
/// cookie's worth, the renewal pair and the save time) and writes a renewed
/// login back through [saveRenewed]. Every read is synchronous off the vault's
/// memory cache and the settings controller, matching the seam's contract; the
/// writes land both halves so the account page and the site see the same
/// login. The store holds the riverpod `Ref` and reads the repository lazily,
/// so a request made before the vault finishes opening is simply a guest,
/// exactly as before.
final class VaultDouyuLoginStore implements DouyuLoginStore {
  /// The store over the given `ref`'s account vault and settings.
  VaultDouyuLoginStore(this._ref);

  final Ref _ref;

  AccountRepository? get _repository => _ref.read(accountRepositoryProvider).value;

  @override
  String get cookie {
    final credential = _repository?.get(_douyuSiteId);
    return credential == null ? '' : accountCookieLine(credential);
  }

  @override
  String? get longTermKey => _repository?.douyuLtp0();

  @override
  String? get deviceId => _repository?.douyuDid();

  @override
  DateTime? get savedAt {
    final seconds = _ref.read(douyuCookieSavedAtProvider);
    return seconds > 0 ? DateTime.fromMillisecondsSinceEpoch(seconds * 1000) : null;
  }

  /// Stores [cookie] as the login (its fields, with the identity kept from
  /// what is stored) and stamps the save time; the vault's watch stream then
  /// moves the account page, and the applied credential the site carries keeps
  /// the requests on the renewed login.
  @override
  Future<void> saveRenewed(String cookie, DateTime renewedAt) async {
    final repository = _repository;
    if (repository == null) return;
    final fields = DouyuAccount.cookieFields(cookie);
    if (fields.isEmpty) return;
    final previous = repository.get(_douyuSiteId);
    final credential = LiveCredential(
      siteId: _douyuSiteId,
      cookies: fields,
      userId: previous?.userId,
      nickname: previous?.nickname,
      avatar: previous?.avatar,
      expiry: DouyuAccount.sessionExpiry(cookie, savedAt: renewedAt),
    );
    await repository.save(credential);
    await _ref.read(douyuCookieSavedAtProvider.notifier).markSaved(renewedAt);
  }
}

/// The douyu renewal seam handed to the site registry.
final douyuLoginStoreProvider = Provider<DouyuLoginStore>(VaultDouyuLoginStore.new);

/// What douyu has stored beside its cookie: the renewal pair and the save
/// time, watched so the status card moves when either half changes.
///
/// A pair write fires the vault's change stream (both refs live under
/// `credentials/`), and the account state rebuilds; the save time is its own
/// settings controller. Watching both, then reading the pair off the vault,
/// gives the page one snapshot of the whole login.
final douyuRenewalProvider = Provider<DouyuRenewal>((ref) {
  ref.watch(accountsProvider);
  final seconds = ref.watch(douyuCookieSavedAtProvider);
  final repository = ref.read(accountRepositoryProvider).value;
  return (
    ltp0: repository?.douyuLtp0(),
    did: repository?.douyuDid(),
    savedAt: seconds > 0 ? DateTime.fromMillisecondsSinceEpoch(seconds * 1000) : null,
  );
});

/// [stored] with douyu's renewal pair folded in, so the four-state judgment
/// sees the whole login (the other platforms are returned unchanged).
AccountSnapshot accountSnapshotWithDouyu(AccountSnapshot stored, DouyuRenewal renewal) => AccountSnapshot(
  credential: stored.credential,
  unreadable: stored.unreadable,
  douyuLtp0: renewal.ltp0,
  douyuDid: renewal.did,
  douyuSavedAt: renewal.savedAt,
);
