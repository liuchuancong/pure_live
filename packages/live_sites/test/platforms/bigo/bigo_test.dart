import 'dart:convert';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/bigo/api/bigo_http.dart';
import 'package:live_sites/src/platforms/bigo/bigo_site.dart';
import 'package:live_sites/src/platforms/bigo/danmaku/bigo_danmaku_codec.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_hls_protection.dart';
import 'package:test/test.dart';

const String _room = '123';

/// A `10|24` gift animation frame (uri 2584, `oriUri` 760969).
Map<String, Object?> _gift({String name = 'Flower', int count = 2, int? sends = 3, String room = _room}) => {
  'room_id': room,
  'seqId': '9',
  'from_uid': '1001',
  'payload': {
    'room_id': room,
    'oriUri': BigoDanmakuCodec.giftOriUri,
    'vgift_typeid': '77',
    'vgift_name': name,
    'vgift_count': count,
    'send_times': ?sends,
    'from_uid': '1001',
  },
};

/// The Base64 chat-list line that names a gift's sender.
String _line(Map<String, Object?> json) => base64.encode(utf8.encode(jsonEncode(json)));

void main() {
  group('gifts (760969)', () {
    test('a gift carries its id, name, count and the combo so far', () {
      final message = BigoDanmakuCodec.gift(_gift(), roomId: _room)!;
      expect(message.type, LiveMessageType.gift);
      expect(message.text, 'Flower x2');
      expect(message.sender?.userId, '1001');
      expect(message.messageId, '1001:9');
      final gift = message.giftOrNull! as LiveGift;
      expect(gift.giftId, '77');
      expect(gift.name, 'Flower');
      expect(gift.count, 2);
      expect(gift.combo.comboTotal, 6);
    });

    test('another room, no name or no count of sends is handled', () {
      expect(BigoDanmakuCodec.gift(_gift(room: '999'), roomId: _room), isNull);
      expect(BigoDanmakuCodec.gift(_gift(name: ''), roomId: _room), isNull);
      final gift = BigoDanmakuCodec.gift(_gift(sends: null), roomId: _room)!.giftOrNull! as LiveGift;
      expect(gift.combo.comboTotal, isNull);
      expect(gift.count, 2);
    });

    test('the line after a gift names its sender, level and text', () {
      final frame = <Object?, Object?>{
        'room_id': _room,
        'payload': {
          'tag': '${BigoDanmakuCodec.giftLineTag}',
          'uid': '1001',
          'grade': '31',
          'content': _line({'n': 'Ann', 'm': 'Flower 送出了 2 个'}),
        },
      };
      final sender = BigoDanmakuCodec.giftLine(frame, roomId: _room)!;
      expect(sender.userId, '1001');
      expect(sender.name, 'Ann');
      expect(sender.level, '31');
      expect(
        BigoDanmakuCodec.giftLine({
          'room_id': _room,
          'payload': {'tag': '1'},
        }, roomId: _room),
        isNull,
      );
    });
  });

  group('audience', () {
    test('both audience frames are concurrent viewers', () {
      final first = BigoDanmakuCodec.audience(
        {'gid': _room, 'totalUserCount': '2472'},
        uri: BigoDanmakuCodec.audienceUri,
        roomId: _room,
      )!;
      final second = BigoDanmakuCodec.audience({'room_id': _room, 'total': 2513}, uri: 11032, roomId: _room)!;
      expect(first.type, LiveMessageType.audienceUpdate);
      expect('${first.payload}', contains('2472'));
      expect('${second.payload}', contains('2513'));
      expect(
        BigoDanmakuCodec.audience(
          {'gid': '999', 'totalUserCount': '1'},
          uri: BigoDanmakuCodec.audienceUri,
          roomId: _room,
        ),
        isNull,
      );
    });
  });

  group('playback (the web stream is scrambled)', () {
    test('the room answers the reason and spends no single-use address', () async {
      final site = BigoSite(http: BigoHttp(_NeverHttp()));
      final answer = await site.capability<LivePlaybackProvider>()!.getLines(
        room: LiveRoom.normalized(platform: 'bigo', roomId: _room),
      );

      final error = answer.match((failure) => failure, (lines) => throw StateError('bigo handed out $lines'));
      expect(error, isA<LiveSiteUnsupported>());

      // What the viewer is told, not a stack trace: the stream is protected and
      // this build does not descramble it.
      expect(error.message, contains('加密'));
    });

    test('the protection is recognised, and its transform is its own inverse', () {
      const playlist = '#EXTM3U\n#EXT-X-BIGO-WEB-PROTECTION:VERSION=1,SEED=2654435769\n#EXTINF:2,\nseg.ts\n';
      expect(BigoHlsProtection.seed(playlist), 2654435769);

      // An ordinary playlist is not protected and answers nothing.
      expect(BigoHlsProtection.seed('#EXTM3U\n#EXTINF:2,\nseg.ts\n'), isNull);

      // Applying the transform twice with one seed restores the bytes: what any
      // descrambler would rely on, and the reason the algorithm is kept.
      final plain = List<int>.generate(BigoHlsProtection.prefixBytes, (i) => (i * 37 + 7) & 0xff);
      final scrambled = BigoHlsProtection.transform(plain, 2654435769);
      expect(scrambled, isNot(plain));
      expect(BigoHlsProtection.transform(scrambled, 2654435769), plain);
    });
  });
}

/// A transport that must not be used: the refusal answers before any request, so
/// a call here is the failure.
final class _NeverHttp implements LiveHttp {
  @override
  Future<LiveResponse> send(LiveRequest request) async => throw StateError('bigo playback asked for ${request.url}');

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}
