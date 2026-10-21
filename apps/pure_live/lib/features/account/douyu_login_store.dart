import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show DouyuAccount, DouyuLoginStore, LiveCredential;
import 'package:live_storage/live_storage.dart' show SecretRefs, SecretStore, SecretVault;
import 'package:pure_live/system/security/secure_vault.dart';

/// The app's half of the douyu renewal seam: what the adapter reads beside
/// the cookie (LTP0, the login's `dy_did`, the saved-at clock) and where a
/// renewed cookie goes — the same secret vault the login repository stores
/// the signed-in credential in.
///
/// The getters answer from a snapshot taken at [load] and kept current by
/// the writes below (the adapter's interface is synchronous). A vault this
/// process cannot open answers as a guest: empty cookie, nothing stored —
/// which is exactly what the adapter does with a null store.
final class AppDouyuLoginStore implements DouyuLoginStore {
  // The unnamed-constructor shorthand cannot spell a private-named
  // constructor; the named one stays spelled with the type name.
  // ignore: unnecessary_type_name_in_constructor
  AppDouyuLoginStore._(this._store);

  final SecretStore _store;
  String _cookie = '';
  String? _ltp0;
  String? _did;
  DateTime? _savedAt;

  /// Opens the vault and reads the renewal pair, the saved-at clock and the
  /// stored douyu credential's cookie into the snapshot. [vault] is
  /// injectable so a test can hand an in-memory vault, as the login
  /// repository's does.
  static Future<AppDouyuLoginStore> load({SecretVault Function()? vault}) async {
    final store = await SecretStore.load(vault: (vault ?? SecureVault.new)());
    return AppDouyuLoginStore._(store).._reload();
  }

  void _reload() {
    _ltp0 = _nonEmpty(_store.value(SecretRefs.douyuLtp0));
    _did = _nonEmpty(_store.value(SecretRefs.douyuDid));
    final stamp = int.tryParse(_store.value(SecretRefs.douyuSavedAt) ?? '');
    _savedAt = stamp == null ? null : DateTime.fromMillisecondsSinceEpoch(stamp);
    final raw = _store.value(SecretRefs.cookie('douyu'));
    if (raw == null) {
      _cookie = '';
      return;
    }
    final credential = _credentialOf(raw);
    _cookie = credential == null
        ? ''
        : credential.cookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// The stored credential document (the login repository's JSON shape),
  /// null when it is missing or unreadable.
  static LiveCredential? _credentialOf(String raw) {
    try {
      final document = jsonDecode(raw);
      if (document is! Map) {
        return null;
      }
      final cookies = document['cookies'];
      if (cookies is! Map) {
        return null;
      }
      return LiveCredential(
        siteId: 'douyu',
        cookies: <String, String>{for (final entry in cookies.entries) '${entry.key}': '${entry.value}'},
        userId: document['userId'] is String ? document['userId']! as String : null,
        nickname: document['nickname'] is String ? document['nickname']! as String : null,
        avatar: document['avatar'] is String ? document['avatar']! as String : null,
        expiry: document['expiry'] is String ? DateTime.tryParse(document['expiry']! as String) : null,
      );
    } on Object {
      return null;
    }
  }

  @override
  String get cookie => _cookie;

  @override
  String? get longTermKey => _ltp0;

  @override
  String? get deviceId => _did;

  @override
  DateTime? get savedAt => _savedAt;

  /// Stores the renewed [cookie] as the credential document (identity kept
  /// from the previous one, expiry read from the token) and stamps [renewedAt].
  @override
  Future<void> saveRenewed(String cookie, DateTime renewedAt) async {
    final fields = DouyuAccount.cookieFields(cookie);
    if (fields.isEmpty) {
      return;
    }
    final previous = _credentialOf(_store.value(SecretRefs.cookie('douyu')) ?? '');
    final credential = LiveCredential(
      siteId: 'douyu',
      cookies: fields,
      userId: previous?.userId,
      nickname: previous?.nickname,
      avatar: previous?.avatar,
      expiry: DouyuAccount.sessionExpiry(cookie, savedAt: renewedAt),
    );
    await _store.set(SecretRefs.cookie('douyu'), jsonEncode(_documentOf(credential)));
    await _store.set(SecretRefs.douyuSavedAt, renewedAt.millisecondsSinceEpoch.toString());
    _cookie = fields.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
    _savedAt = renewedAt;
  }

  /// The cookie page's LTP0 / `dy_did` pair; an empty [ltp0] or [did] clears
  /// the stored value (the reference's fields can be taken back out).
  Future<void> saveRenewalPair({required String ltp0, required String did}) async {
    final key = _nonEmpty(ltp0);
    final device = _nonEmpty(did);
    if (key == null) {
      await _store.remove(SecretRefs.douyuLtp0);
    } else {
      await _store.set(SecretRefs.douyuLtp0, key);
    }
    if (device == null) {
      await _store.remove(SecretRefs.douyuDid);
    } else {
      await _store.set(SecretRefs.douyuDid, device);
    }
    _ltp0 = key;
    _did = device;
  }

  /// Stamps the cookie page's save: the saved-at clock the renewal window is
  /// measured from.
  Future<void> markSavedAt(DateTime at) async {
    await _store.set(SecretRefs.douyuSavedAt, at.millisecondsSinceEpoch.toString());
    _savedAt = at;
  }

  static Map<String, Object?> _documentOf(LiveCredential credential) => <String, Object?>{
    'siteId': credential.siteId,
    'cookies': credential.cookies,
    'userId': credential.userId,
    'nickname': credential.nickname,
    'avatar': credential.avatar,
    if (credential.expiry != null) 'expiry': credential.expiry!.toIso8601String(),
  };
}

/// The process's douyu renewal store, overridden at start-up with the one
/// the site registry was built over (null in a headless test run, which
/// keeps douyu a guest exactly as the un-overridden adapter is).
final douyuLoginStoreProvider = Provider<AppDouyuLoginStore?>((ref) => null);
