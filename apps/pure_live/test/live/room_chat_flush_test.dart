import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/modules/live/room/controller/room_controller.dart'
    show roomChatProvider;

LiveMessage _chat(String id) => LiveMessage.normalized(
  text: 'line $id',
  sender: MessageSender.of(userId: 'u-$id', userName: id),
  messageId: id,
);

// The frame scheduling needs a binding, so these run only here: a plain
// `test()` shares the process with no binding and hears of every change at
// once (the room shield count's own seam).
void main() {
  testWidgets('a burst lands as one change, at the next frame', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final chat = container.read(roomChatProvider.notifier);
    final lengths = <int>[];
    container.listen(roomChatProvider, (_, next) => lengths.add(next.length));

    chat
      ..add(_chat('a'))
      ..add(_chat('b'))
      ..add(_chat('c'));

    expect(container.read(roomChatProvider), isEmpty);
    await tester.pump();
    expect(container.read(roomChatProvider).length, 3);
    expect(lengths, [3]);
  });

  testWidgets('flush tells the listeners now instead of at the next frame', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(roomChatProvider.notifier)
      ..add(_chat('a'))
      ..flush();
    expect(container.read(roomChatProvider).length, 1);
    await tester.pump();
  });
}
