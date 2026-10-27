import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:live_sites/live_sites.dart' show LiveCredential, SiteIds;
import 'package:live_storage/live_storage.dart' show SecretStore, SecretVault;

/// One sign-in the vault remembers (the reference's `SavedAccount`).
///
/// Bilibili keeps a roster of the accounts this device has signed in, so
/// switching back to one needs no new scan. Each entry is its own JSON
/// document under `credentials/bilibili.account/<uid>` — beside, and never
/// part of, the current login at `credentials/bilibili` — and it carries the
/// cookie that makes it the current login again.
final class BilibiliAccount {
  /// Creates a roster entry.
  const BilibiliAccount({
    required this.uid,
    required this.name,
    required this.cookie,
    required this.usedAt,
    this.avatar,
  });

  /// The account's id on the platform (`DedeUserID`), always positive.
  final int uid;

  /// The account's display name; empty when the platform gave none.
  final String name;

  /// The account's picture address, when the login carried one.
  final String? avatar;

  /// The cookie header line this sign-in switches back with.
  final String cookie;

  /// When this sign-in was last the current one; orders the roster.
  final DateTime usedAt;

  /// The entry as it is stored.
  Map<String, Object?> toJson() => <String, Object?>{
    'uid': uid,
    'name': name,
    if (avatar != null) 'avatar': avatar,
    'cookie': cookie,
    'usedAt': usedAt.toIso8601String(),
  };

  /// The entry [raw] holds, or null when it is not a roster document this app
  /// can open (a document of another shape, or one without an uid or a
  /// cookie). Such an entry is left out of the list and dropped by the next
  /// write of the roster.
  static BilibiliAccount? decode(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final uid = int.tryParse('${json['uid']}');
      final cookie = json['cookie'];
      if (uid == null || uid <= 0) return null;
      if (cookie is! String || cookie.trim().isEmpty) return null;
      final name = json['name'];
      final avatar = json['avatar'];
      final usedAt = json['usedAt'] is String ? DateTime.tryParse(json['usedAt'] as String) : null;
      return BilibiliAccount(
        uid: uid,
        name: name is String ? name.trim() : '',
        avatar: avatar is String && avatar.isNotEmpty ? avatar : null,
        cookie: cookie.trim(),
        usedAt: usedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    } on Object {
      return null;
    }
  }

  /// This entry with the given halves replaced; a null argument keeps the
  /// value it has.
  BilibiliAccount copyWith({String? name, String? avatar, String? cookie, DateTime? usedAt}) => BilibiliAccount(
    uid: uid,
    name: name ?? this.name,
    avatar: avatar ?? this.avatar,
    cookie: cookie ?? this.cookie,
    usedAt: usedAt ?? this.usedAt,
  );

  @override
  String toString() => 'BilibiliAccount($uid, $name, used $usedAt)';
}

/// The device's secret vault over `flutter_secure_storage` — the
/// implementation the storage package leaves to the app shell (Windows
/// DPAPI, the iOS Keychain, the Android Keystore).
final class SecureVaultAdapter implements SecretVault {
  /// The adapter; the plugin carries its own platform options.
  const SecureVaultAdapter();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();

  @override
  Future<void> write(String ref, String plain) => _storage.write(key: ref, value: plain);

  @override
  Future<void> delete(String ref) => _storage.delete(key: ref);
}

/// The viewer's platform credentials over the app's [SecretStore]: one
/// JSON document per signed-in site, never on disk in plain text. The
/// refs live under `credentials/<siteId>` — the app's vault namespace for
/// login credentials — and every read is a memory read off the store's
/// cache.
final class AccountRepository {
  AccountRepository._(this._store);

  static const String _refPrefix = 'credentials/';

  /// Douyu's renewal pair: LTP0 and the login's `dy_did`, each kept under its
  /// own ref beside the cookie document. A ref with a dot in its site portion
  /// is a sub-key, never a credential document, so the site scan below skips
  /// it and only whole-site `credentials/<siteId>` entries decode as
  /// credentials.
  static const String _douyuLtp0Ref = 'credentials/douyu.ltp0';
  static const String _douyuDidRef = 'credentials/douyu.did';

  /// Bilibili's remembered sign-ins: one JSON document per uid under this
  /// prefix, so the dotted site portion keeps them out of the credential
  /// scan exactly like douyu's renewal sub-keys. The current login stays the
  /// single `credentials/bilibili` document.
  static const String _bilibiliAccountPrefix = '$_refPrefix${SiteIds.bilibili}.account/';

  /// The secret store this repository reads and writes.
  final SecretStore _store;

  /// Opens the repository: loads every stored secret into the store's
  /// memory cache once.
  static Future<AccountRepository> open() async =>
      AccountRepository._(await SecretStore.load(vault: const SecureVaultAdapter()));

  /// Emits after every committed credential change under the
  /// repository's namespace.
  Stream<void> watch() => _store.changes.where((ref) => ref.startsWith(_refPrefix));

  /// The stored credentials, keyed by site id.
  Map<String, LiveCredential> list() {
    final credentials = <String, LiveCredential>{};
    for (final siteId in _storedSiteIds) {
      final credential = _decode(_store.value(_ref(siteId)));
      if (credential != null) credentials[credential.siteId] = credential;
    }
    return credentials;
  }

  /// The sites with a document under the repository's prefix that cannot be
  /// read back as a credential — something is stored, but this app cannot
  /// open it. The account page says so instead of calling the site signed
  /// out, and lets the viewer remove it.
  Set<String> unreadableSites() {
    final unreadable = <String>{};
    for (final siteId in _storedSiteIds) {
      if (_decode(_store.value(_ref(siteId))) == null) unreadable.add(siteId);
    }
    return unreadable;
  }

  Iterable<String> get _storedSiteIds => _store.refs
      .where((ref) => ref.startsWith(_refPrefix))
      .map((ref) => ref.substring(_refPrefix.length))
      // A dotted id is a sub-key (the douyu renewal pair), not a credential
      // document; it is never decoded and never reported unreadable.
      .where((siteId) => !siteId.contains('.'));

  /// The stored credential of [siteId], or null.
  LiveCredential? get(String siteId) => _decode(_store.value(_ref(siteId)));

  /// Stores [credential], replacing its site's previous entry.
  Future<void> save(LiveCredential credential) => _store.set(_ref(credential.siteId), jsonEncode(_encode(credential)));

  /// Drops [siteId]'s credential; a never-stored site is a no-op.
  Future<void> remove(String siteId) => _store.remove(_ref(siteId));

  /// Douyu's stored LTP0 (the renewal key kept beside the cookie), or null.
  String? douyuLtp0() => _store.value(_douyuLtp0Ref);

  /// Douyu's stored login device id (kept beside the cookie), or null.
  String? douyuDid() => _store.value(_douyuDidRef);

  /// Stores douyu's renewal pair. A null or blank value clears that ref, so
  /// clearing one half of the pair leaves the other untouched; the store's
  /// watch stream fires for whichever ref actually changed.
  Future<void> saveDouyuPair({required String? ltp0, required String? did}) async {
    await _writeRef(_douyuLtp0Ref, ltp0);
    await _writeRef(_douyuDidRef, did);
  }

  /// Drops both halves of douyu's renewal pair (the sign-out cleanup).
  Future<void> clearDouyuPair() => saveDouyuPair(ltp0: null, did: null);

  /// How many bilibili sign-ins the roster keeps. Remembering one more past
  /// this forgets the least recently used of the *others*; the sign-in just
  /// stored is never the one dropped.
  static const int bilibiliAccountLimit = 5;

  /// The bilibili sign-ins remembered on this device, most recently used
  /// first. Entries the vault holds but this app cannot open are left out.
  List<BilibiliAccount> bilibiliAccounts() {
    final accounts = <BilibiliAccount>[];
    for (final ref in _store.refs) {
      if (!ref.startsWith(_bilibiliAccountPrefix)) continue;
      final account = BilibiliAccount.decode(_store.value(ref));
      if (account != null) accounts.add(account);
    }
    accounts.sort((a, b) {
      final used = b.usedAt.compareTo(a.usedAt);
      return used != 0 ? used : a.uid.compareTo(b.uid);
    });
    return accounts;
  }

  /// The remembered bilibili sign-in with [uid], or null when the roster has
  /// none.
  BilibiliAccount? bilibiliAccount(int uid) {
    for (final account in bilibiliAccounts()) {
      if (account.uid == uid) return account;
    }
    return null;
  }

  /// Remembers [account] as a bilibili sign-in (the login itself is already
  /// stored by the caller). A known uid is updated — its name kept when the
  /// new one is blank — and only a new cookie marks it used now; nothing is
  /// written when nothing changed. A uid nobody was found for, or an empty
  /// cookie, stores nothing.
  ///
  /// Past [bilibiliAccountLimit] the least recently used of the *other*
  /// entries are forgotten, so the sign-in just stored always survives; the
  /// caller reports the eviction rather than leaving it silent.
  Future<void> rememberBilibiliAccount(BilibiliAccount account, {DateTime? at}) async {
    if (account.uid <= 0) return;
    final cookie = account.cookie.trim();
    if (cookie.isEmpty) return;
    final known = bilibiliAccount(account.uid);
    final name = account.name.trim();
    final entry = known == null
        ? BilibiliAccount(
            uid: account.uid,
            name: name,
            avatar: account.avatar,
            cookie: cookie,
            usedAt: at ?? DateTime.now(),
          )
        : known.copyWith(
            name: name.isEmpty ? null : name,
            avatar: account.avatar,
            cookie: cookie,
            usedAt: known.cookie == cookie ? null : (at ?? DateTime.now()),
          );
    if (known != null && known.name == entry.name && known.cookie == entry.cookie && known.usedAt == entry.usedAt) {
      return;
    }
    await _store.set(_bilibiliAccountRef(entry.uid), jsonEncode(entry.toJson()));
    await _trimBilibiliAccounts(keeping: entry.uid);
  }

  /// Marks the remembered bilibili sign-in [uid] as used now (a switch to it),
  /// leaving its other values alone. An unknown uid is a no-op.
  Future<void> touchBilibiliAccount(int uid, {DateTime? at}) async {
    final known = bilibiliAccount(uid);
    if (known == null) return;
    await _store.set(
      _bilibiliAccountRef(uid),
      jsonEncode(known.copyWith(usedAt: at ?? DateTime.now()).toJson()),
    );
  }

  /// Forgets the remembered bilibili sign-in [uid] (not the current login:
  /// that is the caller's sign-out).
  Future<void> forgetBilibiliAccount(int uid) => _store.remove(_bilibiliAccountRef(uid));

  /// Forgets the remembered bilibili sign-ins of the login being dropped: the
  /// entry with [uid] and any entry carrying the same [cookie]. Signing out
  /// of bilibili therefore leaves no remembered copy of itself behind.
  Future<void> forgetBilibiliAccountsOf({int? uid, String? cookie}) async {
    final line = cookie?.trim();
    for (final account in bilibiliAccounts()) {
      final sameUid = uid != null && uid > 0 && account.uid == uid;
      final sameCookie = line != null && line.isNotEmpty && account.cookie == line;
      if (sameUid || sameCookie) await _store.remove(_bilibiliAccountRef(account.uid));
    }
  }

  /// Forgets the least recently used bilibili sign-ins beyond the limit, never
  /// [keeping] (the entry just remembered).
  Future<void> _trimBilibiliAccounts({required int keeping}) async {
    final accounts = bilibiliAccounts();
    var overflow = accounts.length - bilibiliAccountLimit;
    if (overflow <= 0) return;
    for (final account in accounts.reversed) {
      if (overflow <= 0) break;
      if (account.uid == keeping) continue;
      await _store.remove(_bilibiliAccountRef(account.uid));
      overflow--;
    }
  }

  Future<void> _writeRef(String ref, String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return _store.remove(ref);
    return _store.set(ref, text);
  }

  static String _ref(String siteId) => '$_refPrefix${siteId.trim().toLowerCase()}';

  static String _bilibiliAccountRef(int uid) => '$_bilibiliAccountPrefix$uid';

  static Map<String, Object?> _encode(LiveCredential credential) => <String, Object?>{
    'siteId': credential.siteId,
    'cookies': credential.cookies,
    if (credential.userId != null) 'userId': credential.userId,
    if (credential.nickname != null) 'nickname': credential.nickname,
    if (credential.avatar != null) 'avatar': credential.avatar,
    if (credential.expiry != null) 'expiry': credential.expiry!.toIso8601String(),
  };

  static LiveCredential? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final cookies = json['cookies'];
      if (cookies is! Map) return null;
      return LiveCredential(
        siteId: json['siteId'] as String,
        cookies: {for (final entry in cookies.entries) '${entry.key}': '${entry.value}'},
        userId: json['userId'] as String?,
        nickname: json['nickname'] as String?,
        avatar: json['avatar'] as String?,
        expiry: json['expiry'] is String ? DateTime.tryParse(json['expiry'] as String) : null,
      );
    } on Object {
      // A credential the app cannot read is as good as absent; the next
      // sign-in replaces it.
      return null;
    }
  }
}
