import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/l10n/translations.g.dart';
import 'package:pure_live/modules/live/room/chat/room_chat_overlay.dart';
import 'package:pure_live/modules/live/room/controller/room_controller.dart'
    show RoomChat, RoomChatStatus, roomAnchorNameProvider, roomChatProvider, roomChatStandingProvider;

LiveMessage _talk(String id, String name) => LiveMessage.normalized(
  text: 'line $id',
  sender: MessageSender.of(userId: 'u-$id', userName: name),
  messageId: id,
);

/// The standing the overlay sees before anything opens: connecting, no
/// reason. The real room state drags the player settings' chain in (and
/// their idle timers with it), which is a test of the boot, not of the
/// overlay — the selectors it reads are overridden instead.
const RoomChat _stubStanding = (status: RoomChatStatus.connecting, error: null);

/// Whether a line with [needle] in its plain text is on the overlay: the
/// pills draw through `Text.rich`, so the plain-text finders need the rich
/// flag to see them.
bool hasPillWith(String needle) => find.textContaining(needle, findRichText: true).evaluate().isNotEmpty;

/// The overlay under a container of the test's own, so the lines arrive
/// through the controller the test holds, and the room state is the stub.
Future<void> show(WidgetTester tester, ProviderContainer container) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    TranslationProvider(
      child: DsScope(
        child: UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ColoredBox(color: Color(0xFF000000), child: RoomChatOverlay())),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      roomChatStandingProvider.overrideWithValue(_stubStanding),
      roomAnchorNameProvider.overrideWithValue(''),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  testWidgets('the pills carry the talk, and super chats keep their tab', (tester) async {
    final container = _container();
    container
        .read(roomChatProvider.notifier)
      ..add(_talk('a', 'Bob'))
      ..add(LiveMessage.normalized(type: LiveMessageType.superChat, text: 'paid words', messageId: 'sc'));
    await show(tester, container);

    expect(hasPillWith('Bob'), isTrue, reason: 'the sender leads the pill');
    expect(hasPillWith('line a'), isTrue);
    expect(hasPillWith('paid words'), isFalse, reason: 'super chats live in their own tab');
  });

  testWidgets('the room voice sits in a quiet capsule of its own', (tester) async {
    final container = _container();
    container
        .read(roomChatProvider.notifier)
        .add(LiveMessage.normalized(type: LiveMessageType.system, text: 'the room says hi', messageId: 'n'));
    await show(tester, container);

    // The voice draws as a plain text on its own capsule, centred — the
    // conversation's left edge stays a conversation's.
    expect(find.text('the room says hi'), findsOneWidget);
    expect(find.ancestor(of: find.text('the room says hi'), matching: find.byType(Align)), findsWidgets);
  });

  testWidgets('an empty overlay says what the socket is doing', (tester) async {
    final container = _container();
    await show(tester, container);

    // The stub's standing is `connecting`: one quiet pill, no pills of talk.
    expect(find.byType(DsSpinner), findsOneWidget);
  });

  testWidgets('the glance surface keeps only its last pills', (tester) async {
    final container = _container();
    final chat = container.read(roomChatProvider.notifier);
    for (var i = 0; i < 40; i++) {
      chat.add(_talk('c$i', 'P$i'));
    }
    await show(tester, container);

    expect(hasPillWith('P39'), isTrue, reason: 'the newest pill is on the surface');
    // The list builds lazily, so the cap shows in what the scroll's far end
    // can reach: the oldest pill the surface ever holds is the cap's floor,
    // and the feed's history stays out of it.
    for (var i = 0; i < 5; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pump();
    }
    expect(hasPillWith('P10'), isTrue, reason: 'the cap keeps the newest thirty');
    expect(hasPillWith('P0'), isFalse, reason: "the feed's history is not the overlay's");
  });

  testWidgets('reading away from the bottom holds the pills and counts arrivals', (tester) async {
    final container = _container();
    final chat = container.read(roomChatProvider.notifier);
    for (var i = 0; i < 30; i++) {
      chat.add(_talk('h$i', 'P$i'));
    }
    await show(tester, container);

    // A drag away from the bottom (the reverse list's older side) pauses the
    // chase: the next arrivals count into the jump pill instead of pulling
    // the list down. The drag goes to the scroll's far end, where the oldest
    // held pill is the one built under the eye.
    await tester.drag(find.byType(ListView), const Offset(0, 160));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pump();
    // The touch slop eats a little of each drag; the third carries the list
    // to its far end, where the oldest held pill is built under the eye.
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pump();
    chat.add(_talk('arrived', 'Late'));
    await tester.pump();

    expect(find.textContaining('条新消息'), findsOneWidget);
    expect(hasPillWith('line h0'), isTrue, reason: 'the held list keeps the old pills readable');

    // The pill's press takes the viewer back to the newest line.
    await tester.tap(find.textContaining('条新消息'));
    await tester.pump();
    expect(find.textContaining('条新消息'), findsNothing);
    expect(hasPillWith('Late'), isTrue);
  });
}
