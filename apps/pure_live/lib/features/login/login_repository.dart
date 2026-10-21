import 'dart:convert';

import 'package:live_sites/live_sites.dart' show LiveCredential;
import 'package:live_storage/live_storage.dart' show SecretRefs, SecretStore, SecretVault;

import 'package:pure_live/app/services/secure_vault.dart';

/// A signed-in platform account's persistence: the credential a login
/// granted, stored as one JSON document under the site's cookie ref
/// ([SecretRefs.cookie]) of the app's [SecretStore] (device-encrypted, never
/// plain on disk).
///
/// `LiveAuthCapability` keeps its credential in memory only — carrying the
/// values between a login (the bilibili QR exchange, a pasted douyu/huya
/// cookie) and `applyCredential` is all it does — so this repository is the
/// application's half of the contract: [save] after a successful login,
/// [load] when the account state initialises (the site's requests only carry
/// the cookies once the loaded credential is applied back), [clear] on
/// sign-out. One repository per site.
final class LoginRepository {
  /// The repository of [siteId]'s platform (`bilibili`, `douyu`, `huya`).
  /// [vaultOf] is injectable so a test (or a later sync feature) can hand
  /// the repository an in-memory vault without touching the platform.
  new({required this.siteId, SecretVault Function()? vaultOf}) : _vaultOf = vaultOf ?? SecureVault.new;

  /// The platform whose credential this repository stores.
  final String siteId;

  final SecretVault Function() _vaultOf;

  Future<SecretStore>? _store;

  /// The loaded store, waiting for a load still in flight so a login that
  /// lands before the first read never writes past it.
  Future<SecretStore> _ready() => _store ??= SecretStore.load(vault: _vaultOf());

  /// The stored credential, null while signed out. A document that cannot be
  /// read back is removed rather than kept — a broken credential would fail
  /// every start-up apply after it.
  Future<LiveCredential?> load() async {
    final store = await _ready();
    final raw = store.value(SecretRefs.cookie(siteId));
    if (raw == null) {
      return null;
    }
    final credential = _decode(jsonDecode(raw));
    if (credential == null) {
      await store.remove(SecretRefs.cookie(siteId));
    }
    return credential;
  }

  /// Stores [credential], replacing any previous one.
  Future<void> save(LiveCredential credential) async {
    final store = await _ready();
    await store.set(SecretRefs.cookie(siteId), jsonEncode(_encode(credential)));
  }

  /// Removes the stored credential; a no-op while signed out.
  Future<void> clear() async {
    final store = await _ready();
    await store.remove(SecretRefs.cookie(siteId));
  }

  /// The stored document as it stands, for a device-sync export; null while
  /// signed out.
  Future<String?> exportDocument() async {
    final store = await _ready();
    return store.value(SecretRefs.cookie(siteId));
  }

  /// Stores [document] (one [save] wrote, from any device) as this site's
  /// credential when it decodes, and answers the parsed credential; an
  /// unreadable document changes nothing and answers null.
  Future<LiveCredential?> saveDocument(String document) async {
    final credential = decodeDocument(document);
    if (credential == null) {
      return null;
    }
    final store = await _ready();
    await store.set(SecretRefs.cookie(siteId), document);
    return credential;
  }

  /// Reads [document] back into a credential without storing it — the shape
  /// [load] checks; null when the text is no credential document at all.
  LiveCredential? decodeDocument(String document) {
    try {
      return _decode(jsonDecode(document));
    } on FormatException {
      return null;
    }
  }

  /// The document [save] would write for [credential], without writing it —
  /// what a device-sync export sends for a roster entry.
  String encodeDocument(LiveCredential credential) => jsonEncode(_encode(credential));

  Map<String, Object?> _encode(LiveCredential credential) => <String, Object?>{
    'siteId': credential.siteId,
    'cookies': credential.cookies,
    'userId': credential.userId,
    'nickname': credential.nickname,
    'avatar': credential.avatar,
    if (credential.expiry != null) 'expiry': credential.expiry!.toIso8601String(),
  };

  /// Reads the credential back out of [document], null when the shape is not
  /// the one [save] wrote — every field is checked rather than cast, so a
  /// truncated or hand-edited document answers null instead of throwing.
  LiveCredential? _decode(Object? document) {
    if (document is! Map) {
      return null;
    }
    final siteId = document['siteId'];
    final cookies = document['cookies'];
    if (siteId is! String || siteId.isEmpty || cookies is! Map) {
      return null;
    }
    final expiry = document['expiry'];
    return LiveCredential(
      siteId: siteId,
      cookies: <String, String>{for (final entry in cookies.entries) '${entry.key}': '${entry.value}'},
      userId: document['userId'] is String ? document['userId']! as String : null,
      nickname: document['nickname'] is String ? document['nickname']! as String : null,
      avatar: document['avatar'] is String ? document['avatar']! as String : null,
      expiry: expiry is String ? DateTime.tryParse(expiry) : null,
    );
  }
}
