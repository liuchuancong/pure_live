import 'package:live_sites/src/models/serializers.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_price/live_super_chat_price.dart';
import 'package:test/test.dart';

final DateTime _at = DateTime.utc(2026, 11, 6, 12);

/// A paid message shown a minute from [seconds] after [_at].
LiveSuperChatMessage _chat(
  int seconds, {
  String id = '',
  String user = 'viewer',
  String text = 'same paid text',
  int amount = 30,
  String face = '',
  bool estimated = false,
}) => LiveSuperChatMessage.of(
  messageId: id,
  userName: user,
  faceUrl: face,
  text: text,
  price: SuperChatPrice.of(amount: amount, currency: 'CNY'),
  startTime: _at.add(Duration(seconds: seconds)),
  endTime: _at.add(Duration(seconds: seconds + 60)),
  hasEstimatedStartTime: estimated,
);

void main() {
  group('one super chat event', () {
    test('an id names its event: equal ids match whatever else moved, other ids never', () {
      expect(_chat(0, id: 'a').isSameEventAs(_chat(120, id: 'a', text: 'edited')), isTrue);
      expect(_chat(0, id: 'a').isSameEventAs(_chat(0, id: 'b')), isFalse);
      expect(_chat(0, id: 'a').isSameEventAs(_chat(0)), isFalse, reason: 'an id never matches a message without one');
      expect(_chat(0).isSameEventAs(_chat(0, id: 'a')), isFalse);
    });

    test('without ids, the same payload at the same start is one event and a later start a new purchase', () {
      expect(_chat(0).isSameEventAs(_chat(0)), isTrue);
      expect(_chat(0).isSameEventAs(_chat(1)), isFalse, reason: 'an event time that moved is another purchase');
      expect(_chat(0).isSameEventAs(_chat(0, text: 'other')), isFalse);
      expect(_chat(0).isSameEventAs(_chat(0, user: 'other')), isFalse);
      expect(_chat(0).isSameEventAs(_chat(0, amount: 50)), isFalse);
      expect(_chat(0).isSameEventAs(_chat(0, face: 'https://a/b.png')), isTrue, reason: 'the avatar is no part of it');
      final local = _chat(0).rebuild((b) => b.startTime = _at.toLocal());
      expect(local.isSameEventAs(_chat(0)), isTrue, reason: 'the same moment in another zone is the same start');
    });

    test('an estimated start matches an overlapping window, either way round', () {
      expect(_chat(0, estimated: true).isSameEventAs(_chat(1, estimated: true)), isTrue);
      expect(_chat(1, estimated: true).isSameEventAs(_chat(0, estimated: true)), isTrue);
      expect(_chat(0, estimated: true).isSameEventAs(_chat(5)), isTrue, reason: 'one estimate is enough');
      expect(_chat(5).isSameEventAs(_chat(0, estimated: true)), isTrue);
      expect(
        _chat(0, estimated: true).isSameEventAs(_chat(60, estimated: true)),
        isFalse,
        reason: 'adjacent windows are distinct events',
      );
      expect(_chat(0, estimated: true).isSameEventAs(_chat(120, estimated: true)), isFalse);
      expect(_chat(0, estimated: true).isSameEventAs(_chat(1, text: 'other', estimated: true)), isFalse);
    });

    test('overlap stays out of equality, for it is not transitive', () {
      final first = _chat(0, estimated: true);
      final drifted = _chat(1, estimated: true);
      expect(first.isSameEventAs(drifted), isTrue);
      expect(first, isNot(drifted));
      expect({first, drifted}, hasLength(2));

      final middle = _chat(40, estimated: true);
      final last = _chat(80, estimated: true);
      expect(first.isSameEventAs(middle) && middle.isSameEventAs(last), isTrue);
      expect(first.isSameEventAs(last), isFalse);
    });

    test('a start or an end that is not known matches only what it must', () {
      final bare = LiveSuperChatMessage.of(userName: 'viewer', text: 'same paid text');
      expect(bare.isSameEventAs(LiveSuperChatMessage.of(userName: 'viewer', text: 'same paid text')), isTrue);
      expect(
        bare.isSameEventAs(_chat(0).rebuild((b) => b.price.replace(SuperChatPrice()))),
        isFalse,
        reason: 'a known start is not an unknown one',
      );
      final openEnded = _chat(1, estimated: true).rebuild((b) => b.endTime = null);
      expect(openEnded.isSameEventAs(_chat(0, estimated: true)), isFalse, reason: 'no window, no overlap');
    });

    test('folding by it keeps the first card of each event', () {
      final read = [_chat(0, estimated: true), _chat(10, id: 'huya:1')];
      final reread = [_chat(3, estimated: true), _chat(14, id: 'huya:1'), _chat(20, id: 'huya:2')];
      final folded = [...read];
      for (final message in reread) {
        if (!folded.any(message.isSameEventAs)) folded.add(message);
      }
      expect(folded, hasLength(3));
      expect(folded.first, same(read.first));
      expect(folded[1], same(read[1]));
      expect(folded.last.messageId, 'huya:2');
    });
  });

  group('the estimate mark', () {
    test('is false unless a source sets it', () {
      expect(LiveSuperChatMessage.of().hasEstimatedStartTime, isFalse);
      expect(LiveSuperChatMessage().hasEstimatedStartTime, isFalse);
    });

    test('round-trips, and a record written before it reads as false', () {
      final json = Map<String, Object?>.from(
        serializers.serializeWith(LiveSuperChatMessage.serializer, _chat(0, estimated: true))! as Map,
      );
      expect(LiveSuperChatMessage.fromJson(json).hasEstimatedStartTime, isTrue);
      expect(LiveSuperChatMessage.fromJson(json), _chat(0, estimated: true));
      final older = {...json}..remove('hasEstimatedStartTime');
      expect(LiveSuperChatMessage.fromJson(older).hasEstimatedStartTime, isFalse);
    });
  });
}
