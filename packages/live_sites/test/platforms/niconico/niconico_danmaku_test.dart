import 'dart:typed_data';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_danmaku_codec.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_protobuf.dart';
import 'package:test/test.dart';

/// A `google.protobuf.Timestamp` of [seconds] and [nanos].
Uint8List _at(int seconds, {int nanos = 250000}) =>
    (NiconicoProtoWriter()
          ..integer(1, seconds)
          ..integer(2, nanos))
        .toBytes();

/// `ChunkedMessage.Meta`: 1 id, 2 at.
Uint8List _meta({String id = 'm1', int at = 1790519893, int nanos = 250000}) =>
    (NiconicoProtoWriter()
          ..string(1, id)
          ..message(2, _at(at, nanos: nanos)))
        .toBytes();

/// One `ChunkedMessage`: the meta and then the payload the codec reads.
Uint8List _chunk({Uint8List? meta, Uint8List? data, Uint8List? state, int? signal}) {
  final writer = NiconicoProtoWriter();
  if (meta != null) writer.message(1, meta);
  if (data != null) writer.message(2, data);
  if (state != null) writer.message(4, state);
  if (signal != null) writer.integer(5, signal);
  return writer.toBytes();
}

/// A `NicoliveMessage` carrying one field of its oneof.
Uint8List _nicolive(int number, Uint8List value) => (NiconicoProtoWriter()..message(number, value)).toBytes();

/// A `Chat` (1 content, 2 name, 5 raw_user_id, 6 hashed_user_id, 7 modifier).
Uint8List _chat({Object? content = 'hello', String name = 'Ann', int? rawUserId, String? hashed, Uint8List? modifier}) {
  final writer = NiconicoProtoWriter();
  if (content is int) {
    writer.integer(1, content);
  } else if (content is String) {
    writer.string(1, content);
  }
  if (name.isNotEmpty) writer.string(2, name);
  if (rawUserId != null) writer.integer(5, rawUserId);
  if (hashed != null) writer.string(6, hashed);
  if (modifier != null) writer.message(7, modifier);
  return writer.toBytes();
}

/// A `Chat.Modifier` naming either a colour index or the red/green/blue triple.
Uint8List _modifier({int? named, int? r, int? g, int? b}) {
  final writer = NiconicoProtoWriter();
  if (named != null) writer.integer(3, named);
  if (r != null || g != null || b != null) {
    final rgb = NiconicoProtoWriter();
    if (r != null) rgb.integer(1, r);
    if (g != null) rgb.integer(2, g);
    if (b != null) rgb.integer(3, b);
    writer.message(4, rgb.toBytes());
  }
  return writer.toBytes();
}

/// A `Gift` (1 item_id, 2 advertiser_user_id, 3 advertiser_name, 4 point,
/// 5 message, 6 item_name).
Uint8List _giftLine({String? itemId, String? name, int? point, String? advertiser, int? advertiserId}) {
  final writer = NiconicoProtoWriter();
  if (itemId != null) writer.string(1, itemId);
  if (advertiserId != null) writer.integer(2, advertiserId);
  if (advertiser != null) writer.string(3, advertiser);
  if (point != null) writer.integer(4, point);
  if (name != null) writer.string(6, name);
  return writer.toBytes();
}

/// A `NicoliveState` from its fields, in the order the reader tries them:
/// 1 statistics, 4 marquee, 5 comment_lock, 9 program_status.
Uint8List _state({int? viewers, Uint8List? marquee, Uint8List? lock, int? programStatus}) {
  final writer = NiconicoProtoWriter();
  if (viewers != null) writer.message(1, (NiconicoProtoWriter()..integer(1, viewers)).toBytes());
  if (marquee != null) writer.message(4, marquee);
  if (lock != null) writer.message(5, lock);
  if (programStatus != null) writer.message(9, (NiconicoProtoWriter()..integer(1, programStatus)).toBytes());
  return writer.toBytes();
}

/// A `CommentLock` (1 status, 2 follow_restriction {1 minimum_follow_duration
/// {1 seconds}}).
Uint8List _lock(int status, {int? followSeconds}) {
  final writer = NiconicoProtoWriter()..integer(1, status);
  if (followSeconds != null) {
    final duration = (NiconicoProtoWriter()..integer(1, followSeconds)).toBytes();
    writer.message(2, (NiconicoProtoWriter()..message(1, duration)).toBytes());
  }
  return writer.toBytes();
}

/// A `Marquee` with an operator comment (display → comment: 1 content, 2 name,
/// 3 modifier); [cleared] sends the display with no comment at all.
Uint8List _marquee({String? content, String name = 'Operator', bool cleared = false, Uint8List? modifier}) {
  if (cleared) return (NiconicoProtoWriter()..message(1, NiconicoProtoWriter().toBytes())).toBytes();
  final comment = NiconicoProtoWriter();
  if (content != null) comment.string(1, content);
  if (name.isNotEmpty) comment.string(2, name);
  if (modifier != null) comment.message(3, modifier);
  final display = (NiconicoProtoWriter()..message(1, comment.toBytes())).toBytes();
  return (NiconicoProtoWriter()..message(1, display)).toBytes();
}

/// A `MessageSegment` (1 from, 2 until, 3 uri) for a `view` entry.
Uint8List _segment({int? from = 1790519893, int? until = 1790519953, String uri = 'https://cc.nicovideo.jp/1234/'}) {
  final writer = NiconicoProtoWriter();
  if (from != null) writer.message(1, _at(from, nanos: 0));
  if (until != null) writer.message(2, _at(until, nanos: 0));
  if (uri.isNotEmpty) writer.string(3, uri);
  return writer.toBytes();
}

/// One `ChunkedEntry`: 1 segment, 2 backward, 3 previous, 4 next {1 at}.
Uint8List _entry({Uint8List? segment, bool backward = false, Uint8List? previous, int? next}) {
  final writer = NiconicoProtoWriter();
  if (segment != null) writer.message(1, segment);
  if (backward) writer.message(2, (NiconicoProtoWriter()..string(1, 'older')).toBytes());
  if (previous != null) writer.message(3, previous);
  if (next != null) writer.message(4, (NiconicoProtoWriter()..integer(1, next)).toBytes());
  return writer.toBytes();
}

/// A decoded protobuf message from the bytes a writer built.
NiconicoProtoMessage _decoded(Uint8List bytes) => NiconicoProtoMessage.decode(bytes);

/// The wire form of one message of the length-delimited stream.
List<int> _varint(int value) {
  final out = <int>[];
  var rest = value;
  while (true) {
    final byte = rest & 0x7F;
    rest >>>= 7;
    if (rest == 0) return [...out, byte];
    out.add(byte | 0x80);
  }
}

/// The comment server frames each message as its bare varint length.
Uint8List _framed(List<int> message) => Uint8List.fromList([..._varint(message.length), ...message]);

/// One message of a state sequence, as a reader would meet it.
LiveMessage? _readState(NiconicoMessageReader reader, Uint8List state, {Uint8List? meta}) =>
    reader.read(_chunk(meta: meta ?? _meta(), state: state));

void main() {
  group('the framing of an answer', () {
    test('a length-delimited stream is its messages, in order', () {
      final first = _entry(next: 1);
      final second = _entry(next: 2);
      expect(NiconicoDanmakuCodec.split([..._framed(first), ..._framed(second)]), [first, second]);
      expect(NiconicoDanmakuCodec.split(const []), isEmpty);
    });

    test('an answer that ends inside a message is refused', () {
      final whole = _framed(_entry(next: 3));
      expect(() => NiconicoDanmakuCodec.split(whole.sublist(0, whole.length - 1)), throwsA(isA<FormatException>()));
    });

    test('a message over the cap is refused, and the stream cannot be read on', () async {
      final big = Uint8List(64);
      final body = Stream<List<int>>.fromIterable([_framed(big), _framed(_entry(next: 1))]);
      final seen = <Uint8List>[];
      await expectLater(
        NiconicoDanmakuCodec.delimited(body, maxLength: 32).forEach(seen.add),
        throwsA(isA<FormatException>()),
      );
      expect(seen, isEmpty, reason: 'the oversized message is not handed out before the failure');
    });

    test('a message split across chunks is yielded once it completes', () async {
      final message = _nicolive(1, _chat(content: '分かれた'));
      final framed = _framed(message);
      final seen = await NiconicoDanmakuCodec.delimited(
        Stream<List<int>>.fromIterable([framed.sublist(0, 1), framed.sublist(1, 3), framed.sublist(3)]),
      ).toList();
      expect(seen.single, message);
    });

    test('the comment-server address the seat may be read from', () {
      expect(NiconicoDanmakuCodec.isCommentServer(Uri.parse('https://cc.nicovideo.jp/1/')), isTrue);
      expect(NiconicoDanmakuCodec.isCommentServer(Uri.parse('https://nicovideo.jp/1/')), isTrue);
      expect(NiconicoDanmakuCodec.isCommentServer(Uri.parse('http://cc.nicovideo.jp/1/')), isFalse);
      expect(NiconicoDanmakuCodec.isCommentServer(Uri.parse('https://nicovideo.jp.evil.test/1/')), isFalse);
      expect(NiconicoDanmakuCodec.isCommentServer(Uri.parse('https://user@cc.nicovideo.jp/1/')), isFalse);
      expect(NiconicoDanmakuCodec.isCommentServer(Uri.parse('https://cc.nicovideo.jp:8443/1/')), isFalse);
      expect(NiconicoDanmakuCodec.isCommentServer(Uri.parse('https://cc.nicovideo.jp/1/#x')), isFalse);

      final view = Uri.parse('https://live2.deno.dev/view?token=t&other=1');
      expect(
        NiconicoDanmakuCodec.viewUrl(view, 'now'),
        Uri.parse('https://live2.deno.dev/view?token=t&other=1&at=now'),
      );
      expect(NiconicoDanmakuCodec.viewUrl(view, '1790519893').queryParameters['at'], '1790519893');
    });

    test('the window sizes the reader works with', () {
      expect(NiconicoDanmakuCodec.maxMessageBytes, 1 << 20);
      expect(NiconicoDanmakuCodec.namedColors, hasLength(20));
      expect(NiconicoDanmakuCodec.programEndedNotice, 'この番組は終了しました');
      expect(NiconicoDanmakuCodec.commentLockedNotice, '現在コメントできません');
    });
  });

  group('the view answer', () {
    test('a segment entry is the window to read', () {
      final entry = NiconicoDanmakuCodec.viewEntry(_entry(segment: _segment()));
      expect(entry.kind, NiconicoViewEntryKind.segment);
      final window = entry.window!;
      expect(window.uri.toString(), 'https://cc.nicovideo.jp/1234/');
      expect(window.from, DateTime.fromMicrosecondsSinceEpoch(1790519893000000));
      expect(window.until, DateTime.fromMicrosecondsSinceEpoch(1790519953000000));
      expect(window.toString(), contains('2026-09-27T22:38:13'));

      expect(NiconicoDanmakuCodec.viewEntry(_entry(previous: _segment())).kind, NiconicoViewEntryKind.previous);
      expect(NiconicoDanmakuCodec.viewEntry(_entry(backward: true)).kind, NiconicoViewEntryKind.backward);
      expect(NiconicoDanmakuCodec.viewEntry(_entry(backward: true)).window, isNull);
      expect(NiconicoDanmakuCodec.viewEntry(Uint8List(0)).kind, NiconicoViewEntryKind.unknown);
    });

    test('the next entry names when to ask again, and never a time that is not ahead', () {
      expect(NiconicoDanmakuCodec.viewEntry(_entry(next: 1790519953)).next, 1790519953);
      expect(NiconicoDanmakuCodec.viewEntry(_entry(next: 0)).next, isNull);
      expect(NiconicoDanmakuCodec.viewEntry(_entry(next: -5)).next, isNull);
      expect(NiconicoDanmakuCodec.viewEntry(_entry(next: 5)).kind, NiconicoViewEntryKind.next);
    });

    test('of a oneof the last field on the wire is the entry', () {
      final entry = NiconicoDanmakuCodec.viewEntry(_entry(segment: _segment(), next: 1790519999));
      expect(entry.kind, NiconicoViewEntryKind.next, reason: 'the next came after the segment');
      expect(entry.window, isNull);
    });

    test('a window that is not usable is no window', () {
      for (final segment in <Uint8List>[
        _segment(uri: ''),
        _segment(uri: 'http://cc.nicovideo.jp/1/'),
        _segment(uri: 'https://other.test/1/'),
        _segment(from: null),
        _segment(until: null),
        _segment(from: 8640000000001),
      ]) {
        expect(NiconicoDanmakuCodec.viewEntry(_entry(segment: segment)).window, isNull, reason: '$segment');
      }
    });

    test('bytes that are not protobuf are a format failure', () {
      expect(() => NiconicoDanmakuCodec.viewEntry([0xFF, 0xFF]), throwsA(isA<FormatException>()));
      expect(() => NiconicoDanmakuCodec.message([0xFF, 0xFF]), throwsA(isA<FormatException>()));
    });
  });

  group('chat lines', () {
    test('a chat carries its text, sender, colour, id and time', () {
      final message = NiconicoDanmakuCodec.message(
        _chunk(
          meta: _meta(id: ' c1 ', nanos: 500000),
          data: _nicolive(1, _chat()),
        ),
      )!;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, 'hello');
      expect(message.sender?.userName, 'Ann');
      expect(message.sender?.userId, isEmpty, reason: 'neither a hashed nor a raw id was sent');
      expect(message.messageId, 'c1', reason: 'the meta id is trimmed');
      expect(message.sentAt, DateTime.fromMicrosecondsSinceEpoch(1790519893000500));
      expect(message.color, LiveMessageColor.white);
    });

    test('the hashed id names the sender, and the raw one only when it is absent', () {
      LiveMessage? of({String? hashed, int? raw}) => NiconicoDanmakuCodec.message(
        _chunk(
          data: _nicolive(1, _chat(hashed: hashed, rawUserId: raw)),
        ),
      );
      expect(of(hashed: 'h1', raw: 42)!.sender?.userId, 'h1');
      expect(of(hashed: ' ', raw: 42)!.sender?.userId, '42', reason: 'a blank hashed id is not an id');
      expect(of(raw: 42)!.sender?.userId, '42');
      expect(of(raw: 0)!.sender?.userId, '0');
      expect(of()!.sender?.userId, isEmpty);
    });

    test('a chat with no text is not a message, and a field of another wire type is not text', () {
      expect(NiconicoDanmakuCodec.message(_chunk(data: _nicolive(1, _chat(content: '   ')))), isNull);
      expect(NiconicoDanmakuCodec.message(_chunk(data: _nicolive(1, _chat(content: null)))), isNull);
      expect(NiconicoDanmakuCodec.message(_chunk(data: _nicolive(1, _chat(content: 7)))), isNull);
    });

    test('an overflowed chat is a chat, and the other oneof fields are not reported', () {
      for (final number in [7, 9, 13, 17, 18, 19, 22, 23, 24, 25, 26]) {
        expect(
          NiconicoDanmakuCodec.message(_chunk(data: _nicolive(number, _chat()))),
          isNull,
          reason: 'oneof field $number',
        );
      }
      expect(NiconicoDanmakuCodec.message(_chunk(data: _nicolive(20, _chat())))!.text, 'hello');
      expect(NiconicoDanmakuCodec.message(_chunk(data: _nicolive(1, _chat(content: 'first'))))!.text, 'first');
    });

    test('of a oneof the last field on the wire is the message', () {
      final writer = NiconicoProtoWriter()
        ..message(1, _chat(content: 'first'))
        ..message(20, _chat(content: 'second'));
      expect(NiconicoDanmakuCodec.message(_chunk(data: writer.toBytes()))!.text, 'second');
    });

    test('a chunk that is neither a message nor a state reports nothing', () {
      expect(NiconicoDanmakuCodec.message(_chunk(meta: _meta())), isNull);
      expect(NiconicoDanmakuCodec.message(_chunk()), isNull);
      expect(NiconicoDanmakuCodec.message(_chunk(signal: 3)), isNull);
    });

    test('a signal in the chunk keeps a stale message from being read as a chat', () {
      final writer = NiconicoProtoWriter()
        ..message(1, _meta())
        ..message(2, _nicolive(1, _chat()))
        ..integer(5, 1);
      expect(NiconicoDanmakuCodec.message(writer.toBytes()), isNull, reason: 'the last payload wins: a Flushed signal');
    });

    test('the colours a comment may name', () {
      LiveMessage? colored(Uint8List? modifier) =>
          NiconicoDanmakuCodec.message(_chunk(data: _nicolive(1, _chat(modifier: modifier))));
      expect(colored(null)!.color, LiveMessageColor.white);
      expect(colored(_modifier())!.color, LiveMessageColor.white);
      expect(colored(_modifier(named: 1))!.color, const LiveMessageColor(255, 0, 0));
      expect(colored(_modifier(named: 19))!.color, const LiveMessageColor(102, 102, 102));
      expect(colored(_modifier(named: 20))!.color, LiveMessageColor.white, reason: 'past the table is white');
      expect(colored(_modifier(named: -1))!.color, LiveMessageColor.white);
      expect(
        colored(_modifier(named: 7, r: 1, g: 2, b: 3))!.color,
        const LiveMessageColor(0, 0, 255),
        reason: 'the named colour is read first',
      );
      expect(
        colored(_modifier(r: 10, g: 300, b: -5))!.color,
        const LiveMessageColor(10, 255, 0),
        reason: 'channels are clamped, and an absent one is zero',
      );
    });

    test('a timestamp the answer does not hold leaves the line undated', () {
      DateTime? at({int? seconds, int? nanos}) {
        final meta =
            (NiconicoProtoWriter()
                  ..string(1, 'm')
                  ..message(2, _at(seconds ?? 0, nanos: nanos ?? 0)))
                .toBytes();
        return NiconicoDanmakuCodec.message(_chunk(meta: meta, data: _nicolive(1, _chat())))?.sentAt;
      }

      expect(at(seconds: 1790519893), DateTime.fromMicrosecondsSinceEpoch(1790519893000000));
      expect(at(seconds: 8640000000000), isNotNull);
      expect(at(seconds: 8640000000001), isNull);
      expect(at(seconds: -8640000000001), isNull);
      expect(at(seconds: 1790519893, nanos: -1), isNull);
      expect(at(seconds: 1790519893, nanos: 1000000000), isNull);
      expect(at(nanos: 999999999), isNotNull, reason: 'a bare nanos field with seconds zero is the epoch');
      expect(
        NiconicoDanmakuCodec.message(_chunk(data: _nicolive(1, _chat())))!.sentAt,
        isNull,
        reason: 'no meta at all is no time',
      );
    });
  });

  group('gifts', () {
    test('a gift is the one-item line with its value', () {
      final message = NiconicoDanmakuCodec.message(
        _chunk(
          meta: _meta(id: 'g1'),
          data: _nicolive(8, _giftLine(itemId: 'nikoko', name: 'ニコ子', point: 100, advertiser: 'Ann', advertiserId: 7)),
        ),
      )!;
      expect(message.type, LiveMessageType.gift);
      expect(message.text, 'ニコ子 ×1');
      expect(message.messageId, 'g1');
      expect(message.sender?.userName, 'Ann');
      expect(message.sender?.userId, '7');
      final gift = message.payload! as LiveGift;
      expect(gift.giftId, 'nikoko');
      expect(gift.name, 'ニコ子');
      expect(gift.value.unit, LiveGiftUnit.point);
      expect(gift.value.unitPrice, 100);
      expect(gift.value.totalValue, 100);
    });

    test('a free gift says so and names no price', () {
      final gift =
          NiconicoDanmakuCodec.message(_chunk(data: _nicolive(8, _giftLine(name: 'ニコ子'))))!.payload! as LiveGift;
      expect(gift.value.unit, LiveGiftUnit.free);
      expect(gift.value.unitPrice, isNull);
      expect(gift.value.totalValue, isNull);
    });

    test('the id stands in when no item name is sent, and an unnamed nothing is dropped', () {
      expect(
        NiconicoDanmakuCodec.message(_chunk(data: _nicolive(8, _giftLine(itemId: 'nikoko', point: 1))))!.text,
        'nikoko ×1',
      );
      expect(NiconicoDanmakuCodec.message(_chunk(data: _nicolive(8, _giftLine(point: 1)))), isNull);
      expect(
        NiconicoDanmakuCodec.message(_chunk(data: _nicolive(8, _giftLine(itemId: 'x', point: -1)))),
        isNull,
        reason: 'negative points are not a gift',
      );
    });

    test('a gift of no advertiser names nobody', () {
      final message = NiconicoDanmakuCodec.message(
        _chunk(data: _nicolive(8, _giftLine(name: 'ニコ子', point: 1, advertiserId: 0))),
      )!;
      expect(message.sender?.userName, isEmpty);
      expect(message.sender?.userId, isEmpty, reason: 'a zero advertiser id is not an id');
    });
  });

  group('the state of the program', () {
    test('statistics are the audience of the seat', () {
      final message = NiconicoMessageReader().read(_chunk(state: _state(viewers: 240)))!;
      expect(message.type, LiveMessageType.audienceUpdate);
      final audience = message.payload! as LiveAudienceUpdate;
      expect(audience.kind, LiveAudienceSignalKind.totalViewers);
      expect(audience.value, 240);
      expect(NiconicoMessageReader().read(_chunk(state: _state(viewers: 0))), isNotNull, reason: 'zero is a number');
      expect(NiconicoMessageReader().read(_chunk(state: _state(viewers: -1))), isNull);
      expect(NiconicoMessageReader().read(_chunk(state: _state())), isNull);
    });

    test("the end of the program is the web player's line and ends its seat", () {
      final reader = NiconicoMessageReader();
      expect(reader.endedProgram, isFalse);
      final message = reader.read(
        _chunk(
          meta: _meta(id: ' e1 '),
          state: _state(programStatus: 1),
        ),
      )!;
      expect(message.type, LiveMessageType.notice);
      expect(message.text, NiconicoDanmakuCodec.programEndedNotice);
      expect(message.messageId, 'e1');
      expect(message.sentAt, DateTime.fromMicrosecondsSinceEpoch(1790519893000250));
      expect(reader.endedProgram, isTrue);

      reader.read(_chunk(meta: _meta(), state: _state(viewers: 3)));
      expect(reader.endedProgram, isFalse, reason: 'the flag is re-read per message');
      expect(
        reader.read(_chunk(state: _state(programStatus: 2))),
        isNull,
        reason: 'another program status is not the end, and names nothing else',
      );
      expect(reader.endedProgram, isFalse);
    });

    test("a marquee comment is the operator's notice, in its colour", () {
      final message = NiconicoMessageReader().read(
        _chunk(
          meta: _meta(),
          state: _state(
            marquee: _marquee(content: ' here ', name: 'Owner', modifier: _modifier(named: 1)),
          ),
        ),
      )!;
      expect(message.type, LiveMessageType.notice);
      expect(message.text, 'here');
      expect(message.sender?.userName, 'Owner');
      expect(message.color, const LiveMessageColor(255, 0, 0));
      expect(message.messageId, 'm1', reason: 'a notice carries the meta id like a chat does');
      expect(
        NiconicoMessageReader().read(
          _chunk(
            state: _state(marquee: _marquee(content: '   ')),
          ),
        ),
        isNull,
      );
      expect(NiconicoMessageReader().read(_chunk(state: _state(marquee: _marquee(cleared: true)))), isNull);
    });

    test('only a change of who may comment is reported', () {
      final reader = NiconicoMessageReader();
      expect(_readState(reader, _state(lock: _lock(1)))?.text, NiconicoDanmakuCodec.commentLockedNotice);
      expect(_readState(reader, _state(lock: _lock(1))), isNull, reason: 'the same lock again says nothing');
      expect(_readState(reader, _state(lock: _lock(0)))?.text, NiconicoDanmakuCodec.commentUnlockedNotice);
      expect(_readState(reader, _state(lock: _lock(0))), isNull);
      expect(_readState(reader, _state(lock: _lock(2, followSeconds: 86400)))?.text, '【コメント制限】1日フォローを継続したユーザーに限定されます');
      expect(_readState(reader, _state(lock: _lock(2, followSeconds: 0)))?.text, '【コメント制限】フォロワーに限定されます');
      expect(_readState(reader, _state(lock: _lock(0)))?.text, NiconicoDanmakuCodec.followersOnlyLiftedNotice);

      final fresh = NiconicoMessageReader();
      expect(_readState(fresh, _state(lock: _lock(3))), isNull, reason: 'an unknown status changes nothing');
      expect(
        _readState(fresh, _state(lock: _lock(3), viewers: 12))?.type,
        LiveMessageType.audienceUpdate,
        reason: 'and the state is still read past it',
      );
      expect(
        _readState(fresh, _state(lock: _lock(2, followSeconds: 0)))?.text,
        '【コメント制限】フォロワーに限定されます',
        reason: 'a restriction of no duration is the shortest one',
      );
    });

    test('a lock change wins over the rest of the same state', () {
      final reader = NiconicoMessageReader();
      final message = _readState(
        reader,
        _state(
          viewers: 5000,
          marquee: _marquee(content: 'x'),
          lock: _lock(1),
        ),
      );
      expect(message?.text, NiconicoDanmakuCodec.commentLockedNotice, reason: 'one notice per state');
      expect(
        _readState(reader, _state(viewers: 5000, lock: _lock(1)))?.type,
        LiveMessageType.audienceUpdate,
        reason: 'once the lock is unchanged the state is read on',
      );
      expect(
        _readState(
          reader,
          _state(
            marquee: _marquee(content: 'after'),
            lock: _lock(1),
          ),
        )?.text,
        'after',
      );
    });

    test('a state field that is not protobuf counts as absent', () {
      final writer = NiconicoProtoWriter()
        ..integer(5, 1)
        ..message(1, (NiconicoProtoWriter()..integer(1, 20)).toBytes());
      expect(NiconicoMessageReader().read(_chunk(state: writer.toBytes()))?.type, LiveMessageType.audienceUpdate);
      expect(
        NiconicoMessageReader().read(_chunk(state: _state(lock: Uint8List.fromList([0xFF]), viewers: 9)))!.type,
        LiveMessageType.audienceUpdate,
        reason: 'a broken lock is not a lock',
      );
    });
  });

  group('the reader of one comment lock', () {
    test('a follow restriction is written the way the web player writes it', () {
      for (final entry in const <int, String>{
        0: '0分',
        59: '0分',
        60: '1分',
        3599: '59分',
        3600: '1時間',
        3660: '1時間1分',
        86399: '23時間59分',
        86400: '1日',
        89999: '1日',
        90060: '1日と1時間',
      }.entries) {
        expect(NiconicoDanmakuCodec.followDuration(entry.key), entry.value, reason: '${entry.key} seconds');
      }
    });

    test('who may comment, read from a CommentLock', () {
      NiconicoCommentLock? of(int status, {int? followSeconds}) =>
          NiconicoDanmakuCodec.commentLockOf(_decoded(_lock(status, followSeconds: followSeconds)));

      expect(of(0), NiconicoCommentLock.none);
      expect(of(1), NiconicoCommentLock.locked);
      expect(
        of(2),
        const NiconicoCommentLock.followers(Duration.zero),
        reason: 'a restriction-less status 2 is followers with no wait',
      );
      expect(of(2, followSeconds: 3600), const NiconicoCommentLock.followers(Duration(hours: 1)));
      expect(of(2, followSeconds: -5), const NiconicoCommentLock.followers(Duration.zero));
      expect(
        of(2, followSeconds: NiconicoDanmakuCodec.maxFollowSeconds + 1),
        const NiconicoCommentLock.followers(Duration(seconds: NiconicoDanmakuCodec.maxFollowSeconds)),
      );
      expect(of(4), isNull);
    });

    test('the lock of an empty message is everyone', () {
      final empty = NiconicoProtoMessage.decode(const <int>[]);
      expect(NiconicoDanmakuCodec.commentLockOf(empty), NiconicoCommentLock.none);
      expect(NiconicoDanmakuCodec.commentLockNotice(NiconicoCommentLock.none, NiconicoCommentLock.none), isNull);
    });

    test('a notice carries the meta it was read with', () {
      final notice = NiconicoDanmakuCodec.notice('テキスト', _decoded(_meta(id: ' n1 ')));
      expect(notice.type, LiveMessageType.notice);
      expect(notice.text, 'テキスト');
      expect(notice.messageId, 'n1');
      expect(notice.sentAt, DateTime.fromMicrosecondsSinceEpoch(1790519893000250));
      expect(notice.color, LiveMessageColor.white);
      expect(notice.sender?.userName, isEmpty);

      final own = NiconicoDanmakuCodec.programEnded(messageId: 'own', sentAt: DateTime.utc(2026, 11, 5));
      expect(own.messageId, 'own', reason: 'a given id is not read from the meta');
      expect(own.sentAt, DateTime.utc(2026, 11, 5));
    });
  });
}
