import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/live/shield/danmaku_filter_settings.dart';

/// The fuzzy filter's current over the in-memory store: the defaults, the
/// ranges the sliders promise, what lands in the store, and the two
/// predicates the room's danmaku pipeline asks — the content blocks and the
/// attribute blocks.
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

  DanmakuFilterController filter() => container.read(danmakuFilterProvider.notifier);
  DanmakuFilterRules readRules() => container.read(danmakuFilterProvider);

  test('the defaults leave every block off and the sliders mid-way', () {
    final current = readRules();
    expect(current.similarityEnabled, isFalse);
    expect(current.similarityThreshold, 85);
    expect(current.similarityCacheSeconds, 3);
    expect(current.similarityMaxCacheSize, 100);
    expect(current.blockEmoteOnly, isFalse);
    expect(current.blockLong, isFalse);
    expect(current.blockLongLength, 30);
    expect(current.douyuSuspectedAutomated, isFalse);
    expect(current.coloredOnly, isFalse);
    expect(current.minUserLevel, 0);
    expect(current.minFansLevel, 0);
  });

  test('every slider clamps to its range', () async {
    await filter().setSimilarityThreshold(30);
    expect(readRules().similarityThreshold, DanmakuFilterRange.thresholdMin);
    await filter().setSimilarityThreshold(200);
    expect(readRules().similarityThreshold, DanmakuFilterRange.thresholdMax);

    await filter().setSimilarityCacheSeconds(0);
    expect(readRules().similarityCacheSeconds, DanmakuFilterRange.cacheSecondsMin);
    await filter().setSimilarityCacheSeconds(999);
    expect(readRules().similarityCacheSeconds, DanmakuFilterRange.cacheSecondsMax);

    await filter().setSimilarityMaxCacheSize(5);
    expect(readRules().similarityMaxCacheSize, DanmakuFilterRange.maxCacheSizeMin);
    await filter().setSimilarityMaxCacheSize(5000);
    expect(readRules().similarityMaxCacheSize, DanmakuFilterRange.maxCacheSizeMax);

    await filter().setBlockLongLength(3);
    expect(readRules().blockLongLength, DanmakuFilterRange.blockLongLengthMin);
    await filter().setBlockLongLength(500);
    expect(readRules().blockLongLength, DanmakuFilterRange.blockLongLengthMax);

    // A floor's zero is "off", so negatives land there, not below it.
    await filter().setMinUserLevel(-5);
    expect(readRules().minUserLevel, 0);
    await filter().setMinUserLevel(150);
    expect(readRules().minUserLevel, DanmakuFilterRange.levelMax);
    await filter().setMinFansLevel(-1);
    expect(readRules().minFansLevel, 0);
    await filter().setMinFansLevel(60);
    expect(readRules().minFansLevel, 60);
  });

  test('the switches flip, and a move lands in the store', () async {
    await filter().setSimilarityEnabled(value: true);
    await filter().setBlockEmoteOnly(value: true);
    await filter().setBlockLong(value: true);
    await filter().setDouyuSuspectedAutomated(value: true);
    await filter().setColoredOnly(value: true);
    await filter().setMinUserLevel(10);
    await filter().setSimilarityThreshold(90);

    expect(readRules().similarityEnabled, isTrue);
    expect(readRules().blockEmoteOnly, isTrue);
    expect(readRules().blockLong, isTrue);
    expect(readRules().douyuSuspectedAutomated, isTrue);
    expect(readRules().coloredOnly, isTrue);
    expect(readRules().minUserLevel, 10);
    expect(readRules().similarityThreshold, 90);

    // Turning one back off leaves the rest as they were.
    await filter().setColoredOnly(value: false);
    expect(readRules().coloredOnly, isFalse);
    expect(readRules().blockEmoteOnly, isTrue);

    // A fresh read of the same store sees every rule.
    final next = ProviderContainer();
    addTearDown(next.dispose);
    final stored = next.read(danmakuFilterProvider);
    expect(stored.similarityEnabled, isTrue);
    expect(stored.similarityThreshold, 90);
    expect(stored.blockEmoteOnly, isTrue);
    expect(stored.blockLong, isTrue);
    expect(stored.douyuSuspectedAutomated, isTrue);
    expect(stored.coloredOnly, isFalse);
    expect(stored.minUserLevel, 10);
  });

  test('a stored value outside the range reads clamped', () async {
    // A value a hand edit or an older build left behind.
    await StoragePrefs.setInt('danmaku.filter.similarityThreshold', 5);
    await StoragePrefs.setInt('danmaku.filter.blockLongLength', 999);
    final next = ProviderContainer();
    addTearDown(next.dispose);
    final stored = next.read(danmakuFilterProvider);
    expect(stored.similarityThreshold, DanmakuFilterRange.thresholdMin);
    expect(stored.blockLongLength, DanmakuFilterRange.blockLongLengthMax);
  });

  LiveMessage line(String text, {MessageSender? sender, LiveMessageColor? color, bool isLocal = false}) =>
      LiveMessage.normalized(text: text, sender: sender, color: color, messageId: 'm', isLocal: isLocal);

  group('the content blocks', () {
    test('with everything off nothing is blocked', () {
      expect(danmakuShapeBlockedByRules(line('[笑哭]'), readRules()), isFalse);
      expect(danmakuShapeBlockedByRules(line('a' * 200), readRules()), isFalse);
    });

    test('a face-only line hides, a mixed one passes', () async {
      await filter().setBlockEmoteOnly(value: true);
      final current = readRules();
      // A site that names its emoticons: the message carries them.
      final named = LiveMessage.normalized(
        text: '[笑哭][笑哭]',
        emotes: [LiveEmote.of(code: '[笑哭]', url: 'u')],
        messageId: 'm',
      );
      expect(danmakuShapeBlockedByRules(named, current), isTrue);
      // Unicode faces, spaces between them at most.
      expect(danmakuShapeBlockedByRules(line('😀 😀'), current), isTrue);
      // Words beside the face keep the line.
      expect(danmakuShapeBlockedByRules(line('哈哈[笑哭]'), current), isFalse);
    });

    test('the length block takes the configured bound', () async {
      await filter().setBlockLong(value: true);
      // 30 passes, 31 hides: the bound is "longer than".
      expect(danmakuShapeBlockedByRules(line('a' * 30), readRules()), isFalse);
      expect(danmakuShapeBlockedByRules(line('a' * 31), readRules()), isTrue);
    });

    test('a line the viewer sent is never blocked', () async {
      await filter().setBlockEmoteOnly(value: true);
      await filter().setBlockLong(value: true);
      final current = readRules();
      expect(danmakuShapeBlockedByRules(line('😀', isLocal: true), current), isFalse);
      expect(danmakuShapeBlockedByRules(line('a' * 500, isLocal: true), current), isFalse);
    });
  });

  group('the attribute blocks', () {
    test('colour-only hides the grey lines, white among them', () async {
      await filter().setColoredOnly(value: true);
      final current = readRules();
      // The platform gave no colour: the line reads white, and white is
      // grey with its channels equal.
      expect(danmakuAttributesBlockedByRules(line('hello'), current), isTrue);
      expect(
        danmakuAttributesBlockedByRules(line('hello', color: const LiveMessageColor(120, 120, 120)), current),
        isTrue,
      );
      expect(
        danmakuAttributesBlockedByRules(line('hello', color: const LiveMessageColor(255, 80, 80)), current),
        isFalse,
      );
      expect(danmakuAttributesBlockedByRules(line('hello', isLocal: true), current), isFalse);
    });

    test('a level floor hides the senders under it and no one else', () async {
      await filter().setMinUserLevel(5);
      await filter().setMinFansLevel(3);
      final current = readRules();
      MessageSender sender({String? level, String fans = ''}) =>
          MessageSender.of(userId: 'u', userName: 'n', userLevel: level, fanBadgeLevel: fans);

      expect(danmakuAttributesBlockedByRules(line('hi', sender: sender(level: '3')), current), isTrue);
      expect(danmakuAttributesBlockedByRules(line('hi', sender: sender(level: '5')), current), isFalse);
      expect(danmakuAttributesBlockedByRules(line('hi', sender: sender(level: '99')), current), isFalse);
      // No badge, or a badge the platform did not number: unknown is no
      // opinion, not zero.
      expect(danmakuAttributesBlockedByRules(line('hi', sender: sender(level: '9')), current), isFalse);
      expect(
        danmakuAttributesBlockedByRules(
          line(
            'hi',
            sender: sender(level: '9', fans: '青铜'),
          ),
          current,
        ),
        isFalse,
      );
      expect(
        danmakuAttributesBlockedByRules(
          line(
            'hi',
            sender: sender(level: '9', fans: '2'),
          ),
          current,
        ),
        isTrue,
      );
      // The floor zero is off; a senderless line has nothing to read.
      await filter().setMinUserLevel(0);
      await filter().setMinFansLevel(0);
      expect(danmakuAttributesBlockedByRules(line('hi', sender: sender(level: '1')), readRules()), isFalse);
      expect(danmakuAttributesBlockedByRules(line('hi'), readRules()), isFalse);
    });
  });
}
