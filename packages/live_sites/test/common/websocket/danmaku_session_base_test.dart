import 'dart:async';

import 'package:live_sites/src/common/websocket/danmaku_session_base.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:test/test.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// A timer the session can arm and cancel while the test keeps its callback.
final class _Armed implements Timer {
  _Armed(this._gone);

  final void Function() _gone;
  var _cancelled = false;

  @override
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _gone();
  }

  @override
  bool get isActive => !_cancelled;

  @override
  int get tick => 0;
}

/// The timers a session armed, kept so the waits can be fired by hand.
final class _Clock {
  final _after = <({Duration delay, void Function() fire})>[];

  DanmakuTimers get timers => (
    after: (delay, callback) {
      final record = (delay: delay, fire: callback);
      _after.add(record);
      return _Armed(() => _after.remove(record));
    },
    every: (period, callback) => _Armed(() {}),
  );

  /// The timers currently armed.
  int get armedCount => _after.length;

  /// Fires every timer armed, oldest first.
  void fireAll() {
    while (_after.isNotEmpty) {
      _after.removeAt(0).fire();
    }
  }
}

/// The platform under test: it opens nothing and counts the releases.
final class _Session extends DanmakuSessionBase {
  _Session({super.timers});

  /// How often the transport was released, in order.
  final releases = <String>[];

  @override
  Future<void> connect() async {}

  @override
  Future<void> stop() async {
    releases.add('stop');
  }
}

/// A chat message with [text] and a sender named [name], wearing [badge].
LiveMessage _chat(String text, {String? name, String? badge}) => LiveMessage.normalized(
  text: text,
  sender: name == null
      ? null
      : MessageSender((builder) {
        builder.userName = name;
        if (badge != null) builder.fanBadgeName = badge;
      }),
);

/// Collects the events and states a session reports, in order.
Future<(List<LiveMessage>, List<DanmakuStateEvent>)> _collect(DanmakuSessionBase session) async {
  final messages = <LiveMessage>[];
  final states = <DanmakuStateEvent>[];
  session.events.listen(messages.add);
  session.states.listen(states.add);
  return (messages, states);
}

Future<void> _settle() async {
  for (var turn = 0; turn < 6; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('the run token dies with its generation', () {
    test('a new beginRun silences the previous attempt for good', () async {
      final session = _Session();
      final (messages, states) = await _collect(session);

      final first = session.beginRun();
      final second = session.beginRun()
        ..message(_chat('live'));
      first
        ..message(_chat('old'))
        ..joined()
        ..exhausted('old budget');

      expect(first.isActive, isFalse, reason: 'the second attempt replaced it');
      expect(second.isActive, isTrue);
      await _settle();
      expect(messages.map((message) => message.text), ['live']);
      expect(states, [const DanmakuConnecting(), const DanmakuConnecting()]);
    });

    test('endRun silences the attempt; the next beginRun starts over', () async {
      final session = _Session();
      final (messages, _) = await _collect(session);

      final run = session.beginRun();
      session.endRun();
      expect(run.isActive, isFalse);
      expect(session.run, isNull);

      final again = session.beginRun()
        ..message(_chat('live'));
      run.message(_chat('late'));
      await _settle();
      expect(again.isActive, isTrue);
      expect(messages.map((message) => message.text), ['live']);
    });

    test('a disposed session reports nothing, whatever a run still holds', () async {
      final session = _Session();
      final (messages, states) = await _collect(session);

      final run = session.beginRun();
      await session.dispose();
      expect(run.isActive, isFalse);
      run
        ..message(_chat('late'))
        ..joined();

      await _settle();
      expect(messages, isEmpty);
      expect(states, [const DanmakuConnecting()]);
      expect(session.isDisposed, isTrue);
    });

    test('disconnect stops the attempt and leaves the session reusable', () async {
      final session = _Session();
      await _collect(session);

      final run = session.beginRun();
      await session.disconnect();
      expect(run.isActive, isFalse);
      expect(session.releases, ['stop']);

      final again = session.beginRun();
      expect(again.isActive, isTrue, reason: 'the session connects again after a disconnect');
    });

    test('a delay ends when the attempt is replaced, and its timer is dropped', () async {
      final clock = _Clock();
      final session = _Session(timers: clock.timers);
      final run = session.beginRun();

      final waited = run.delay(const Duration(seconds: 5));
      expect(clock.armedCount, 1);
      session.beginRun();
      expect(await waited, isFalse);
      expect(clock.armedCount, 0, reason: 'the wait of a dead attempt is not kept armed');
    });

    test('a delay outlives its wait while the attempt is active', () async {
      final clock = _Clock();
      final session = _Session(timers: clock.timers);
      final run = session.beginRun();

      final waited = run.delay(const Duration(seconds: 5));
      clock.fireAll();
      expect(await waited, isTrue);
      expect(clock.armedCount, 0);
    });
  });

  group('the sealed state events', () {
    test('an attempt reports connecting, handshake, joined in order', () async {
      final session = _Session();
      final (_, states) = await _collect(session);

      session.beginRun()
        ..handshakeDone()
        ..joined();

      expect(states, [const DanmakuConnecting(), const DanmakuHandshakeDone(), const DanmakuJoined()]);
      expect(session.run?.isJoined, isTrue);
    });

    test('a lost join is told reconnecting; a failure before it is not', () async {
      final session = _Session();
      final (_, states) = await _collect(session);

      final run = session.beginRun()
        ..reconnecting('socket closed');
      expect(states, [const DanmakuConnecting()], reason: 'an attempt that never joined is still connecting');

      run
        ..joined()
        ..reconnecting('socket silent');
      expect(states.last, const DanmakuReconnecting('socket silent'));
    });

    test('the budget end is told exhausted, with its reason', () async {
      final session = _Session();
      final (_, states) = await _collect(session);

      session.beginRun()
        ..exhausted('gave up after 4 attempts')
        ..exhausted('gave up after 4 attempts');

      expect(states, [const DanmakuConnecting(), const DanmakuExhausted('gave up after 4 attempts')]);
    });

    test('dispose closes both streams after the pending messages flushed', () async {
      final session = _Session();
      final (messages, states) = await _collect(session);
      final messagesDone = Completer<void>();
      final statesDone = Completer<void>();
      session.events.listen((_) {}, onDone: messagesDone.complete);
      session.states.listen((_) {}, onDone: statesDone.complete);

      session.beginRun().message(_chat('last words'));
      await session.dispose();
      await Future.wait([messagesDone.future, statesDone.future]);

      expect(messages.map((message) => message.text), ['last words']);
      expect(states, [const DanmakuConnecting()]);
      expect(session.isDisposed, isTrue);

      await session.dispose();
      expect(session.releases, ['stop'], reason: 'a second dispose does not release again');
    });
  });

  group('the single message outlet cleans invisible characters', () {
    test('control characters go, tab newline carriage return and CJK stay', () {
      expect(cleanDanmakuText('a\u0000\u0001\u0007\u0008b\u000B\u000Cc\u000E\u001Fd'), 'abcd');
      expect(cleanDanmakuText('a\tb\nc\rd'), 'a\tb\nc\rd');
      expect(cleanDanmakuText('弹\u0000幕'), '弹幕');
      expect(cleanDanmakuText('a\u007F\u0080\u009Fb'), 'ab', reason: 'the C1 controls are invisible too');
      expect(cleanDanmakuText('\uFFF9a\uFFFB\uFFFC\uFFFE\uFFFF'), 'a', reason: 'the placeholders go');
      expect(cleanDanmakuText('弹幕 plain'), same('弹幕 plain'), reason: 'a clean text is passed through, not copied');
    });

    test('the message, its sender name and fan badge are cleaned at the outlet', () async {
      final session = _Session();
      final (messages, _) = await _collect(session);
      session.beginRun().message(_chat('hi\u0000 there', name: 'An\u0000n', badge: 'fan\u000Bclub'));
      await _settle();

      final message = messages.single;
      expect(message.text, 'hi there');
      expect(message.sender?.userName, 'Ann');
      expect(message.sender?.fanBadgeName, 'fanclub');
    });

    test('a message without anything to clean passes through as itself', () async {
      final session = _Session();
      final (messages, _) = await _collect(session);
      final plain = _chat('弹幕 plain');
      session.beginRun().message(plain);
      await _settle();

      expect(messages.single, same(plain));
    });

    test('a message of an attempt that is over never reaches the events', () async {
      final session = _Session();
      final (messages, _) = await _collect(session);
      final run = session.beginRun();
      session.endRun();

      run.message(_chat('late'));
      await _settle();
      expect(messages, isEmpty);
    });
  });
}
