import 'dart:convert';

import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/kuaishou/capabilities/kuaishou_link_resolver.dart';
import 'package:live_sites/src/platforms/kuaishou/danmaku/kuaishou_danmaku_codec.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_play_parser.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_room_parser.dart';
import 'package:test/test.dart';

/// A Kuaishou comment-feed answer wrapped the way the mobile endpoint sends it:
/// a JSON object inside a JSON string (the feed double-encodes).
String feedJson({required int result, List<Object?> feeds = const [], String watching = '', int? pullSeconds}) =>
    jsonEncode(
      jsonEncode({
        'result': result,
        'currentWatchingCount': watching,
        'pullCycleSeconds': ?pullSeconds,
        'cursor': 'c-1',
        'liveStreamFeeds': feeds,
      }),
    );

Object? comment({
  String type = 'comment',
  String content = 'hi',
  String user = 'X',
  String uid = 'u1',
  int time = 1700000000000,
  String? id,
}) => {
  'type': type,
  'content': content,
  'time': time,
  'id': ?id,
  'author': {'userName': user, 'userId': uid},
};

void main() {
  group('KuaishouDanmakuCodec', () {
    test('parse unwraps the double-encoded feed into comments and the audience', () {
      final batch = KuaishouDanmakuCodec.parse(
        feedJson(
          result: 1,
          watching: '1234',
          pullSeconds: 5,
          feeds: [comment(id: 'e1')],
        ),
      );
      expect(batch.onlineViewers, 1234);
      expect(batch.cursor, 'c-1');
      expect(batch.pullDelay, const Duration(seconds: 5));
      final chat = batch.messages.single;
      expect(chat.type, LiveMessageType.chat);
      expect(chat.text, 'hi');
      expect(chat.effectiveSender.userName, 'X');
      expect(chat.messageId, 'kuaishou:e1');
      // reported leads with the audience figure, then the comments.
      expect(batch.reported.first.type, LiveMessageType.audienceUpdate);
      expect(batch.reported.first.payload, isA<LiveAudienceUpdate>());
      expect(batch.reported.last, same(chat));
    });

    test('a blank watching count yields no audience message', () {
      final batch = KuaishouDanmakuCodec.parse(feedJson(result: 1, feeds: [comment()]));
      expect(batch.onlineViewers, isNull);
      expect(batch.reported, hasLength(1));
    });

    test('only comment entries with text become messages', () {
      final batch = KuaishouDanmakuCodec.parse(
        feedJson(
          result: 1,
          feeds: [
            comment(type: 'like'),
            comment(content: ''),
            comment(content: 'ok'),
          ],
        ),
      );
      expect(batch.messages.map((m) => m.text), ['ok']);
    });

    test('a rejected result throws KuaishouFeedRejected', () {
      expect(() => KuaishouDanmakuCodec.parse(feedJson(result: 2)), throwsA(isA<KuaishouFeedRejected>()));
    });

    test('a comment code found in the emoji table becomes an emote', () {
      final batch = KuaishouDanmakuCodec.parse(
        feedJson(result: 1, feeds: [comment(content: '高兴[笑哭]再见[笑哭][未知]')]),
        emotes: {'[笑哭]': 'https://ali2.a.yximgs.com/e/laugh.png'},
      );
      final chat = batch.messages.single;
      expect(chat.emotes.map((e) => e.code), ['[笑哭]']);
      expect(chat.emotes.single.url, 'https://ali2.a.yximgs.com/e/laugh.png');
    });

    test('no emoji table leaves a message without emotes', () {
      final batch = KuaishouDanmakuCodec.parse(feedJson(result: 1, feeds: [comment(content: 'hi[笑哭]')]));
      expect(batch.messages.single.emotes, isEmpty);
    });

    test('query carries the live stream id and only an existing cursor', () {
      expect(KuaishouDanmakuCodec.query('LS1', ''), {'liveStreamId': 'LS1'});
      expect(KuaishouDanmakuCodec.query('LS1', 'abc'), {'liveStreamId': 'LS1', 'cursor': 'abc'});
    });

    test('backoff is 1,2,4,8 then capped at 8 seconds', () {
      expect(KuaishouDanmakuCodec.backoff(1), const Duration(seconds: 1));
      expect(KuaishouDanmakuCodec.backoff(2), const Duration(seconds: 2));
      expect(KuaishouDanmakuCodec.backoff(3), const Duration(seconds: 4));
      expect(KuaishouDanmakuCodec.backoff(5), const Duration(seconds: 8));
    });
  });

  group('KuaishouPlayParser', () {
    final issuedAt = DateTime.utc(2026, 1, 1, 12);

    test('a txTime hex lease expires and refreshes ahead', () {
      final expiry = issuedAt.millisecondsSinceEpoch ~/ 1000 + 3600;
      final url = Uri.parse('https://p.example.com/a_AvcSd.flv?txTime=${expiry.toRadixString(16).toUpperCase()}');
      final lease = KuaishouPlayParser.lease(url, issuedAt);
      expect(lease, isNotNull);
      expect(lease!.expiresAt, issuedAt.add(const Duration(hours: 1)));
      // refresh leads by min(10 min, lifetime/4): lifetime 1h -> lead 10 min.
      expect(lease.refreshAt, lease.expiresAt!.subtract(const Duration(minutes: 10)));
    });

    test('an auth_key time lease is read', () {
      final expiry = issuedAt.millisecondsSinceEpoch ~/ 1000 + 600;
      final url = Uri.parse('https://p.example.com/a_AvcSd.flv?auth_key=$expiry-0-0-abcd');
      expect(KuaishouPlayParser.lease(url, issuedAt)?.expiresAt, issuedAt.add(const Duration(minutes: 10)));
    });

    test('a URL with no expiry has no lease', () {
      expect(KuaishouPlayParser.lease(Uri.parse('https://p.example.com/a.flv'), issuedAt), isNull);
    });

    test('qualities and lines come from the h264/hevc representation sets', () {
      final playUrls = {
        'h264': {
          'adaptationSet': {
            'representation': [
              {'url': 'https://p.example.com/a_AvcSdL1.flv', 'level': 2, 'bitrate': 2000, 'name': '高清'},
            ],
          },
        },
        'hevc': {
          'adaptationSet': {
            'representation': [
              {'url': 'https://p.example.com/a_HevcHdL1.m3u8', 'level': 3, 'bitrate': 4000, 'name': '超清'},
            ],
          },
        },
      };
      final qualities = KuaishouPlayParser.qualities(playUrls);
      expect(qualities.length, greaterThanOrEqualTo(2));
      final lines = KuaishouPlayParser.lines(playUrls, roomId: 'abc', issuedAt: issuedAt);
      expect(lines, isNotEmpty);
      expect(lines.any((l) => l.url.endsWith('.flv')), isTrue);
      expect(lines.every((l) => l.url.startsWith('https://')), isTrue);
    });

    test('mediaHeaders carry UA, origin and the room referer', () {
      final headers = KuaishouPlayParser.mediaHeaders('abc');
      expect(headers['referer'], 'https://live.kuaishou.com/u/abc');
      expect(headers['origin'], 'https://live.kuaishou.com');
      expect(headers['user-agent'], isNotEmpty);
    });
  });

  group('KuaishouLinkResolver', () {
    test('a /u/{id} path yields the room id, other shapes are null', () {
      expect(KuaishouLinkResolver.roomIdOf(['u', 'kuaishouuser']), 'kuaishouuser');
      expect(KuaishouLinkResolver.roomIdOf(['U', '3dABC123']), '3dABC123');
      expect(KuaishouLinkResolver.roomIdOf(['profile', 'x']), isNull);
      expect(KuaishouLinkResolver.roomIdOf(['u']), isNull);
    });
  });

  group('KuaishouRoomParser', () {
    test('sessionCookies keeps the identity cookies from the response headers', () {
      final cookies = KuaishouRoomParser.sessionCookies({
        'set-cookie': 'did=abc123; Path=/; client_key=k1; kpn=KEY; sessionid=x',
      });
      expect(cookies['did'], 'abc123');
      expect(cookies['client_key'], 'k1');
    });

    test('roomDetail reads the live stream id and page streams from the RSC state', () {
      final state = {
        'liveroom': {
          'playList': [
            {
              'isLiving': true,
              'author': {
                'name': '主播',
                'avatar': 'http://a.jpg',
                'counts': {'fan': '10'},
                'description': '简介',
              },
              'liveStream': {
                'id': 'LS-99',
                'poster': 'http://c.jpg',
                'playUrls': {
                  'h264': {
                    'adaptationSet': {
                      'representation': [
                        {'url': 'https://p.example.com/a_AvcSdL1.flv', 'level': 1, 'name': '标清'},
                      ],
                    },
                  },
                },
              },
              'gameInfo': {'name': '网游'},
            },
          ],
        },
        'pcConfig': {
          'pcConfig': {
            'config': {
              'pcLive.webConfig.emojiPanel': {
                '[笑哭]': '//ali2.a.yximgs.com/bs2/emotion/laugh.png',
                'not_a_code': 'https://ali2.a.yximgs.com/bs2/emotion/x.png',
                '[空]': '',
              },
            },
          },
        },
      };
      final html = '<html>window.__INITIAL_STATE__ = ${jsonEncode(state)};</html>';
      final parsed = KuaishouRoomParser.roomDetail(html, requestedId: 'someone');
      expect(parsed.liveStreamId, 'LS-99');
      expect(parsed.playUrls, isNotNull);
      expect(parsed.room, isNotNull);
      // A code that is not […] and an entry without an address are skipped.
      expect(parsed.emotes, {'[笑哭]': 'https://ali2.a.yximgs.com/bs2/emotion/laugh.png'});
    });
  });
}
