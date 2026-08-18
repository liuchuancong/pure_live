import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/modules/live_play/local_message_delivery_queue.dart';

void main() {
  LiveMessage message(String text) => LiveMessage(
    type: LiveMessageType.chat,
    userName: 'local',
    message: text,
    color: LiveMessageColor.white,
    isLocal: true,
  );

  test('delivers a local message once after its configured delay', () async {
    final delivered = <LocalMessageDelivery>[];
    final queue = LocalMessageDeliveryQueue(onDeliver: delivered.add);
    queue.schedule(
      LocalMessageDelivery(message: message('hello'), showAsDanmaku: true, roomEpoch: 3),
      delay: const Duration(milliseconds: 20),
    );

    expect(delivered, isEmpty);
    expect(queue.pendingCount, 1);
    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(delivered.single.message.message, 'hello');
    expect(delivered.single.showAsDanmaku, isTrue);
    expect(queue.pendingCount, 0);
    queue.dispose();
  });

  test('cancels delayed messages when a room is replaced', () async {
    final delivered = <LocalMessageDelivery>[];
    final queue = LocalMessageDeliveryQueue(onDeliver: delivered.add);
    queue.schedule(
      LocalMessageDelivery(message: message('stale'), showAsDanmaku: true, roomEpoch: 1),
      delay: const Duration(milliseconds: 20),
    );
    queue.cancelAll();

    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(delivered, isEmpty);
    expect(queue.pendingCount, 0);
    queue.dispose();
  });
}
