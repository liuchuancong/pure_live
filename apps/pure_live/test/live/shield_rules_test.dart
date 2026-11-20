import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/live/shield/shield_repository.dart';

/// The shield's rule set over the in-memory store: what an add accepts, the
/// ceiling, the replace and the clear, what the store keeps, and how the
/// rules read as the block list the pipeline and the recorder ask.
void main() {
  late StorageStores stores;
  late ProviderContainer container;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  tearDown(() => stores.close());

  ShieldRulesController shield() => container.read(shieldRulesProvider.notifier);
  ShieldRules rules() => container.read(shieldRulesProvider);

  test('an add trims, refuses the empty and the duplicate, and keeps order', () async {
    expect(await shield().addKeyword('  广告  '), isTrue);
    expect(await shield().addKeyword('广告'), isFalse); // the duplicate, trimmed
    expect(await shield().addKeyword('   '), isFalse); // the empty
    expect(rules().keywords, ['广告']);

    expect(await shield().addUser(' 主播 '), isTrue);
    expect(await shield().addUser('主播'), isFalse);
    expect(rules().users, ['主播']);

    await shield().addKeyword('代练');
    expect(rules().keywords, ['广告', '代练']); // insertion order
  });

  test('a remove drops one, an absent one is nothing, a clear empties', () async {
    await shield().addKeyword('a');
    await shield().addKeyword('b');
    await shield().addUser('x');

    await shield().removeKeyword('a');
    expect(rules().keywords, ['b']);
    await shield().removeKeyword('gone');
    expect(rules().keywords, ['b']);

    await shield().removeUser('x');
    expect(rules().users, isEmpty);
    await shield().removeUser('nobody');
    expect(rules().users, isEmpty);

    await shield().clearKeywords();
    expect(rules().keywords, isEmpty);
    // A clear on an empty list writes nothing and answers the same.
    await shield().clearKeywords();
    expect(rules().keywords, isEmpty);
  });

  test('the list editor replaces wholesale, and the ceiling holds at five thousand', () async {
    final full = [for (var i = 0; i < kShieldBlockLimit; i++) 'word $i'];
    await shield().setKeywords(full);
    expect(rules().keywords.length, kShieldBlockLimit);
    expect(shield().keywordsHaveRoom, isFalse);
    expect(shield().usersHaveRoom, isTrue);

    // The one-by-one path honours the same ceiling.
    expect(await shield().addKeyword('one more'), isFalse);
    expect(rules().keywords.length, kShieldBlockLimit);

    // A pasted list longer than the ceiling takes its first five thousand.
    await shield().setKeywords([for (var i = 0; i < kShieldBlockLimit + 20; i++) 'w$i']);
    expect(rules().keywords.length, kShieldBlockLimit);
    expect(rules().keywords.first, 'w0');

    await shield().setKeywords(['kept']);
    expect(rules().keywords, ['kept']);
    expect(shield().keywordsHaveRoom, isTrue);
  });

  test('the switch flips, and every rule lands in the store', () async {
    expect(rules().enabled, isTrue); // the default is on

    await shield().setEnabled(value: false);
    expect(rules().enabled, isFalse);
    await shield().addKeyword('广告');
    await shield().addUser('主播');

    // The store holds what the state holds.
    expect(StoragePrefs.getBool('danmaku.block.enabled'), isFalse);
    expect(StoragePrefs.getStringList('danmaku.block.keywords'), ['广告']);
    expect(StoragePrefs.getStringList('danmaku.block.users'), ['主播']);

    // A fresh read of the same store sees the same rules.
    final next = ProviderContainer();
    addTearDown(next.dispose);
    final stored = next.read(shieldRulesProvider);
    expect(stored.enabled, isFalse);
    expect(stored.keywords, ['广告']);
    expect(stored.users, ['主播']);
  });

  test('the rules read as the block list: users, words, patterns, masks', () async {
    await shield().addUser('Spammer');
    await shield().addKeyword('代练');
    await shield().addKeyword('VX'); // a word whose own letters carry case
    await shield().addKeyword('/广告[0-9]+/');
    await shield().addUser('观***'); // a masked name: stored, but blocks nobody

    final list = DanmakuBlockList.of(users: rules().users, keywords: rules().keywords);
    expect(list.isEmpty, isFalse);

    LiveMessage line(String text, {String userName = ''}) => LiveMessage.normalized(
      text: text,
      sender: MessageSender.of(userId: 'u', userName: userName),
      messageId: 'm',
    );

    // The user hit is case-blind; a word is a substring, case-blind too.
    expect(list.blocks(line('hello', userName: 'spammer')), isTrue);
    expect(list.blocks(line('来代练吗')), isTrue);
    expect(list.blocks(line('加vx啦')), isTrue); // the word's own case is blind
    expect(list.blocks(line('广告1234')), isTrue); // the pattern's match
    expect(list.blocks(line('正常聊天')), isFalse);
    expect(list.blocks(line('广告')), isFalse); // without a digit the pattern is not a match

    // The masked name stands for several viewers, so it blocks nobody —
    // not even a viewer whose name carries the same prefix.
    expect(list.blocks(line('hi', userName: '观***')), isFalse);
    expect(list.blocks(line('hi', userName: '观abc')), isFalse);
  });

  test('an empty rule set reads as an empty block list', () async {
    final list = DanmakuBlockList.of(users: rules().users, keywords: rules().keywords);
    expect(list.isEmpty, isTrue);
    expect(list.blocks(LiveMessage.normalized(text: 'anything', messageId: 'm')), isFalse);
  });
}
