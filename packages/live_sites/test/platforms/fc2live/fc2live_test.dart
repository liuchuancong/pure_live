import 'dart:convert';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/fc2live/danmaku/fc2live_danmaku_codec.dart';
import 'package:test/test.dart';

const int _millis = 1790733600000;

Map<String, Object?> _row({
  Object? comment = 'hello',
  String name = 'Ann',
  Object? color,
  Object? timestamp = _millis,
  Object? anonymous,
  Object? history,
  Object? system,
  String? encrypted = 'visitor',
  int owner = 0,
  String? orz,
}) => {
  'comment': comment,
  'user_name': name,
  'encrypted_user_id': ?encrypted,
  'color': ?color,
  'timestamp': ?timestamp,
  'anonymous': ?anonymous,
  'history': ?history,
  'system_comment': ?system,
  'owner': owner,
  'orz_token': ?orz,
};

void main() {
  group('frames', () {
    test('a frame names its message and keeps its arguments', () {
      final frame = Fc2LiveDanmakuCodec.decode(
        jsonEncode({
          'name': 'comment',
          'id': 5,
          'arguments': {'comments': <Object?>[]},
        }),
      )!;
      expect(frame.name, 'comment');
      expect(frame.id, 5);
      expect(frame.arguments, containsPair('comments', isEmpty));
      final bytes = Fc2LiveDanmakuCodec.decode(utf8.encode('{"name":"heartbeat"}'))!;
      expect(bytes.name, 'heartbeat');
      expect(bytes.arguments, isEmpty);
    });

    test('a frame that is not JSON or names nothing is none', () {
      expect(Fc2LiveDanmakuCodec.decode('not json'), isNull);
      expect(Fc2LiveDanmakuCodec.decode('[]'), isNull);
      expect(Fc2LiveDanmakuCodec.decode('{}'), isNull);
      expect(Fc2LiveDanmakuCodec.decode({'name': 'comment'}), isNull);
      expect(Fc2LiveDanmakuCodec.decode('{"name":"x","arguments":[]}')!.arguments, isEmpty);
      expect(Fc2LiveDanmakuCodec.heartbeat(3), '{"name":"heartbeat","arguments":{},"id":3}');
    });
  });

  group('comments', () {
    test('a row is chat with its cleaned text, colour and sender', () {
      final message = Fc2LiveDanmakuCodec.comment(
        _row(comment: '<b>hi</b> &amp; bye', color: 'red'),
      )!;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, 'hi & bye');
      expect(message.color, Fc2LiveDanmakuCodec.colors['red']);
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(_millis));
      expect(message.sender?.userName, 'Ann');
      expect(message.sender?.userId, 'id_visitor');
    });

    test('an anonymous or nameless row is the site anonymous name', () {
      expect(Fc2LiveDanmakuCodec.comment(_row(anonymous: 1))?.sender?.userName, Fc2LiveDanmakuCodec.anonymousName);
      expect(Fc2LiveDanmakuCodec.comment(_row(name: '  '))?.sender?.userName, Fc2LiveDanmakuCodec.anonymousName);
    });

    test('history, system rows, blank text and bad times are not chat', () {
      expect(Fc2LiveDanmakuCodec.comment(_row(history: 1)), isNull);
      expect(Fc2LiveDanmakuCodec.comment(_row(history: '1')), isNull);
      expect(Fc2LiveDanmakuCodec.comment(_row(system: {'type': 'gift'})), isNull);
      expect(Fc2LiveDanmakuCodec.comment(_row(comment: '<br> ')), isNull);
      expect(Fc2LiveDanmakuCodec.comment(_row(comment: 5)), isNull);
      expect(Fc2LiveDanmakuCodec.comment(_row(timestamp: -1))?.sentAt, isNull);
      expect(Fc2LiveDanmakuCodec.comment(_row(timestamp: null))?.sentAt, isNull);
      expect(Fc2LiveDanmakuCodec.comment(_row(encrypted: null))?.sender?.userId, '');
      expect(Fc2LiveDanmakuCodec.comment('row'), isNull);
    });

    test('the comment list skips what is not chat', () {
      final messages = Fc2LiveDanmakuCodec.comments({
        'comments': [_row(), _row(history: 1), _row(comment: 'kept')],
      });
      expect(messages.map((message) => message.text), ['hello', 'kept']);
    });

    test('an FC2 id written with an offset is decoded to a stable key', () {
      final encoded = String.fromCharCodes([0x61, 0x32, 6, 13, 20]);
      expect(Fc2LiveDanmakuCodec.userId(encoded), 'id-10-20-30');
      expect(Fc2LiveDanmakuCodec.userId('visitor'), 'id_visitor');
      expect(Fc2LiveDanmakuCodec.userId(''), '');
      expect(Fc2LiveDanmakuCodec.userId(5), '');
    });

    test('text is cleaned and re-escaped for the filters, and colours are by name', () {
      expect(Fc2LiveDanmakuCodec.plainText(' <i>Tom &amp; Jerry</i> '), 'Tom & Jerry');
      expect(Fc2LiveDanmakuCodec.escapedText('<i>Tom &amp; Jerry</i>'), 'Tom &amp; Jerry');
      expect(Fc2LiveDanmakuCodec.escapedText('a < b'), 'a &lt; b');
      expect(Fc2LiveDanmakuCodec.color(' BLUE '), Fc2LiveDanmakuCodec.colors['blue']);
      expect(Fc2LiveDanmakuCodec.color('black'), LiveMessageColor.white);
      expect(Fc2LiveDanmakuCodec.color(5), LiveMessageColor.white);
      expect(Fc2LiveDanmakuCodec.isSet(1), isTrue);
      expect(Fc2LiveDanmakuCodec.isSet('1'), isTrue);
      expect(Fc2LiveDanmakuCodec.isSet(true), isTrue);
      expect(Fc2LiveDanmakuCodec.isSet('0'), isFalse);
      expect(Fc2LiveDanmakuCodec.isSet(null), isFalse);
    });
  });

  group('NG filters', () {
    test('a keyword hides matching comments, case-insensitively', () {
      final ng = Fc2LiveNgList()
        ..apply({
          'ng_comments': [
            {'type': 'keyword', 'ng_keyword': 'spoiler'},
          ],
        });
      expect(ng.length, 1);
      expect(ng.hides(_row(comment: 'a SPOILER here')), isTrue);
      expect(ng.hides(_row(comment: 'fine')), isFalse);
      expect(
        Fc2LiveDanmakuCodec.comments({
          'comments': [_row(comment: 'SPOILER'), _row()],
        }, ng: ng).map((m) => m.text),
        ['hello'],
      );
    });

    test('the platform and shared lists apply only when enabled', () {
      final ng = Fc2LiveNgList()
        ..apply({
          'ng_comments': [
            {'type': 'admin_keyword', 'ng_keyword': 'bad'},
            {'type': 'share_high', 'ng_orz_token': 'tokH'},
          ],
        });
      expect(ng.length, 2);
      expect(ng.hides(_row(comment: 'bad')), isFalse);
      expect(ng.hides(_row(orz: 'tokH')), isFalse);
      ng.apply({'admin_ng': 1, 'shared_ng_level': 1});
      expect(ng.usesAdminLists, isTrue);
      expect(ng.sharedLevel, 1);
      expect(ng.hides(_row(comment: 'bad')), isTrue);
      expect(ng.hides(_row(orz: 'tokH')), isFalse);
      ng.apply({'shared_ng_level': 2});
      expect(ng.hides(_row(orz: 'tokH')), isTrue);
    });

    test('a sender entry hides by its session token, and entries can be removed', () {
      final ng = Fc2LiveNgList()
        ..apply({
          'ng_comments': [
            {'type': 'user', 'ng_orz_token': 'tok'},
            {'type': 'keyword', 'ng_comment_id': 7, 'ng_keyword': 'gone'},
          ],
        });
      expect(ng.length, 2);
      expect(ng.hides(_row(orz: 'tok')), isTrue);
      expect(ng.hides(_row(orz: 'other')), isFalse);
      expect(ng.hides(_row(orz: 'tok', owner: 1)), isFalse);
      ng.apply({
        'ng_comments': [
          {'type': 'keyword', 'ng_comment_id': 7, 'mode': 'remove'},
        ],
      });
      expect(ng.length, 1);
      expect(ng.hides(_row(comment: 'gone')), isFalse);
    });
  });

  group('audience', () {
    test('the halves are summed, and only the changed figures are reported', () {
      final audience = Fc2LiveAudience();
      expect(audience.online, isNull);
      expect(audience.update({'pc_user_count': 10}).single.payload, isA<LiveAudienceUpdate>());
      expect(audience.online, 10);
      expect(audience.update({'mobile_user_count': 5}).single.type, LiveMessageType.audienceUpdate);
      expect(audience.online, 15);
      expect(audience.update({'pc_total_count': 100}).single.type, LiveMessageType.audienceUpdate);
      expect(audience.total, 100);
      final totals = audience.update({'mobile_total_count': 20});
      expect((totals.single.payload! as LiveAudienceUpdate).kind, LiveAudienceSignalKind.totalViewers);
      expect(audience.total, 120);
      expect(audience.update({'pc_user_count': -1}), isEmpty);
      expect(audience.update({}), isEmpty);
      expect(audience.online, 15);
    });

    test('a figure is reported only once either half is known', () {
      final audience = Fc2LiveAudience();
      expect(audience.update({'pc_user_count': 3}).single.payload, isA<LiveAudienceUpdate>());
      expect(audience.online, 3);
      expect(audience.update({'pc_user_count': 3}), isEmpty);
    });
  });

  group('wiring', () {
    test('the endpoint carries the channel, and the secrets are redacted', () {
      final endpoint = Fc2LiveDanmakuCodec.endpoint('12345');
      expect(Fc2LiveDanmakuCodec.channelOf(endpoint), '12345');
      expect(Fc2LiveDanmakuCodec.channelOf(Uri.parse('https://example.com/x?channel_id=12345')), isNull);
      expect(
        Fc2LiveDanmakuCodec.redact('wss://a?control_token=secret&l_ortkn=t&x=1'),
        'wss://a?control_token=…&l_ortkn=…&x=1',
      );
    });
  });
}
