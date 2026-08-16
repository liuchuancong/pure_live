import 'package:flame_barrage/flame_barrage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
