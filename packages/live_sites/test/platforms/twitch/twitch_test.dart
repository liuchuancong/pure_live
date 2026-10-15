import 'dart:convert';
import 'dart:math';

// The test doubles spell their class name in their one constructor; the
// shorthand would read as a field declaration at the call site.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_hot_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/internal/built_in_sites.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_gift_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/live_retraction/live_retraction.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/platforms/twitch/api/twitch_endpoints.dart';
import 'package:live_sites/src/platforms/twitch/api/twitch_http.dart';
import 'package:live_sites/src/platforms/twitch/danmaku/twitch_danmaku_codec.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_failure.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_json.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_play_parser.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_room_parser.dart';
import 'package:live_sites/src/platforms/twitch/twitch_site.dart';
import 'package:test/test.dart';

/// The request the fake transport answered, with its body text.
typedef _Seen = ({String method, Uri url, Map<String, String> headers, String body});

/// Answers every request from [onSend] and records each one.
final class _FakeHttp implements LiveHttp {
  _FakeHttp(this.onSend);

  final LiveResponse Function(_Seen request) onSend;
  final List<_Seen> sent = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    sent.add((
      method: request.method,
      url: request.url,
      headers: request.headers,
      body: request.body ?? utf8.decode(request.bodyBytes ?? const <int>[]),
    ));
    return onSend(sent.last);
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: utf8.encode(body));

/// One GraphQL answer envelope, as a parser takes it (already decoded).
Map<String, Object?> _envelope(Map<String, Object?> data) => {'data': data};

/// The same envelope as the JSON text a transport answers with.
String _body(Map<String, Object?> data) => jsonEncode({'data': data});

/// A site over [onSend], with a fixed clock and an injected random source.
TwitchSite _site(LiveResponse Function(_Seen request) onSend, {String cookie = ''}) {
  final http = _FakeHttp(onSend);
  return TwitchSite(
    http: TwitchHttp(http),
    loginCookie: cookie.isEmpty ? null : () => cookie,
    now: () => DateTime.fromMillisecondsSinceEpoch(1760000000000, isUtc: true),
    random: Random(1),
  );
}

/// A site whose every GraphQL call answers [body].
TwitchSite _gqlSite(Object? body, {int status = 200, String cookie = ''}) =>
    _site((request) => _resp(status, request.url.host == 'gql.twitch.tv' ? jsonEncode(body) : ''), cookie: cookie);

/// Throws a [TwitchFailure] of [kind].
Matcher _fails(TwitchFailureKind kind) => predicate((value) => value is TwitchFailure && value.kind == kind);

/// The right value of an [Either] (throws when it is a left).
T _right<T>(Either<Object?, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _left(Either<LiveSiteError, Object?> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $right'));

void main() {
  group('IRC line', () {
    test('tags, prefix, params and the trailing parameter', () {
      final line = TwitchIrcLine.parse(
        '@badge-info=;color=#123456;display-name=Foo :foo!foo@foo.tmi.twitch.tv PRIVMSG #foo :hello there',
      );
      expect(line?.command, 'PRIVMSG');
      expect(line?.prefix, 'foo!foo@foo.tmi.twitch.tv');
      expect(line?.params, ['#foo']);
      expect(line?.trailing, 'hello there');
      expect(line?.tags['color'], '#123456');
      expect(line?.tags['badge-info'], '');
    });

    test('tag values unescape in one IRCv3 pass', () {
      expect(TwitchIrcLine.unescape(r'a\:b\s\c\\d'), r'a;b c\d');
      expect(TwitchIrcLine.unescape('no escapes'), 'no escapes');
      expect(TwitchIrcLine.unescape(r'trailing\'), 'trailing');
    });

    test('a line without a command is not a line', () {
      expect(TwitchIrcLine.parse('@only=tags'), isNull);
      expect(TwitchIrcLine.parse(':only-prefix'), isNull);
    });
  });

  group('danmaku codec', () {
    test('chat, with the name, colour, ids and time', () {
      final message = TwitchDanmakuCodec.chat(
        '@color=#FF0000;display-name=Alice;id=abc-1;tmi-sent-ts=1760000000000;user-id=42'
        r' :alice!alice@alice.tmi.twitch.tv PRIVMSG #chan :Hi\sall',
      );
      expect(message?.type, LiveMessageType.chat);
      expect(message?.text, r'Hi\sall');
      expect(message?.effectiveSender.userName, 'Alice');
      expect(message?.sender?.userId, '42');
      expect(message?.messageId, 'abc-1');
      expect(message?.color, LiveMessageColor.numberToColor(0xFF0000));
      expect(message?.sentAt?.millisecondsSinceEpoch, 1760000000000);
    });

    test('a /me line loses its CTCP wrapper', () {
      const line = ':alice!alice@x PRIVMSG #chan :\u0001ACTION waves\u0001';
      expect(TwitchDanmakuCodec.chat(line)?.text, 'waves');
    });

    test('a cheer is a gift before its chat line', () {
      final frame = TwitchDanmakuCodec.decode('@bits=250;display-name=Alice;id=abc;m1 :alice!x PRIVMSG #chan :cheers');
      final chat = frame.messages.firstWhere((message) => message.type == LiveMessageType.chat);
      final gift = frame.messages.firstWhere((message) => message.type == LiveMessageType.gift);
      expect(gift.effectiveSender.userName, 'Alice');
      expect((gift.payload! as LiveGift).kind, LiveGiftKind.tip);
      expect((gift.payload! as LiveGift).count, 250);
      expect((gift.payload! as LiveGift).value.totalValue, 250);
      expect(gift.messageId, 'abc:bits');
      expect(chat.messageId, 'abc');
    });

    test('CLEARCHAT and CLEARMSG are retractions', () {
      final user = TwitchDanmakuCodec.decode('@target-user-id=7 :tmi.twitch.tv CLEARCHAT #chan :alice');
      expect((user.messages.single.payload! as LiveRetraction).userId, '7');
      final cleared = TwitchDanmakuCodec.decode(':tmi.twitch.tv CLEARCHAT #chan');
      expect((cleared.messages.single.payload! as LiveRetraction).all, isTrue);
      final deleted = TwitchDanmakuCodec.decode('@target-msg-id=m9 :tmi.twitch.tv CLEARMSG #chan :gone');
      expect((deleted.messages.single.payload! as LiveRetraction).messageId, 'm9');
    });

    test('USERNOTICE is a notice, and its words are the viewer chat', () {
      final frame = TwitchDanmakuCodec.decode(
        r'@msg-id=resub;system-msg=Al\sstayed\s2\smonths;display-name=Al;user-id=8;id=n1;tmi-sent-ts=1'
        ' :al!al@al.tmi.twitch.tv USERNOTICE #chan :thanks',
      );
      expect(frame.messages, hasLength(2));
      expect(frame.messages.first.type, LiveMessageType.notice);
      expect(frame.messages.first.text, 'Al stayed 2 months');
      expect(frame.messages.first.payload, LiveNoticeKind.subscription);
      expect(frame.messages.last.type, LiveMessageType.chat);
    });

    test('an announcement notice has no system message, a raid is a raid', () {
      final raid = TwitchDanmakuCodec.decode('@msg-id=raid;system-msg=Raiding :tmi.twitch.tv USERNOTICE #chan');
      expect(raid.messages.single.payload, LiveNoticeKind.raid);
      final announce = TwitchDanmakuCodec.decode('@msg-id=announcement :tmi.twitch.tv USERNOTICE #chan :Hello');
      expect(announce.messages, hasLength(1));
      expect(announce.messages.single.type, LiveMessageType.notice);
      expect(announce.messages.single.text, 'Hello');
    });

    test('a shared chat notice counts as its source message id', () {
      final frame = TwitchDanmakuCodec.decode(
        '@msg-id=sharedchatnotice;source-msg-id=sub;system-msg=Shared :tmi.twitch.tv USERNOTICE #chan',
      );
      expect(frame.messages.single.payload, LiveNoticeKind.subscription);
    });

    test('a server PING is answered, and RECONNECT and a refused login are marked', () {
      final ping = TwitchDanmakuCodec.decode('PING :tmi.twitch.tv');
      expect(ping.replies, ['PONG :tmi.twitch.tv']);
      expect(TwitchDanmakuCodec.decode(':tmi.twitch.tv RECONNECT').reconnect, isTrue);
      expect(TwitchDanmakuCodec.decode(':tmi.twitch.tv NOTICE * :Login authentication failed').loginRejected, isTrue);
      expect(TwitchDanmakuCodec.decode('@a=b; :tmi.twitch.tv NOTICE #chan :slow mode').loginRejected, isFalse);
    });

    test('a community gift marks its notices, with the announcement count', () {
      final frame = TwitchDanmakuCodec.decode(
        '@msg-id=submysterygift;msg-param-community-gift-id=g1;msg-param-mass-gift-count=3;system-msg=Gifted'
        ' :tmi.twitch.tv USERNOTICE #chan\n'
        r'@msg-id=subgift;msg-param-community-gift-id=g1;system-msg=Gifted\sto\sBob'
        ' :tmi.twitch.tv USERNOTICE #chan',
      );
      expect(frame.messages, hasLength(2));
      expect(frame.communityGifts[frame.messages.first]?.announcement, isTrue);
      expect(frame.communityGifts[frame.messages.first]?.count, 3);
      expect(frame.communityGifts[frame.messages.last]?.announcement, isFalse);
    });

    test('the join sends PASS, NICK, CAP REQ and JOIN as separate lines', () {
      final lines = TwitchDanmakuCodec.join('Chan', random: Random(2));
      expect(lines, hasLength(4));
      expect(lines.first, TwitchDanmakuCodec.anonymousPassword);
      expect(lines[1], matches(RegExp(r'^NICK justinfan\d{4,5}$')));
      expect(lines[2], TwitchDanmakuCodec.capabilities);
      expect(lines[3], 'JOIN #chan');
      final logged = TwitchDanmakuCodec.join('chan', random: Random(2), chat: (login: 'user', token: 'tok'));
      expect(logged[0], 'PASS oauth:tok');
      expect(logged[1], 'NICK user');
    });

    test('the chat literals the server expects', () {
      expect(TwitchDanmakuCodec.endpoint.toString(), 'wss://irc-ws.chat.twitch.tv');
      expect(TwitchDanmakuCodec.anonymousPassword, 'PASS SCHMOOPIIE');
      expect(TwitchDanmakuCodec.capabilities, 'CAP REQ :twitch.tv/tags twitch.tv/commands twitch.tv/membership');
      expect(TwitchDanmakuCodec.heartbeat, 'PING :tmi.twitch.tv');
      expect(TwitchDanmakuCodec.heartbeatInterval, const Duration(seconds: 40));
      expect(TwitchDanmakuCodec.inactivityTimeout, const Duration(seconds: 120));
      expect(TwitchDanmakuCodec.maxReconnectAttempts, 8);
      expect(TwitchDanmakuCodec.reconnectStepCap, const Duration(seconds: 6));
      expect(TwitchDanmakuCodec.subscriptionNotices, contains('communitypayforward'));
      expect(TwitchDanmakuCodec.cookieExpiredNotice().text, startsWith('Twitch 的 Cookie 已失效'));
    });
  });

  group('master playlist', () {
    const playlist = '''
#EXTM3U
#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=6000000,RESOLUTION=1280x720,FRAME-RATE=30.000,CODECS="avc1.64001f,mp4a.40.2",VIDEO="1"
https://cdn.example/1.m3u8
#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=12000000,RESOLUTION=1920x1080,FRAME-RATE=60.000,CODECS="hev1.1.6",VIDEO="chunked"
https://cdn.example/2.m3u8
#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=6000000,RESOLUTION=1280x720,FRAME-RATE=30.000,CODECS="avc1.64001f",VIDEO="1"
https://other.example/1.m3u8
''';
    final master = Uri.parse('https://usher.ttvnw.net/api/channel/hls/chan.m3u8?token=t');

    test('grouping, source first, merged hosts, codecs and labels', () {
      final groups = TwitchPlayParser.groups(playlist, master: master);
      expect(groups.map((group) => group.label), ['1080p60（原画）', '720p']);
      expect(groups.last.urls, ['https://cdn.example/1.m3u8', 'https://other.example/1.m3u8']);
      expect(groups.first.codec, LiveStreamCodec.hevc);
      expect(groups.last.codec, LiveStreamCodec.avc);
      expect(groups.last.qualityId, '720:30:6000000:1');

      final qualities = TwitchPlayParser.qualities(groups);
      expect(qualities.map((quality) => quality.label), ['1080p60（原画）', '720p']);
      expect(qualities.first.platformOrder, 2);
    });

    test('lines are HLS, host-labelled, with media headers and no lease', () {
      final group = TwitchPlayParser.groups(playlist, master: master).last;
      final lines = TwitchPlayParser.lines(group, roomId: 'Chan');
      expect(lines, hasLength(2));
      expect(lines.first.format, LiveStreamFormat.hls);
      expect(lines.map((line) => line.lineLabel), ['cdn.example', 'other.example']);
      expect(lines.first.lease, isNull);
      expect(lines.first.headers['referer'], 'https://www.twitch.tv/Chan');
      expect(lines.first.headers.containsKey('cookie'), isFalse);
    });

    test('a quality is matched by id, then by VIDEO group, then by label', () {
      final groups = TwitchPlayParser.groups(playlist, master: master);
      expect(TwitchPlayParser.sameGroup(groups, '720:30:6000000:1')?.qualityId, '720:30:6000000:1');
      expect(TwitchPlayParser.sameGroup(groups, '720:30:9999999:1')?.qualityId, '720:30:6000000:1');
      expect(TwitchPlayParser.sameGroup(groups, 'none', label: '1080p60（原画）')?.label, '1080p60（原画）');
      expect(TwitchPlayParser.sameGroup(groups, null), isNull);
    });

    test('a body that is not a playlist is api-changed, no variant is unavailable', () {
      expect(
        () => TwitchPlayParser.groups('<html></html>', master: master),
        throwsA(_fails(TwitchFailureKind.apiChanged)),
      );
      expect(
        () => TwitchPlayParser.groups('#EXTM3U\n', master: master),
        throwsA(_fails(TwitchFailureKind.streamUnavailable)),
      );
    });

    test('usher 404 is unavailable, 403 geo is region-blocked, 403 else needs a login', () {
      TwitchPlayParser.usherStatus(200, '');
      expect(
        () => TwitchPlayParser.usherStatus(404, '[{"error_code":"unavailable","error":"no stream"}]'),
        throwsA(_fails(TwitchFailureKind.streamUnavailable)),
      );
      expect(
        () => TwitchPlayParser.usherStatus(403, '[{"error_code":"geo_blocked","error":"geo"}]'),
        throwsA(_fails(TwitchFailureKind.regionBlocked)),
      );
      expect(
        () => TwitchPlayParser.usherStatus(403, '[{"error_code":"auth","error":"bad token"}]'),
        throwsA(_fails(TwitchFailureKind.needsLogin)),
      );
      expect(
        () => TwitchPlayParser.usherStatus(403, '[{"error_code":"unauthorized","error":"failed integrity check"}]'),
        throwsA(_fails(TwitchFailureKind.riskControl)),
      );
      expect(
        () => TwitchJson.decode('{"extensions":{"challenge":"https://.twitch.tv/challenge"}}', status: 200, what: 'x'),
        throwsA(_fails(TwitchFailureKind.riskControl)),
      );
      expect(
        () => TwitchJson.decode('{"errors":[{"message":"Please review our Terms"}]}', status: 409, what: 'x'),
        throwsA(_fails(TwitchFailureKind.apiChanged)),
      );
    });
  });

  group('labels and language', () {
    test('the bandwidth ladder names a playlist without a resolution', () {
      expect(TwitchPlayParser.qualityName(9000000, height: 0, frameRate: 0, source: false), '1080P');
      expect(TwitchPlayParser.qualityName(0, height: 0, frameRate: 0, source: true), '原画');
      expect(TwitchPlayParser.qualityName(100, height: 0, frameRate: 0, source: false), '自动');
      expect(TwitchPlayParser.qualityName(1, height: 720, frameRate: 60, source: false), '720p60');
    });

    test('codecs are named as lines name them', () {
      expect(TwitchPlayParser.videoCodec('hev1.1.6,mp4a.40.2'), LiveStreamCodec.hevc);
      expect(TwitchPlayParser.videoCodec('av01.0.08M.08'), LiveStreamCodec.av1);
      expect(TwitchPlayParser.videoCodec('mp4a.40.2'), isNull);
      expect(TwitchEndpoints.supportedCodecs(preferH264: true), 'h264');
      expect(TwitchEndpoints.supportedCodecs(preferH264: false, codecs: {'av1'}), 'av1,h264');
      expect(TwitchEndpoints.supportedCodecs(preferH264: false, codecs: {'hevc'}), 'h265,h264');
    });

    test('languages are upper-cased, joined with an underscore and deduped', () {
      expect(TwitchEndpoints.normalizeLanguages(['zh-cn', 'KO', 'zh_CN', ' ', 'nope-nope-nope']), ['ZH_CN', 'KO']);
    });
  });

  group('room parsing', () {
    final user = {
      'user': {
        'id': '1',
        'login': 'chan',
        'displayName': 'Chan',
        'description': 'Bio',
        'profileImageURL': 'https://p/1.jpg',
        'stream': {
          'id': 's1',
          'title': 'Playing',
          'type': 'live',
          'viewersCount': '1234',
          'createdAt': '2026-09-27T12:49:35Z',
          'previewImageURL': 'https://p/s.jpg',
          'restriction': null,
          'game': {'id': '9', 'name': 'Game', 'displayName': '游戏', 'slug': 'game'},
        },
        'lastBroadcast': {'title': 'Playing'},
      },
    };

    test('the detail carries the asked id, viewers, area and restriction', () {
      final room = TwitchRoomParser.roomDetail(_envelope(user), requestedId: 'Chan', now: DateTime(2026));
      expect(room.roomId, 'Chan');
      expect(room.content.title, 'Playing');
      expect(room.content.introduction, 'Bio');
      expect(room.anchor?.name, 'Chan');
      expect(room.area?.areaId, '9');
      expect(room.area?.areaName, '游戏');
      expect(room.area?.shortName, 'game');
      expect(room.audience.onlineViewers, 1234);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.effectiveRestriction, LiveRestriction.none);
      expect(room.links.webUrl, 'https://www.twitch.tv/Chan');
      expect(room.content.coverUrl, startsWith('https://p/s.jpg?&t='));
    });

    test('an offline channel has no viewers and its profile as cover', () {
      final offline = {
        'user': {...user['user']! as Map<String, Object?>, 'stream': null},
      };
      final room = TwitchRoomParser.roomDetail(_envelope(offline), requestedId: 'chan', now: DateTime(2026));
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.audience.onlineViewers, 0);
      expect(room.broadcast.restriction, isNull);
      expect(room.content.coverUrl, 'https://p/1.jpg');
    });

    test('a rerun is a replay, a subscriber-only stream is restricted', () {
      final stream = user['user']!['stream']! as Map<String, Object?>;
      final rerun = {
        'user': {
          ...user['user']! as Map<String, Object?>,
          'stream': {
            ...stream,
            'type': 'rerun',
            'restriction': {'type': 'SUB_ONLY_LIVE'},
          },
        },
      };
      final room = TwitchRoomParser.roomDetail(_envelope(rerun), requestedId: 'chan', now: DateTime(2026));
      expect(room.broadcast.liveStatus, LiveStatus.replay);
      expect(room.broadcast.effectiveRestriction, LiveRestriction.subscribersOnly);
    });

    test('a channel that is not there is not-found, another login is api-changed', () {
      expect(
        () => TwitchRoomParser.roomDetail(_envelope({'user': null}), requestedId: 'nope', now: DateTime(2026)),
        throwsA(_fails(TwitchFailureKind.notFound)),
      );
      final other = {
        'user': {...user['user']! as Map<String, Object?>, 'login': 'someone-else'},
      };
      expect(
        () => TwitchRoomParser.roomDetail(_envelope(other), requestedId: 'chan', now: DateTime(2026)),
        throwsA(_fails(TwitchFailureKind.apiChanged)),
      );
    });

    test('a list card without a broadcaster is skipped, a rerun is a replay', () {
      final decoded = _envelope({
        'streams': {
          'edges': [
            {
              'cursor': 'c1',
              'node': {
                'title': 'A',
                'type': 'rerun',
                'viewersCount': 10,
                'broadcaster': {'login': 'a', 'displayName': 'A', 'profileImageURL': 'https://a/1.jpg'},
              },
            },
            {
              'cursor': 'c2',
              'node': {'title': 'B'},
            },
          ],
          'pageInfo': {'hasNextPage': true},
        },
      });
      final result = TwitchRoomParser.streams(decoded, now: DateTime(2026));
      expect(result.rooms, hasLength(1));
      expect(result.rooms.single.broadcast.liveStatus, LiveStatus.replay);
      expect(result.cursor, 'c2');
    });

    test('a search card titles itself from its broadcast settings', () {
      final decoded = _envelope({
        'searchFor': {
          'channels': {
            'cursor': 'n1',
            'edges': [
              {
                'item': {
                  'login': 'chan',
                  'displayName': 'Chan',
                  'profileImageURL': 'https://p/1.jpg',
                  'broadcastSettings': {'title': 'Set title'},
                  'lastBroadcast': {'id': 's1', 'startedAt': '2026-09-27T10:00:00Z'},
                  'stream': {
                    'id': 's1',
                    'viewersCount': '5',
                    'game': {'displayName': '游戏'},
                  },
                },
              },
            ],
          },
        },
      });
      final result = TwitchRoomParser.searchPage(decoded, now: DateTime(2026));
      expect(result.rooms.single.content.title, 'Set title');
      expect(result.rooms.single.audience.onlineViewers, 5);
      expect(result.rooms.single.broadcast.startedAt?.toIso8601String(), startsWith('2026-09-27T10:00:00'));
      expect(result.cursor, 'n1');
      expect(TwitchRoomParser.searchPage(_envelope({'searchFor': {}}), now: DateTime(2026)).rooms, isEmpty);
    });

    test('an unknown directory is not-found, a tag keeps the name it was given', () {
      expect(
        () => TwitchRoomParser.gameStreams(_envelope({'game': null}), now: DateTime(2026), slug: 'nope'),
        throwsA(_fails(TwitchFailureKind.notFound)),
      );
      final tags = TwitchRoomParser.tags(
        _envelope({
          'searchCategoryTags': [
            {'id': '1', 'tagName': 'Gambling'},
            {'id': '2', 'localizedName': '中文名'},
            {'id': '3'},
          ],
        }),
      );
      expect(tags, [(id: '1', name: 'Gambling'), (id: '2', name: '中文名'), (id: '3', name: '')]);
    });

    test('directories name their areas and hand back the cursor', () {
      final areas = TwitchRoomParser.directories(
        {
          'data': {
            'directoriesWithTags': {
              'edges': [
                {
                  'node': {'id': '9', 'slug': 'game', 'displayName': '游戏', 'avatarURL': 'https://a'},
                },
              ],
              'pageInfo': {'hasNextPage': true, 'endCursor': 'c'},
            },
          },
        },
        (id: 'tag', name: 'Tag'),
      ).areas;
      expect(areas.single.areaId, '9');
      expect(areas.single.shortName, 'game');
      expect(areas.single.parentAreaName, 'Tag');
    });
  });

  group('transport', () {
    test('gql headers carry the client id, a 32-digit device id and the OAuth token', () {
      final site = _site((_) => _resp(200, _body({'user': null})), cookie: 'login=Chan; auth-token=TOK');
      final headers = site.gqlHeaders(cookie: site.login());
      expect(headers['client-id'], TwitchEndpoints.clientId);
      expect(headers['device-id'], matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(headers['authorization'], 'OAuth TOK');
      expect(headers['cookie'], 'login=Chan; auth-token=TOK');
      expect(headers['accept'], 'application/vnd.twitchtv.v5+json');
      expect(headers['accept-language'], 'en-US,en;q=0.9');
      expect(headers['origin'], 'https://www.twitch.tv');
      expect(headers['referer'], 'https://www.twitch.tv/');
      expect(headers['content-type'], 'text/plain;charset=UTF-8');
      expect(
        headers['user-agent'],
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36',
      );
      expect(TwitchEndpoints.clientId, 'kimne78kx3ncx6brgo4mv6wki5h1ko');
      expect(TwitchEndpoints.deviceId(Random(1)), matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('the GraphQL bodies carry their operation names and hashes', () {
      String? hashOf(Map<String, Object?> operation) => TwitchJson.textOf(
        ((operation['extensions']! as Map<String, Object?>)['persistedQuery']! as Map)['sha256Hash'],
      );
      final search = TwitchEndpoints.searchOperation('k');
      expect(search['operationName'], 'SearchResultsPage_SearchResults');
      expect(hashOf(search), '7f3580f6ac6cd8aa1424cff7c974a07143827d6fa36bba1b54318fe7f0b68dc5');
      expect(
        search['variables'],
        allOf(
          containsPair('platform', 'web'),
          containsPair('query', 'k'),
          containsPair('requestID', '808c9f2e-f52e-431c-8dc7-d2e3c1831d77'),
          containsPair('includeIsDJ', true),
        ),
      );
      expect((search['variables']! as Map)['options'], containsPair('shouldSkipDiscoveryControl', false));
      final next = TwitchEndpoints.searchOperation('k', cursor: 'c1');
      expect(
        (next['variables']! as Map)['options'],
        containsPair('targets', [
          {'index': 'CHANNEL', 'cursor': 'c1'},
        ]),
      );
      final tags = TwitchEndpoints.tagsOperation();
      expect(tags['operationName'], 'SearchCategoryTags');
      expect(hashOf(tags), 'b4cb189d8d17aadf29c61e9d7c7e7dcfc932e93b77b3209af5661bffb484195f');
      expect(tags['variables'], {'userQuery': '', 'limit': 100});
      final directories = TwitchEndpoints.directoriesOperation('t9');
      expect(directories['operationName'], 'BrowsePage_AllDirectories');
      expect(hashOf(directories), '2f67f71ba89f3c0ed26a141ec00da1defecb2303595f5cda4298169549783d9e');
      expect(directories['variables'], containsPair('limit', 30));
      expect(
        (directories['variables']! as Map)['options'],
        allOf(containsPair('tags', ['t9']), containsPair('sort', 'VIEWER_COUNT')),
      );
      final game = TwitchEndpoints.gameOperation('slug', limit: 100);
      expect(game['operationName'], 'DirectoryPage_Game');
      expect(hashOf(game), '76cb069d835b8a02914c08dc42c421d0dafda8af5b113a3f19141824b901402f');
      expect(game['variables'], allOf(containsPair('slug', 'slug'), containsPair('limit', 100)));
      expect(game['variables'], containsPair('includeCostreaming', true));
      expect(game['variables'], containsPair('sortTypeIsRecency', false));
      final token = TwitchEndpoints.accessTokenOperation('chan');
      expect(token['operationName'], 'PlaybackAccessToken');
      expect(hashOf(token), 'ed230aa1e33e07eebb8928504583da78a5173989fadfb1ac94be06a04f3cdbe9');
      expect(token['variables'], allOf(containsPair('login', 'chan'), containsPair('playerType', 'site')));
      final user = TwitchEndpoints.userOperation('chan');
      expect(user['query'], allOf(contains(r'query($login: String!)'), contains('profileImageURL(width: 300)')));
      expect(user['variables'], {'login': 'chan'});
      final streams = TwitchEndpoints.streamsOperation(limit: 30);
      expect(
        streams['query'],
        allOf(contains(r'$languages: [Language!]'), contains(r'broadcasterLanguages: $languages')),
      );
      expect(streams['variables'], containsPair('first', 30));
    });

    test('an access token refuses a forbidden claim', () {
      final claims = jsonEncode({
        'authorization': {'viewers': 10, 'forbidden': true, 'reason': 'Not permitted by geo restrictions'},
      });
      expect(
        () => TwitchRoomParser.accessToken(
          _envelope({
            'streamPlaybackAccessToken': {'value': claims, 'signature': 'sig'},
          }),
          login: 'chan',
        ),
        throwsA(_fails(TwitchFailureKind.regionBlocked)),
      );
      final allowed = jsonEncode({
        'authorization': {'forbidden': false},
      });
      final token = TwitchRoomParser.accessToken(
        _envelope({
          'streamPlaybackAccessToken': {'value': allowed, 'signature': 'sig'},
        }),
        login: 'chan',
      );
      expect(token.signature, 'sig');
    });

    test('a persisted query that is no longer known is api-changed', () {
      expect(
        () => TwitchRoomParser.tags({
          'errors': [
            {'message': 'PersistedQueryNotFound'},
          ],
        }),
        throwsA(_fails(TwitchFailureKind.apiChanged)),
      );
    });

    test('the answer statuses name the failure that follows', () {
      expect(
        TwitchJson.isIntegrityRejection({
          'extensions': {'challenge': 'x'},
        }),
        isTrue,
      );
      expect(
        TwitchJson.isIntegrityRejection([
          {
            'errors': [
              {'message': 'failed integrity check'},
            ],
          },
        ]),
        isTrue,
      );
      expect(TwitchJson.isIntegrityRejection({'data': <String, Object?>{}}), isFalse);
      expect(
        () => TwitchJson.decode('{</content>', status: 200, what: 'x'),
        throwsA(_fails(TwitchFailureKind.apiChanged)),
      );
      expect(() => TwitchJson.decode('{}', status: 429, what: 'x'), throwsA(_fails(TwitchFailureKind.rateLimited)));
      expect(() => TwitchJson.decode('{}', status: 401, what: 'x'), throwsA(_fails(TwitchFailureKind.needsLogin)));
      expect(() => TwitchJson.decode('{}', status: 503, what: 'x'), throwsA(_fails(TwitchFailureKind.network)));
    });

    test('usher asks for the web player parameters and the codec preference', () {
      final url = TwitchEndpoints.usherUrl(
        'chan',
        value: 'V',
        signature: 'S',
        random: Random(4),
        preferH264: false,
        codecs: {'av1'},
      );
      expect(url.path, '/api/channel/hls/chan.m3u8');
      expect(url.queryParameters['token'], 'V');
      expect(url.queryParameters['sig'], 'S');
      expect(url.queryParameters['supported_codecs'], 'av1,h264');
      expect(url.queryParameters['acmb'], 'e30=');
      expect(url.queryParameters['player_version'], '1.28.0-rc.1');
      expect(TwitchEndpoints.playSessionIds, contains(url.queryParameters['play_session_id']));
    });
  });

  group('adapter wiring', () {
    test('the seven capabilities are wired, the rest are not', () {
      final site = _gqlSite(const {'data': <String, Object?>{}});
      expect(site.manifest.id, 'twitch');
      expect(site.capability<LiveRoomProvider>(), isNotNull);
      expect(site.capability<LiveAreaProvider>(), isNotNull);
      expect(site.capability<LiveDiscoveryProvider>(), isNotNull);
      expect(site.capability<LiveSearchProvider>(), isNotNull);
      expect(site.capability<LivePlaybackProvider>(), isNotNull);
      expect(site.capability<LiveDanmakuProvider>(), isNotNull);
      expect(site.capability<LiveLinkResolver>(), isNotNull);
      expect(site.capability<LiveHotProvider>(), isNull);
      expect(site.capability<LiveRoomProvider>(), same(site.capability<LiveRoomProvider>()));
      final built = createBuiltInLiveSites(http: _FakeHttp((_) => _resp(200, '{}')));
      expect(built.map((entry) => entry.manifest.id), [
        'douyu',
        'huya',
        'douyin',
        'bilibili',
        'kuaishou',
        'youtube',
        'twitch',
        'acfun',
        'bigo',
        'cc',
        'chzzk',
        'fc2live',
        'kick',
        'niconico',
        'picarto',
        'looklive',
        'inke',
        'jdlive',
        'kilakila',
        'kugoulive',
        'missevan',
        'pandalive',
        'showroom',
        'sixroom',
        'liveme',
        'xiaohongshu',
        'yy',
        'tiktok',
        'soop',
        'twitcasting',
      ]);
    });

    test('a room read sends the user query and keeps the asked login', () async {
      final seen = <_Seen>[];
      final site = _site((request) {
        seen.add(request);
        return _resp(
          200,
          _body({
            'user': {
              'login': 'chan',
              'displayName': 'Chan',
              'description': '',
              'profileImageURL': 'https://p/1.jpg',
              'stream': null,
              'lastBroadcast': {'title': 'Off'},
            },
          }),
        );
      });
      final room = _right(await site.capability<LiveRoomProvider>()!.getRoom('Chan'));
      expect(room.roomId, 'Chan');
      expect(room.broadcast.isLiveNow, isFalse);
      expect(seen.single.url.host, 'gql.twitch.tv');
      expect(seen.single.method, 'POST');
      expect(seen.single.headers['client-id'], TwitchEndpoints.clientId);
      expect(seen.single.headers['device-id'], matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('a link is canonicalized, an alien host is unsupported, a site page is not a channel', () async {
      final site = _gqlSite(const {'data': <String, Object?>{}});
      final resolver = site.capability<LiveLinkResolver>()!;
      expect(
        _right(await resolver.resolve(Uri.parse('https://m.twitch.tv/Chan'))).toString(),
        'https://www.twitch.tv/Chan',
      );
      expect(
        _right(await resolver.resolve(Uri.parse('https://www.twitch.tv/popout/Chan/chat'))).toString(),
        'https://www.twitch.tv/Chan',
      );
      expect(
        _right(await resolver.resolve(Uri.parse('https://player.twitch.tv/?channel=chan'))).toString(),
        'https://www.twitch.tv/chan',
      );
      expect(
        _left(await resolver.resolve(Uri.parse('https://www.youtube.com/watch?v=1'))).toString(),
        contains('unsupported'),
      );
      expect(
        _left(await resolver.resolve(Uri.parse('https://www.twitch.tv/drops'))).toString(),
        contains('no channel'),
      );
      for (final page in ['directory', 'videos', 'search', 'games']) {
        expect(
          _left(await resolver.resolve(Uri.parse('https://www.twitch.tv/$page/1'))).toString(),
          contains('no channel'),
          reason: page,
        );
      }
      expect(
        _right(await resolver.resolve(Uri.parse('https://go.twitch.tv/Chan/videos'))).toString(),
        'https://www.twitch.tv/Chan',
      );
    });

    test('a search target the site does not search is unsupported', () async {
      final site = _gqlSite(const {'data': <String, Object?>{}});
      final search = site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, const {LiveSearchTarget.rooms});
      expect(
        _left(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.areas))).toString(),
        contains('unsupported'),
      );
    });

    test('a blank keyword and a page past the last cursor ask for nothing', () async {
      final calls = <String>[];
      final site = _site((request) {
        calls.add(request.body);
        return _resp(
          200,
          _body({
            'searchFor': {
              'channels': <String, Object?>{'edges': const <Object?>[], 'cursor': null},
            },
          }),
        );
      });
      final search = site.capability<LiveSearchProvider>()!;
      expect(
        _right(await search.search(const LiveSearchRequest(query: ' ', target: LiveSearchTarget.rooms))).items,
        isEmpty,
      );
      expect(calls, isEmpty);
      expect(
        _right(await search.search(const LiveSearchRequest(query: 'a', target: LiveSearchTarget.rooms, page: 3))).items,
        isEmpty,
      );
      expect(calls, isEmpty);
    });

    test('an offline room is content-unavailable for playback, not an empty list', () async {
      final site = _site(
        (request) => request.url.host == 'gql.twitch.tv'
            ? _resp(
                200,
                _body({
                  'user': {'login': 'chan', 'stream': null, 'profileImageURL': '', 'displayName': 'Chan'},
                }),
              )
            : _resp(404, '[{"error_code":"unavailable","error":"no stream"}]'),
      );
      final error = _left(await site.capability<LivePlaybackProvider>()!.getQualities(roomId: 'chan'));
      expect(error, isA<LiveSiteContentUnavailable>());
    });

    test('an integrity challenge ends a list quietly on a later page', () async {
      var first = true;
      final site = _site((request) {
        if (first) {
          first = false;
          return _resp(
            200,
            _body({
              'streams': {
                'edges': [
                  {
                    'cursor': 'c1',
                    'node': {
                      'title': 'A',
                      'viewersCount': 1,
                      'broadcaster': {'login': 'a', 'displayName': 'A'},
                    },
                  },
                ],
                'pageInfo': {'hasNextPage': true},
              },
            }),
          );
        }
        return _resp(
          200,
          jsonEncode({
            'errors': [
              {'message': 'failed integrity check'},
            ],
          }),
        );
      });
      final discovery = site.capability<LiveDiscoveryProvider>()!;
      expect(_right(await discovery.getRecommendedRooms()).items, hasLength(1));
      expect(_right(await discovery.getRecommendedRooms(request: const LivePageRequest(page: 2))).items, isEmpty);
    });
  });
}
