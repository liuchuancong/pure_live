// The account vault's offline half: credentials land in a seeded secure
// store, the repository reads them back (and says so when a document is
// not a credential this app can open), douyu's renewal pair halves
// independently, and bilibili's remembered roster trims itself by least
// recent use without ever dropping the sign-in just stored.

import 'dart:convert' show jsonEncode;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart' show LiveCredential;
import 'package:live_storage/live_storage.dart' show SecretStore;

import 'package:pure_live/features/account/account_repository.dart' show AccountRepository, BilibiliAccount;
import 'package:pure_live/features/backup/webdav/webdav_settings.dart' show SecureVault;

/// Opens the repository over the app's own secure vault, seeded with [seed];
/// each call replaces the mock platform, so every test starts from an empty
/// vault. The mock writes into the map it is handed, so it gets a mutable
/// copy.
Future<AccountRepository> _open([Map<String, String> seed = const {}]) async {
  FlutterSecureStorage.setMockInitialValues(Map<String, String>.from(seed));
  final store = await SecretStore.load(vault: const SecureVault(FlutterSecureStorage()));
  return AccountRepository.forStore(store);
}

LiveCredential _credential(String siteId, {String? userId, String? nickname, Map<String, String>? cookies}) =>
    LiveCredential(siteId: siteId, cookies: cookies ?? const {'SESSDATA': 'abc'}, userId: userId, nickname: nickname);

String _rosterJson(
  int uid, {
  String name = '小明',
  String cookie = 'DedeUserID=1; SESSDATA=abc',
  DateTime? usedAt,
  Object? avatar = 'https://a/pic.jpg',
}) => jsonEncode(<String, Object?>{
  'uid': uid,
  'name': name,
  'avatar': ?avatar,
  'cookie': cookie,
  if (usedAt != null) 'usedAt': usedAt.toIso8601String(),
});

void main() {
  test('decode accepts a roster document and rejects everything else', () {
    final used = DateTime.utc(2026, 1, 2);
    final account = BilibiliAccount.decode(_rosterJson(7, usedAt: used));
    expect(account, isNotNull);
    expect(account!.uid, 7);
    expect(account.name, '小明');
    expect(account.avatar, 'https://a/pic.jpg');
    expect(account.usedAt, used);

    // A document of another shape, a bad uid or a blank cookie is not a
    // roster entry this app can open.
    for (final raw in <String?>[
      null,
      'not json',
      jsonEncode(<Object?>['a', 'list']),
      jsonEncode(<String, Object?>{'uid': 'zero', 'cookie': 'x'}),
      jsonEncode(<String, Object?>{'uid': 0, 'cookie': 'x'}),
      jsonEncode(<String, Object?>{'uid': 7}),
      jsonEncode(<String, Object?>{'uid': 7, 'cookie': '   '}),
    ]) {
      expect(BilibiliAccount.decode(raw), isNull, reason: 'raw: $raw');
    }

    // Missing extras fall back: no name is an empty one, no usedAt is the
    // epoch that sorts last.
    final bare = BilibiliAccount.decode(jsonEncode(<String, Object?>{'uid': 9, 'cookie': 'c'}));
    expect(bare, isNotNull);
    expect(bare!.name, isEmpty);
    expect(bare.avatar, isNull);
    expect(bare.usedAt, DateTime.fromMillisecondsSinceEpoch(0));
  });

  test('seeded documents read back; a broken one is reported unreadable', () async {
    final repo = await _open(<String, String>{
      'credentials/bilibili': jsonEncode(<String, Object?>{
        'siteId': 'bilibili',
        'cookies': <String, String>{'SESSDATA': 'abc'},
        'userId': '42',
        'nickname': '小明',
      }),
      // A document another program (or another app version) left there.
      'credentials/douyu': 'not a credential document',
      // The dotted sub-keys sit beside the credential, never decoded as one.
      'credentials/douyu.ltp0': 'ltp-value',
      'credentials/douyu.did': 'did-value',
      // A roster entry this app cannot open is skipped, not unreadable.
      'credentials/bilibili.account/2': 'garbage',
      'credentials/bilibili.account/1': _rosterJson(1),
    });
    final list = repo.list();
    expect(list.keys, <String>['bilibili']);
    expect(repo.get('bilibili')!.userId, '42');
    expect(repo.unreadableSites(), <String>{'douyu'});

    // The roster skips the garbage entry and keeps the good one.
    expect(repo.bilibiliAccounts().map((account) => account.uid), <int>[1]);
    // The renewal pair reads beside the unreadable cookie document.
    expect(repo.douyuLtp0(), 'ltp-value');
    expect(repo.douyuDid(), 'did-value');
  });

  test('a saved credential round-trips and a removed one is gone', () async {
    final repo = await _open();
    await repo.save(_credential('Huya', userId: 'u1', nickname: '虎牙'));
    // The ref normalizes to lower case on both sides, while the stored
    // document keeps the site id exactly as it was saved.
    expect(repo.get('huya'), isNotNull);
    expect(repo.list().keys, <String>['Huya']);
    final removed = repo.get('huya')!;
    expect(removed.nickname, '虎牙');

    await repo.remove('huya');
    expect(repo.get('huya'), isNull);
    // Removing a never-stored site is a silent no-op.
    await repo.remove('huya');
    expect(repo.list(), isEmpty);
  });

  test('douyu renewal halves clear independently', () async {
    final repo = await _open();
    await repo.saveDouyuPair(ltp0: ' ltp ', did: 'did-1');
    expect(repo.douyuLtp0(), 'ltp'); // stored trimmed
    expect(repo.douyuDid(), 'did-1');

    // A blank half clears only itself.
    await repo.saveDouyuPair(ltp0: '  ', did: 'did-2');
    expect(repo.douyuLtp0(), isNull);
    expect(repo.douyuDid(), 'did-2');

    await repo.clearDouyuPair();
    expect(repo.douyuLtp0(), isNull);
    expect(repo.douyuDid(), isNull);
  });

  test('remembering a sign-in dedupes and keeps a blank name from wiping', () async {
    final repo = await _open();
    final first = DateTime.utc(2026);
    final later = DateTime.utc(2026, 6);
    await repo.rememberBilibiliAccount(
      BilibiliAccount(uid: 7, name: '小明', cookie: 'c1', usedAt: first),
      at: first,
    );
    expect(repo.bilibiliAccount(7)!.name, '小明');

    // The same uid again: a blank name keeps the stored one, a new cookie
    // marks it used now, and the fresh login's picture replaces the old.
    await repo.rememberBilibiliAccount(
      BilibiliAccount(uid: 7, name: '  ', cookie: 'c2', avatar: 'https://b/new.jpg', usedAt: later),
      at: later,
    );
    final updated = repo.bilibiliAccount(7)!;
    expect(updated.name, '小明');
    expect(updated.cookie, 'c2');
    expect(updated.avatar, 'https://b/new.jpg');
    expect(updated.usedAt, later);

    // The very same document again writes nothing: the used stamp stays.
    await repo.rememberBilibiliAccount(
      BilibiliAccount(uid: 7, name: '小明', cookie: 'c2', usedAt: later),
      at: DateTime.utc(2027),
    );
    expect(repo.bilibiliAccount(7)!.usedAt, later);

    // A blank cookie or a bad uid stores nothing.
    await repo.rememberBilibiliAccount(BilibiliAccount(uid: 8, name: 'x', cookie: '   ', usedAt: later));
    await repo.rememberBilibiliAccount(BilibiliAccount(uid: 0, name: 'x', cookie: 'c', usedAt: later));
    expect(repo.bilibiliAccounts().single.uid, 7);
  });

  test('the roster trims past the limit, never the sign-in just stored', () async {
    final repo = await _open();
    for (var i = 1; i <= 5; i++) {
      await repo.rememberBilibiliAccount(
        BilibiliAccount(uid: i, name: 'u$i', cookie: 'c$i', usedAt: DateTime.utc(2026, 1, i)),
        at: DateTime.utc(2026, 1, i),
      );
    }
    expect(repo.bilibiliAccounts().map((account) => account.uid), <int>[5, 4, 3, 2, 1]);

    // A sixth sign-in forgets the least recently used of the others.
    await repo.rememberBilibiliAccount(
      BilibiliAccount(uid: 6, name: 'u6', cookie: 'c6', usedAt: DateTime.utc(2026, 2)),
      at: DateTime.utc(2026, 2),
    );
    expect(repo.bilibiliAccounts().map((account) => account.uid), <int>[6, 5, 4, 3, 2]);

    // Re-storing an already-remembered one never evicts itself.
    await repo.rememberBilibiliAccount(
      BilibiliAccount(uid: 2, name: 'u2', cookie: 'c2-new', usedAt: DateTime.utc(2026, 3)),
      at: DateTime.utc(2026, 3),
    );
    expect(repo.bilibiliAccount(2)!.cookie, 'c2-new');
    expect(repo.bilibiliAccounts().length, AccountRepository.bilibiliAccountLimit);
  });

  test('touching orders a sign-in as used; forgetting drops by uid and cookie', () async {
    final repo = await _open();
    for (var i = 1; i <= 3; i++) {
      await repo.rememberBilibiliAccount(
        BilibiliAccount(uid: i, name: 'u$i', cookie: 'line$i', usedAt: DateTime.utc(2026, 1, i)),
        at: DateTime.utc(2026, 1, i),
      );
    }

    // An unknown uid is a no-op; a known one rides to the top.
    await repo.touchBilibiliAccount(99);
    await repo.touchBilibiliAccount(1, at: DateTime.utc(2026, 5));
    expect(repo.bilibiliAccounts().first.uid, 1);

    // A switch-out forgets by uid; signing out forgets any copy of the
    // same cookie line.
    await repo.forgetBilibiliAccount(2);
    expect(repo.bilibiliAccount(2), isNull);
    await repo.forgetBilibiliAccountsOf(cookie: 'line3');
    expect(repo.bilibiliAccounts().map((account) => account.uid), <int>[1]);
  });
}
