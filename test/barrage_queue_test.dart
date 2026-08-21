import 'package:flame_barrage/flame_barrage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bulk emoji registration preserves every alias with one final regex', () {
    final atlas = EmojiAtlas.instance;
    atlas.clear();
    addTearDown(atlas.clear);

    const first = EmojiInfo(id: 'one.png', asset: 'one.png', keys: ['[one]', ':one:']);
    const second = EmojiInfo(id: 'two.png', asset: 'two.png', keys: ['[two]']);
    atlas.registerAll(const [first, second]);

    expect(atlas.count, 3);
    expect(atlas.find('[one]'), same(first));
    expect(atlas.find(':one:'), same(first));
    expect(atlas.find('[two]'), same(second));
    expect(atlas.regex?.allMatches('x [one] :one: [two]').length, 3);
  });

  test('barrage render loop sleeps while idle and wakes only for work', () {
    final engine = BarrageEngine(config: const BarrageConfig(), emojiAtlas: EmojiAtlas.instance);

    expect(engine.paused, isTrue);

    engine.pushMessage(const BarrageItem(content: 'wake'));
    expect(engine.paused, isFalse);

    engine.clear();
    expect(engine.paused, isTrue);
    expect(engine.pendingMessageCount, 0);
  });

  test('barrage waiting queue drops oldest burst entries at its hard cap', () {
    final engine = BarrageEngine(config: const BarrageConfig(maxPendingCount: 2), emojiAtlas: EmojiAtlas.instance);

    engine.pushMessage(const BarrageItem(content: 'one'));
    engine.pushMessage(const BarrageItem(content: 'two'));
    engine.pushMessage(const BarrageItem(content: 'three'));

    expect(engine.pendingMessageCount, 2);
  });

  test('paused and active queues share one hard cap', () {
    final engine = BarrageEngine(config: const BarrageConfig(maxPendingCount: 2), emojiAtlas: EmojiAtlas.instance);

    engine.pushMessage(const BarrageItem(content: 'waiting'));
    engine.pause();
    engine.pushMessage(const BarrageItem(content: 'paused-one'));
    engine.pushMessage(const BarrageItem(content: 'paused-two'));

    expect(engine.pendingMessageCount, 2);
    engine.resume();
    expect(engine.pendingMessageCount, 2);
  });

  test('parser and layout caches remain bounded for unique long-running chat', () {
    final parser = RichParser(atlas: EmojiAtlas.instance, maxCacheSize: 32);
    final layout = MixedLayout(atlas: EmojiAtlas.instance, maxTextCacheSize: 32);
    const config = BarrageConfig(textCacheMaxSize: 32);

    for (var index = 0; index < 200; index++) {
      final content = 'unique barrage $index';
      final fragments = parser.parse(content);
      layout.layout(
        fragments,
        item: BarrageItem(content: content),
        config: config,
      );
    }

    expect(parser.cacheCount, 32);
    expect(layout.cacheCount, 32);
  });

  test('opacity is part of barrage picture and layout cache identity', () {
    final engine = BarrageEngine(config: const BarrageConfig(), emojiAtlas: EmojiAtlas.instance);
    const item = BarrageItem(content: 'same message');
    final opaqueKey = engine.buildCacheKey(item);
    engine.updateConfig(const BarrageConfig(opacity: 0.45));
    final translucentKey = engine.buildCacheKey(item);

    final parser = RichParser(atlas: EmojiAtlas.instance, maxCacheSize: 8);
    final layout = MixedLayout(atlas: EmojiAtlas.instance, maxTextCacheSize: 8);
    final fragments = parser.parse(item.content);
    layout.layout(fragments, item: item, config: const BarrageConfig());
    layout.layout(fragments, item: item, config: const BarrageConfig(opacity: 0.45));

    expect(translucentKey, isNot(opaqueKey));
    expect(layout.cacheCount, 2);
  });

  test('pure-text mode invalidates barrage picture and layout caches', () {
    final engine = BarrageEngine(config: const BarrageConfig(), emojiAtlas: EmojiAtlas.instance);
    const item = BarrageItem(content: 'message [emoji]');
    final emojiKey = engine.buildCacheKey(item);
    engine.updateConfig(const BarrageConfig(noEmojiMode: true));
    final textOnlyKey = engine.buildCacheKey(item);

    final layout = MixedLayout(atlas: EmojiAtlas.instance, maxTextCacheSize: 8);
    const fragments = <Fragment>[TextFragment('message')];
    layout.layout(fragments, item: item, config: const BarrageConfig());
    layout.layout(fragments, item: item, config: const BarrageConfig(noEmojiMode: true));

    expect(textOnlyKey, isNot(emojiKey));
    expect(layout.cacheCount, 2);
  });
}
