import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/features/room/room_back_channel.dart';

/// The room's hold on Android's back, at the channel level: enabling and
/// releasing reach the activity, and the activity's back reaches the room.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('pure_live/predictive_back');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final outgoing = <MethodCall>[];

  setUp(() {
    outgoing.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      outgoing.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    RoomBackChannel.instance.reset();
  });

  test('holding the back enables it, releasing disables it', () async {
    final holder = Object();
    await RoomBackChannel.instance.hold(holder, () async {});
    expect(outgoing.single.method, 'setEnabled');
    expect(outgoing.single.arguments, {'enabled': true});
    expect(RoomBackChannel.instance.held, isTrue);

    await RoomBackChannel.instance.release(holder);
    expect(outgoing.last.method, 'setEnabled');
    expect(outgoing.last.arguments, {'enabled': false});
    expect(RoomBackChannel.instance.held, isFalse);
  });

  test('the activity’s back runs the room handler', () async {
    var backs = 0;
    await RoomBackChannel.instance.hold(Object(), () async => backs++);
    await _invokeBack();
    expect(backs, 1);
  });

  test('a page that lost the back cannot disable it', () async {
    final first = Object();
    final second = Object();
    await RoomBackChannel.instance.hold(first, () async {});
    await RoomBackChannel.instance.hold(second, () async {});
    outgoing.clear();

    await RoomBackChannel.instance.release(first);
    expect(outgoing, isEmpty);
    expect(RoomBackChannel.instance.held, isTrue);
  });
}

Future<void> _invokeBack() async {
  final completer = Completer<void>();
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    'pure_live/predictive_back',
    const StandardMethodCodec().encodeMethodCall(const MethodCall('backInvoked')),
    (_) => completer.complete(),
  );
  await completer.future;
}
