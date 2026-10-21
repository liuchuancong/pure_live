import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart' show LiveCredential;
import 'package:live_storage/live_storage.dart' show SecretRefs, SecretStore, SecretVault;
import 'package:pure_live/features/account/account_roster.dart';

final class _MapVault implements SecretVault {
  final Map<String, String> values = <String, String>{};

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String ref, String plain) async => values[ref] = plain;

  @override
  Future<void> delete(String ref) async => values.remove(ref);
}

LiveCredential _credential(int uid, {String name = ''}) => LiveCredential(
  siteId: 'bilibili',
  cookies: {'SESSDATA': 'x$uid'},
  userId: '$uid',
  nickname: name.isEmpty ? null : name,
);

void main() {
  late _MapVault vault;
  late SecretStore store;
  late AccountRoster roster;
  var tick = 0;

  setUp(() async {
    vault = _MapVault();
    store = await SecretStore.load(vault: vault);
    roster = AccountRoster(store, now: () => DateTime.fromMillisecondsSinceEpoch(1000 * ++tick));
  });

  test('a login joins the roster and the newest leads', () async {
    await roster.remember(_credential(1, name: '一号'));
    await roster.remember(_credential(2, name: '二号'));
    final accounts = roster.of('bilibili');
    expect(accounts.map((account) => account.uid), [2, 1]);
    expect(accounts.first.name, '二号');
  });

  test('a credential without a numeric uid names no entry', () async {
    await roster.remember(const LiveCredential(siteId: 'bilibili', cookies: {'a': 'b'}));
    await roster.remember(const LiveCredential(siteId: 'bilibili', cookies: {'a': 'b'}, userId: 'not-a-uid'));
    expect(roster.of('bilibili'), isEmpty);
  });

  test('beyond the limit the least recently used goes, the newest never', () async {
    for (var uid = 1; uid <= AccountRoster.limit; uid++) {
      await roster.remember(_credential(uid));
    }
    await roster.remember(_credential(99));
    final accounts = roster.of('bilibili');
    expect(accounts.length, AccountRoster.limit);
    expect(accounts.first.uid, 99);
    expect(accounts.map((account) => account.uid), isNot(contains(1)));
    expect(vault.values.containsKey(SecretRefs.account('bilibili', 1)), isFalse);
  });

  test('re-remembering an account refreshes its stamp without duplicating', () async {
    await roster.remember(_credential(7));
    await roster.remember(_credential(8));
    await roster.remember(_credential(7));
    expect(roster.of('bilibili').map((account) => account.uid), [7, 8]);
  });

  test('forget takes one entry off the device', () async {
    await roster.remember(_credential(1));
    await roster.remember(_credential(2));
    await roster.forget('bilibili', 1);
    expect(roster.of('bilibili').map((account) => account.uid), [2]);
  });

  test('a broken document is skipped, not fatal', () async {
    await roster.remember(_credential(3));
    vault.values[SecretRefs.account('bilibili', 4)] = '{not json';
    expect(roster.of('bilibili').map((account) => account.uid), [3]);
  });

  test('another site keeps its own roster', () async {
    await roster.remember(_credential(1));
    expect(roster.of('douyu'), isEmpty);
  });
}
