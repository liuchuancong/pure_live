import 'package:flame_barrage/flame_barrage.dart';
import 'package:flutter/material.dart';
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

  test('barrage keeps the display ticker asleep while detached', () {
    final engine = BarrageEngine(config: const BarrageConfig(), emojiAtlas: EmojiAtlas.instance);

    expect(engine.paused, isTrue);

    engine.pushMessage(const BarrageItem(content: 'wake'));
    expect(engine.paused, isTrue);
    expect(engine.pendingMessageCount, 1);

    engine.clear();
    expect(engine.paused, isTrue);
    expect(engine.pendingMessageCount, 0);
  });

  testWidgets('barrage paints at configured fps and stops its pulse when cleared', (tester) async {
    final controller = BarrageController();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 200,
          child: FlameBarrageWidget(
            config: const BarrageConfig(fps: 30),
            emojiAtlas: EmojiAtlas.instance,
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pump();
    final engine = controller.engine as BarrageEngine;
    addTearDown(engine.clear);

    controller.send(const BarrageItem(content: 'paced'));
    expect(engine.framePulseActive, isTrue);
    final before = engine.frameStepCount;
    for (var frame = 0; frame < 31; frame++) {
      await tester.pump(const Duration(microseconds: 16667));
    }
    final frames = engine.frameStepCount - before;

    // The vsync ticker receives about 60 opportunities per second but the
    // accumulator keeps a 30 FPS renderer near 15 steps in half a second.
    expect(frames, inInclusiveRange(14, 16));

    engine.clear();
    expect(engine.framePulseActive, isFalse);
    expect(engine.paused, isTrue);
  });

  test('barrage waiting queue drops oldest burst entries at its hard cap', () {
    final engine = BarrageEngine(
      config: const BarrageConfig(maxPendingCount: 2),
      emojiAtlas: EmojiAtlas.instance,
    );

    engine.pushMessage(const BarrageItem(content: 'one'));
    engine.pushMessage(const BarrageItem(content: 'two'));
    engine.pushMessage(const BarrageItem(content: 'three'));

    expect(engine.pendingMessageCount, 2);
  });

  test('paused and active queues share one hard cap', () {
    final engine = BarrageEngine(
      config: const BarrageConfig(maxPendingCount: 2),
      emojiAtlas: EmojiAtlas.instance,
    );

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

  test('layout cache disposes native paragraphs after eviction and clear', () {
    final parser = RichParser(atlas: EmojiAtlas.instance, maxCacheSize: 2);
    final layout = MixedLayout(atlas: EmojiAtlas.instance, maxTextCacheSize: 1);
    const config = BarrageConfig(textCacheMaxSize: 1);

    final first = layout.layout(
      parser.parse('first native paragraph'),
      item: const BarrageItem(content: 'first native paragraph'),
      config: config,
    );
    final firstParagraph = (first.spans.single as TextLayoutSpan).paragraph;
    expect(firstParagraph.debugDisposed, isFalse);

    final second = layout.layout(
      parser.parse('second native paragraph'),
      item: const BarrageItem(content: 'second native paragraph'),
      config: config,
    );
    final secondParagraph = (second.spans.single as TextLayoutSpan).paragraph;
    expect(firstParagraph.debugDisposed, isTrue);
    expect(secondParagraph.debugDisposed, isFalse);

    layout.clearCache();
    expect(secondParagraph.debugDisposed, isTrue);
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

  test('low-opacity barrage keeps a monotonic contrast-preserving outline', () {
    expect(resolveBarrageStrokeOpacity(-1), 0);
    expect(resolveBarrageStrokeOpacity(0), 0);
    expect(resolveBarrageStrokeOpacity(0.25), closeTo(0.5, 0.0001));
    expect(resolveBarrageStrokeOpacity(0.5), greaterThan(0.5));
    expect(resolveBarrageStrokeOpacity(1), 1);
    expect(resolveBarrageStrokeOpacity(2), 1);
  });

  test('per-item typography, shadow and duration have distinct picture keys', () {
    final engine = BarrageEngine(config: const BarrageConfig(), emojiAtlas: EmojiAtlas.instance);
    const base = BarrageItem(content: 'personalized');
    final baseKey = engine.buildCacheKey(base);

    const personalized = BarrageItem(
      content: 'personalized',
      type: BarrageType.bottomFixed,
      fontStyle: FontStyle.italic,
      letterSpacing: 1.2,
      opacity: .72,
      showShadow: true,
      shadowColor: Colors.cyan,
      shadowBlur: 3,
      shadowOffset: Offset(1, 1),
      fixedDuration: Duration(seconds: 6),
    );

    expect(engine.buildCacheKey(personalized), isNot(baseKey));
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
