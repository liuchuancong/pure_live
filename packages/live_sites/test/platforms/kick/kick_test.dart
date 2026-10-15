import 'dart:convert';

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
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/live_retraction/live_retraction.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/kick/api/kick_endpoints.dart';
import 'package:live_sites/src/platforms/kick/api/kick_http.dart';
import 'package:live_sites/src/platforms/kick/capabilities/kick_area_provider.dart';
import 'package:live_sites/src/platforms/kick/capabilities/kick_link_resolver.dart';
import 'package:live_sites/src/platforms/kick/capabilities/kick_playback_provider.dart';
import 'package:live_sites/src/platforms/kick/capabilities/kick_room_provider.dart';
import 'package:live_sites/src/platforms/kick/capabilities/kick_search_provider.dart';
import 'package:live_sites/src/platforms/kick/danmaku/kick_danmaku_codec.dart';
import 'package:live_sites/src/platforms/kick/kick_site.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_failure.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_json.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_play_parser.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_room_parser.dart';
import 'package:test/test.dart';

/// The request the fake transport answered, with its URL and headers.
typedef _Seen = ({String method, Uri url, Map<String, String> headers});

/// Answers every request from [onSend] and records each one.
final class _FakeHttp implements LiveHttp {
  _FakeHttp(this.onSend);

  final LiveResponse Function(_Seen request) onSend;
  final List<_Seen> sent = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    sent.add((method: request.method, url: request.url, headers: request.headers));
    return onSend(sent.last);
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: utf8.encode(body));

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _left<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left'));

/// A playback token JWT whose payload says it dies at [exp] (Unix seconds).
String _jwt(int exp) =>
    'eyJ0eXAiOiJKV1QiLCJhbGciOiJFUzM4NCJ9.${base64Url.encode(utf8.encode(jsonEncode({'exp': exp})))}.c2ln';

const int _exp = 1893456000; // 2030-01-01T00:00:00Z
final DateTime _expiry = DateTime.utc(2030);

/// The live channel answer of `xqc` (channel 668, chatroom 668 kept distinct
/// below; the recorded shapes of `fixtures/kick/S05-channel-live`).
String _channelLive({String slug = 'xqc', int id = 668, int chatroom = 101689, bool mature = true}) => jsonEncode({
  'id': id,
  'slug': slug,
  'is_banned': false,
  'followers_count': '1117677',
  'playback_url':
      'https://fa723fc1b171.us-west-2.playback.live-video.net/api/video/v1/channel.m3u8?token=${_jwt(_exp)}',
  'user': {'id': 676, 'username': 'xQc', 'profile_pic': 'https://files.kick.com/avatar.png', 'bio': 'THE JUICER'},
  'chatroom': {'id': chatroom},
  'livestream': {
    'id': 129925755,
    'is_live': true,
    'viewer_count': 45000,
    'session_title': 'reacting',
    'start_time': '2026-10-01 05:00:00',
    'is_mature': mature,
    'thumbnail': {'url': 'https://images.kick.com/thumb.jpg'},
    'categories': [
      {'id': 518, 'name': 'Just Chatting', 'slug': 'just-chatting'},
    ],
  },
});

/// The offline channel answer of `xqcisoffline`: `playback_url` carries only
/// the token, and no `livestream` is there (`fixtures/kick/S05-channel-offline`).
const String _channelOffline =
    '{"id":101691,"slug":"xqcisoffline","is_banned":false,"followers_count":70000,'
    '"playback_url":"?token=eyJ0eXAiOiJKV1QifQ.c2lnature.c2ln",'
    '"user":{"id":102847,"username":"xQcIsOffline","profile_pic":"https://files.kick.com/offline.png","bio":""},'
    '"chatroom":{"id":101689},'
    '"offline_banner_image":{"src":"https://files.kick.com/offline_banner.jpg"}}';

/// The IVS master playlist (`fixtures/kick/S06-master`), renditions first.
const String _masterPlaylist = '''
#EXTM3U
#EXT-X-SESSION-DATA:DATA-ID="NODE",VALUE="fa723fc1b171"
#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID="720p60",NAME="720p60",AUTOSELECT=YES,DEFAULT=YES
#EXT-X-STREAM-INF:BANDWIDTH=3422999,RESOLUTION=1280x720,CODECS="avc1.4D401F,mp4a.40.2",VIDEO="720p60",FRAME-RATE=60.000
/v1/playlist/720.m3u8
#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID="480p30",NAME="480p",AUTOSELECT=YES,DEFAULT=YES
#EXT-X-STREAM-INF:BANDWIDTH=1427999,RESOLUTION=852x480,CODECS="avc1.4D401F,mp4a.40.2",VIDEO="480p30",FRAME-RATE=30.000
/v1/playlist/480.m3u8
#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID="chunked",NAME="1080p60",AUTOSELECT=YES,DEFAULT=YES
#EXT-X-STREAM-INF:BANDWIDTH=9054133,RESOLUTION=1920x1080,CODECS="avc1.64002A,mp4a.40.2",VIDEO="chunked",FRAME-RATE=60.000
/v1/playlist/1080.m3u8
#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID="160p30",NAME="160p",AUTOSELECT=YES,DEFAULT=YES
#EXT-X-STREAM-INF:BANDWIDTH=230000,RESOLUTION=284x160,CODECS="hev1.1.6.L93.90",VIDEO="160p30",FRAME-RATE=30.000
/v1/playlist/160.m3u8
''';

/// One directory row of the live list (a card of `fixtures/kick/S02`).
Map<String, Object?> _directoryRow({
  String slug = 'aquino',
  int channelId = 6332619,
  String subcategory = 'tickets-please',
  bool live = true,
  int? viewers = 33282,
}) => {
  'id': 129936320,
  'channel_id': channelId,
  'session_title': 'DEDsafioMinecraft4 | Dia 9',
  'is_live': live,
  'start_time': '2026-09-30 20:34:25',
  'is_mature': false,
  'viewer_count': viewers,
  'show_view_count': true,
  'thumbnail': {'src': 'https://images.kick.com/k9.jpg'},
  'categories': [
    {'id': 14353, 'name': 'Tickets, Please', 'slug': subcategory},
  ],
  'channel': {
    'id': channelId,
    'slug': slug,
    'is_banned': false,
    'user': {'id': 6425882, 'username': 'AQUINO', 'profile_pic': 'https://files.kick.com/a.png'},
  },
};

/// The chat arguments of the recorded `lonche` room.
const _args = KickDanmakuArgs(chatroomId: 3852600, channelId: 3862536, slug: 'lonche');

/// One Pusher frame: [event] on [channel] with its payload as a JSON string.
String _frame(String event, Object? payload, {String? channel}) =>
    jsonEncode({'event': event, 'channel': ?channel, 'data': payload is String ? payload : jsonEncode(payload)});

/// The live chat payload of `fixtures/kick/danmaku/S07-chat` (trimmed):
/// color, the `level` badge and an inline emote.
Map<String, Object?> _chatPayload({String content = 'hello [emote:1875:KEKW] world'}) => {
  'id': '07a12fcc-26c5-438a-b0be-dfdb0311d89c',
  'chatroom_id': 3852600,
  'content': content,
  'type': 'message',
  'created_at': '2026-10-01T05:42:02+00:00',
  'sender': {
    'id': 22790126,
    'username': 'xlgzifu',
    'identity': {
      'color': '#BDFF28',
      'badges_v2': [
        {
          'name': 'level',
          'metadata': {'level': 37},
        },
      ],
    },
  },
};

void main() {
  group('Pusher frames', () {
    test("the endpoint and the app key are Kick's", () {
      expect(
        '${KickDanmakuCodec.endpoint}',
        'wss://ws-us2.pusher.com/app/32cbd69e4b950bf97679?protocol=7&client=js&version=8.4.0&flash=false',
      );
      expect(KickEndpoints.socketHeaders['origin'], 'https://kick.com');
      expect(KickEndpoints.socketHeaders['user-agent'], contains('Chrome/140.0.0.0'));
    });

    test('a subscription is the recorded JSON literal', () {
      expect(
        KickDanmakuCodec.subscribe('chatrooms.3852600.v2'),
        '{"event":"pusher:subscribe","data":{"auth":"","channel":"chatrooms.3852600.v2"}}',
      );
      expect(KickDanmakuCodec.chatChannel(_args), 'chatrooms.3852600.v2');
      expect(KickDanmakuCodec.broadcastChannel(_args), 'channel.3862536');
      expect(KickDanmakuCodec.kicksChannel(_args), 'channel_3862536');
      expect(KickDanmakuCodec.subscribeAll(_args).length, 3);
    });

    test('the client ping is the Pusher shape', () {
      expect(KickDanmakuCodec.ping, '{"event":"pusher:ping","data":{}}');
      expect(KickDanmakuCodec.pong, '{"event":"pusher:pong","data":{}}');
    });

    test('connection_established opens, subscription_succeeded of the chat joins', () {
      final opened = KickDanmakuCodec.read(
        _frame('pusher:connection_established', {'socket_id': '1', 'activity_timeout': 120}),
        _args,
      );
      expect(opened.established, isTrue);
      final joined = KickDanmakuCodec.read(
        _frame('pusher_internal:subscription_succeeded', {}, channel: KickDanmakuCodec.chatChannel(_args)),
        _args,
      );
      expect(joined.joined, isTrue);
      final other = KickDanmakuCodec.read(
        _frame('pusher_internal:subscription_succeeded', {}, channel: KickDanmakuCodec.broadcastChannel(_args)),
        _args,
      );
      expect(other.joined, isFalse);
    });

    test('server pings are answered and errors reconnect', () {
      expect(KickDanmakuCodec.read(_frame('pusher:ping', {}), _args).ping, isTrue);
      final error = KickDanmakuCodec.read(
        _frame('pusher:error', {'message': 'connection exceeded flow control'}),
        _args,
      );
      expect(error.error, contains('connection exceeded flow control'));
      final timeout = KickDanmakuCodec.read(_frame('activity_timeout', {}), _args);
      expect(timeout.error, isNotNull);
    });

    test('a ChatMessageEvent decodes color, level, emote and the kick-prefixed id', () {
      final frame = KickDanmakuCodec.read(
        _frame(r'App\Events\ChatMessageEvent', _chatPayload(), channel: KickDanmakuCodec.chatChannel(_args)),
        _args,
      );
      final message = frame.messages.single;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, 'hello KEKW world');
      expect(message.messageId, 'kick:07a12fcc-26c5-438a-b0be-dfdb0311d89c');
      expect(message.sender?.userName, 'xlgzifu');
      expect(message.sender?.userId, '22790126');
      expect(message.sender?.userLevel, '37');
      expect(message.color, const LiveMessageColor(189, 255, 40));
      expect(message.sentAt, DateTime.utc(2026, 10, 1, 5, 42, 2));
    });

    test('a line of another chatroom or of no text is dropped', () {
      final other = Map<String, Object?>.from(_chatPayload())..['chatroom_id'] = 1;
      expect(KickDanmakuCodec.message(other, _args), isNull);
      expect(KickDanmakuCodec.message(_chatPayload(content: '   '), _args), isNull);
    });

    test('KicksGifted on the kicks channel is a gift', () {
      final frame = KickDanmakuCodec.read(
        _frame('KicksGifted', {
          'sender': {'id': 7, 'username': 'giver'},
          'gift': {'name': 'Kick', 'amount': 50, 'pinned_time': 60},
          'message': '',
          'gift_transaction_id': 'tx-1',
          'created_at': 1759330000,
        }, channel: KickDanmakuCodec.kicksChannel(_args)),
        _args,
      );
      final message = frame.messages.single;
      expect(message.type, LiveMessageType.gift);
      expect(message.text, 'Kick ×1');
      expect(message.messageId, 'kick:tx-1');
      final gift = message.payload! as LiveGift;
      expect(gift.name, 'Kick');
      expect(gift.value.unit, LiveGiftUnit.gold);
      expect(gift.value.unitPrice, 50);
      expect(gift.value.totalValue, 50);
    });

    test('Kicks with a message is a super chat kept for its pinned_time', () {
      final frame = KickDanmakuCodec.read(
        _frame('KicksGifted', {
          'sender': {'id': 7, 'username': 'giver'},
          'gift': {'name': 'Kick', 'amount': 500, 'pinned_time': 60},
          'message': 'nice stream',
          'gift_transaction_id': 'tx-2',
          'created_at': 1759330000,
        }, channel: KickDanmakuCodec.kicksChannel(_args)),
        _args,
      );
      final message = frame.messages.single;
      expect(message.type, LiveMessageType.superChat);
      expect(message.text, 'nice stream');
      final superChat = message.payload! as LiveSuperChatMessage;
      expect(superChat.price.amount, 500);
      expect(superChat.price.currency, 'Kicks');
      expect(superChat.price.displayText, '500 Kicks');
      expect(superChat.endTime!.difference(superChat.startTime!), const Duration(seconds: 60));
    });

    test('Kicks with a message but no pinned_time falls back to the amount tier', () {
      final message = KickDanmakuCodec.kicks({
        'sender': {'id': 7, 'username': 'giver'},
        'gift': {'name': 'Kick', 'amount': 1000},
        'message': 'hi',
      })!;
      final superChat = message.payload! as LiveSuperChatMessage;
      expect(superChat.endTime!.difference(superChat.startTime!), const Duration(minutes: 2));
    });

    test('deletes, bans and clears are retractions', () {
      List<LiveMessage> read(String event, Object? payload) =>
          KickDanmakuCodec.read(_frame(event, payload, channel: KickDanmakuCodec.chatChannel(_args)), _args).messages;
      final deleted = read(r'App\Events\MessageDeletedEvent', {
        'message': {'id': '07a12fcc'},
      }).single;
      expect(deleted.type, LiveMessageType.retraction);
      expect((deleted.payload! as LiveRetraction).messageId, 'kick:07a12fcc');
      final banned = read(r'App\Events\UserBannedEvent', {
        'user': {'id': 42},
      }).single;
      expect((banned.payload! as LiveRetraction).userId, '42');
      final cleared = read(r'App\Events\ChatroomClearEvent', {}).single;
      expect(cleared.payload! as LiveRetraction, const LiveRetraction(all: true));
    });

    test('subscriptions, hosts and pins are notices; StopStreamBroadcast ends', () {
      final sub = KickDanmakuCodec.read(
        _frame(r'App\Events\SubscriptionEvent', {
          'username': 'fan',
          'months': 3,
          'chatroom_id': 3852600,
        }, channel: KickDanmakuCodec.chatChannel(_args)),
        _args,
      ).messages.single;
      expect(sub.type, LiveMessageType.notice);
      expect(sub.payload, LiveNoticeKind.subscription);
      expect(sub.text, 'fan subscribed for 3 months');
      final host = KickDanmakuCodec.read(
        _frame(r'App\Events\StreamHostEvent', {
          'host_username': 'raider',
          'number_viewers': 120,
        }, channel: KickDanmakuCodec.chatChannel(_args)),
        _args,
      ).messages.single;
      expect(host.payload, LiveNoticeKind.raid);
      final ended = KickDanmakuCodec.read(
        _frame(r'App\Events\StopStreamBroadcast', {
          'livestream': {
            'id': 129925755,
            'channel': {'id': 3862536, 'is_banned': false},
          },
        }, channel: KickDanmakuCodec.broadcastChannel(_args)),
        _args,
      );
      expect(ended.messages.single.type, LiveMessageType.system);
      final foreign = KickDanmakuCodec.read(
        _frame(r'App\Events\StopStreamBroadcast', {
          'livestream': {
            'channel': {'id': 9},
          },
        }, channel: KickDanmakuCodec.broadcastChannel(_args)),
        _args,
      );
      expect(foreign.messages, isEmpty);
    });

    test('the class name after the last backslash names the event', () {
      expect(KickDanmakuCodec.eventName(r'App\Events\ChatMessageSentEvent'), 'ChatMessageSentEvent');
      expect(KickDanmakuCodec.eventName('StopStreamBroadcast'), 'StopStreamBroadcast');
    });
  });

  group('channel answer', () {
    test('a live channel becomes the room, with chatroom and master', () {
      final channel = KickRoomParser.channel(_channelLive(), requestedSlug: 'xqc');
      final room = channel.room;
      expect(room.platform, 'kick');
      expect(room.roomId, 'xqc');
      expect(channel.channelId, 668);
      expect(channel.chatroomId, 101689);
      expect(channel.master, isNotNull);
      expect(room.anchor?.anchorId, '668');
      expect(room.anchor?.name, 'xQc');
      expect(room.anchor?.followerCount, 1117677);
      expect(room.content.title, 'reacting');
      expect(room.content.coverUrl, 'https://images.kick.com/thumb.jpg');
      expect(room.content.notice, KickEndpoints.matureNotice);
      expect(room.audience.onlineViewers, 45000);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, DateTime.utc(2026, 10, 1, 5));
      expect(room.area?.areaId, 'just-chatting');
      expect(room.links.webUrl, 'https://kick.com/xqc');
    });

    test('a protocol-relative picture is made https and a zero viewer count reads as zero', () {
      final body = jsonEncode({
        'id': 668,
        'slug': 'xqc',
        'is_banned': false,
        'followers_count': '0',
        'playback_url':
            'https://fa723fc1b171.us-west-2.playback.live-video.net/api/video/v1/channel.m3u8?token=${_jwt(_exp)}',
        'user': {'id': 676, 'username': ' xQc ', 'profile_pic': '//files.kick.com/avatar.png', 'bio': ''},
        'chatroom': {'id': 101689},
        'livestream': {
          'id': 129925755,
          'is_live': true,
          'viewer_count': 0,
          'session_title': '  reacting  ',
          'start_time': '2026-10-01 05:00:00',
          'thumbnail': {'url': 'images.kick.com/thumb.jpg'},
          'categories': <Object?>[],
        },
      });
      final channel = KickRoomParser.channel(body, requestedSlug: 'xqc');
      expect(channel.room.content.coverUrl, 'https://images.kick.com/thumb.jpg');
      expect(channel.room.content.title, 'reacting');
      expect(channel.room.anchor?.name, 'xQc');
      expect(channel.room.anchor?.avatarUrl, 'https://files.kick.com/avatar.png');
      expect(channel.room.anchor?.followerCount, 0);
      expect(channel.room.audience.onlineViewers, 0);
      // An empty bio reads as nothing, not as the empty string.
      expect(channel.room.anchor?.introduction, isNull);
      expect(channel.room.content.introduction, '');
      expect(channel.room.content.notice, '');
    });

    test('an answered slug of another case still matches; the id is lower case', () {
      final body = _channelLive(slug: 'XQC').replaceFirst('"xQc"', '"xQc"');
      expect(KickRoomParser.channel(body, requestedSlug: 'xqc').room.roomId, 'xqc');
    });

    test('an answer for another channel is api-changed', () {
      expect(
        () => KickRoomParser.channel(_channelLive(), requestedSlug: 'someone-else'),
        throwsA(isA<KickFailure>().having((f) => f.kind, 'kind', KickFailureKind.apiChanged)),
      );
    });

    test('an offline channel has no master and reads the offline banner', () {
      final channel = KickRoomParser.channel(_channelOffline, requestedSlug: 'xqcisoffline');
      expect(channel.master, isNull);
      expect(channel.room.broadcast.liveStatus, LiveStatus.offline);
      expect(channel.room.content.coverUrl, 'https://files.kick.com/offline_banner.jpg');
      expect(channel.chatroomId, 101689);
      expect(channel.channelId, 101691);
    });

    test('a banned channel is banned, not offline', () {
      final body = _channelLive().replaceFirst('"is_banned":false', '"is_banned":true');
      expect(KickRoomParser.channel(body, requestedSlug: 'xqc').room.broadcast.liveStatus, LiveStatus.banned);
    });

    test("404 is not-found and Cloudflare's refusal is risk control", () {
      expect(
        () => KickRoomParser.channel('{}', requestedSlug: 'ghost', status: 404),
        throwsA(isA<KickFailure>().having((f) => f.kind, 'kind', KickFailureKind.notFound)),
      );
      expect(
        () => KickRoomParser.channel('Request blocked by security policy.', requestedSlug: 'xqc', status: 403),
        throwsA(isA<KickFailure>().having((f) => f.kind, 'kind', KickFailureKind.riskControl)),
      );
    });

    test('a playback_url that is not IVS is no stream', () {
      expect(KickRoomParser.ivsMaster('https://kick.com/xqc.m3u8?token=abc'), isNull);
      expect(KickRoomParser.ivsMaster('?token=abc'), isNull);
      expect(KickRoomParser.ivsMaster('https://x.live-video.net/a.m3u8?token=abc'), isNotNull);
    });
  });

  group('master playlist', () {
    final master = Uri.parse('https://fa723fc1b171.us-west-2.playback.live-video.net/api/video/v1/c.m3u8?token=t');

    test('renditions name the qualities, best first, with codecs', () {
      final variants = KickPlayParser.variants(_masterPlaylist, master: master);
      expect(variants.map((v) => v.name), ['1080p60', '720p60', '480p', '160p']);
      expect(variants.map((v) => v.height), [1080, 720, 480, 160]);
      expect(variants.first.codec, LiveStreamCodec.avc);
      expect(variants.last.codec, LiveStreamCodec.hevc);
      final qualities = KickPlayParser.qualities(variants);
      expect(qualities.map((q) => q.qualityId), ['1080p60', '720p60', '480p', '160p']);
      expect(qualities.first.label, '1080p60');
      expect(qualities.first.codec, LiveStreamCodec.avc);
    });

    test('lines resolve against the master with media headers and the lease', () {
      final variants = KickPlayParser.variants(_masterPlaylist, master: master);
      final variant = KickPlayParser.pick(variants, '480p')!;
      final lines = KickPlayParser.lines(
        variant,
        slug: 'xqc',
        master: master,
        expiresAt: _expiry,
        now: _expiry.subtract(const Duration(days: 1)),
      );
      final line = lines.single;
      expect(line.url, 'https://fa723fc1b171.us-west-2.playback.live-video.net/v1/playlist/480.m3u8');
      expect(line.format, LiveStreamFormat.hls);
      expect(line.formatSource, LivePlayFormatSource.declared);
      expect(line.headers['referer'], 'https://kick.com/xqc/');
      expect(line.headers['origin'], 'https://kick.com');
      expect(line.geometry.width, 852);
      expect(line.geometry.height, 480);
      expect(line.lease?.expiresAt, _expiry);
      expect(line.lease?.refreshAt, _expiry.subtract(const Duration(minutes: 1)));
    });

    test('a refused master is stream-unavailable; a non-playlist is api-changed', () {
      expect(
        () => KickPlayParser.variants('', master: master, status: 403),
        throwsA(isA<KickFailure>().having((f) => f.kind, 'kind', KickFailureKind.streamUnavailable)),
      );
      expect(
        () => KickPlayParser.variants('<html>nope</html>', master: master),
        throwsA(isA<KickFailure>().having((f) => f.kind, 'kind', KickFailureKind.apiChanged)),
      );
    });

    test('a 401 refusal is risk control, not a changed API', () {
      expect(
        () => KickPlayParser.variants(_masterPlaylist, master: master, status: 401),
        throwsA(isA<KickFailure>().having((f) => f.kind, 'kind', KickFailureKind.riskControl)),
      );
    });

    test('a STREAM-INF with no playlist under it is api-changed', () {
      const truncated = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=3422999,RESOLUTION=1280x720,CODECS="avc1.4D401F",VIDEO="720p60"
#EXT-X-STREAM-INF:BANDWIDTH=1427999,RESOLUTION=852x480,CODECS="avc1.4D401F",VIDEO="480p30"
/v1/playlist/480.m3u8
''';
      expect(
        () => KickPlayParser.variants(truncated, master: master),
        throwsA(isA<KickFailure>().having((f) => f.kind, 'kind', KickFailureKind.apiChanged)),
      );
      const unterminated = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=3422999,RESOLUTION=1280x720,CODECS="avc1.4D401F",VIDEO="720p60"
''';
      expect(
        () => KickPlayParser.variants(unterminated, master: master),
        throwsA(isA<KickFailure>().having((f) => f.kind, 'kind', KickFailureKind.apiChanged)),
      );
    });

    test('the JWT exp names the token expiry', () {
      final withToken = Uri.parse('https://x.live-video.net/master.m3u8?token=${_jwt(_exp)}');
      expect(KickPlayParser.tokenExpiry(withToken), _expiry);
      expect(KickPlayParser.tokenExpiry(Uri.parse('https://x.live-video.net/master.m3u8?token=abc')), isNull);
      expect(KickPlayParser.tokenExpiry(Uri.parse('https://x.live-video.net/master.m3u8')), isNull);
    });
  });

  group('directory, catalog and search', () {
    test('a livestreams page reads cards and pages on next_page_url', () {
      final body = jsonEncode({
        'current_page': 1,
        'next_page_url': 'https://kick.com/stream/livestreams/en?page=2',
        'data': [_directoryRow(), _directoryRow(slug: 'xqc', channelId: 668)],
      });
      final page = KickRoomParser.directoryPage(body, page: 1, pageSize: 30);
      expect(page.rooms.map((r) => r.roomId), ['aquino', 'xqc']);
      expect(page.rooms.first.audience.onlineViewers, 33282);
      expect(page.hasMore, isTrue);
    });

    test('a page of the wrong number is api-changed', () {
      final body = jsonEncode({'current_page': 2, 'next_page_url': null, 'data': <Object?>[]});
      expect(
        () => KickRoomParser.directoryPage(body, page: 1, pageSize: 30),
        throwsA(isA<KickFailure>().having((f) => f.kind, 'kind', KickFailureKind.apiChanged)),
      );
    });

    test('an unknown subcategory filter is not-found', () {
      final body = jsonEncode({
        'current_page': 1,
        'next_page_url': null,
        'data': [_directoryRow()],
      });
      expect(
        () => KickRoomParser.directoryPage(body, page: 1, pageSize: 30, subcategory: 'no-such-game'),
        throwsA(isA<KickFailure>().having((f) => f.kind, 'kind', KickFailureKind.notFound)),
      );
    });

    test('categories and subcategories form parented areas', () {
      final parents = KickRoomParser.mainCategories(
        jsonEncode([
          {'id': 1, 'name': 'Games', 'slug': 'games'},
          {'id': 2, 'name': 'IRL', 'slug': 'irl'},
          {'id': 3, 'name': 'Bad Slug', 'slug': 'Not A Slug'},
        ]),
      );
      // games/irl are named in Chinese; the malformed slug is dropped.
      expect(parents.map((p) => p.slug), ['games', 'irl']);
      expect(parents.map((p) => p.name), ['游戏', '生活']);
      final areas = KickRoomParser.subcategories(
        jsonEncode({
          'data': [
            {
              'id': 14353,
              'name': 'Tickets, Please',
              'slug': 'tickets-please',
              'category': {'slug': 'games'},
            },
            {
              'id': 1,
              'name': 'Wrong parent',
              'slug': 'other',
              'category': {'slug': 'irl'},
            },
          ],
        }),
        parent: parents.first,
      );
      expect(areas.single.areaId, 'tickets-please');
      expect(areas.single.parentAreaId, 'games');
      expect(areas.single.parentAreaName, '游戏');
    });

    test('search leads with channels and adds tagged lives deduped', () {
      final body = jsonEncode({
        'channels': [
          {
            'id': 668,
            'slug': 'XQC',
            'is_banned': false,
            'isLive': true,
            'followersCount': 1117677,
            'user': {'username': 'xQc', 'profilePic': 'https://files.kick.com/a.png', 'bio': 'juice'},
          },
        ],
        'livestreams': {
          'tags': [
            _directoryRow(slug: 'xqc', channelId: 668),
            _directoryRow(slug: 'other', channelId: 9, viewers: 100),
          ],
        },
      });
      final rooms = KickRoomParser.searchRooms(body);
      expect(rooms.map((r) => r.roomId), ['xqc', 'other']);
      expect(rooms.first.anchor?.followerCount, 1117677);
      expect(rooms.first.broadcast.liveStatus, LiveStatus.live);
    });
  });

  group('slugs and links', () {
    test('a slug is lower case, shaped, and never a reserved page', () {
      expect(KickEndpoints.normalizeSlug(' XQC '), 'xqc');
      expect(KickEndpoints.normalizeSlug('a_b-c1'), 'a_b-c1');
      expect(KickEndpoints.normalizeSlug('search'), isNull);
      expect(KickEndpoints.normalizeSlug('too long ${'x' * 100}'), isNull);
      expect(KickEndpoints.normalizeSlug('no spaces here'), isNull);
    });

    test('a single kick.com path segment names the channel', () {
      expect(KickRoomParser.slugFromUrl(Uri.parse('https://www.kick.com/XQC/')), 'xqc');
      expect(KickRoomParser.slugFromUrl(Uri.parse('https://m.kick.com/xqc')), 'xqc');
      expect(KickRoomParser.slugFromUrl(Uri.parse('https://kick.com/xqc/videos')), isNull);
      expect(KickRoomParser.slugFromUrl(Uri.parse('https://kick.com/search?q=x')), isNull);
      expect(KickRoomParser.slugFromUrl(Uri.parse('https://twitch.tv/xqc')), isNull);
      expect(KickRoomParser.slugFromUrl(Uri.parse('https://evil@kick.com/xqc')), isNull);
      expect(KickRoomParser.slugFromUrl(Uri.parse('https://kick.com/xqc#frag')), isNull);
    });
  });

  group('providers', () {
    test('getRoom carries the chat ids in the runtime handle', () async {
      final http = _FakeHttp((req) => _resp(200, _channelLive()));
      final site = KickSite(http: KickHttp(http), now: () => DateTime.utc(2026, 10));
      final provider = KickRoomProvider(site: site);
      final room = _right(await provider.getRoom('XQC'));
      expect(room.roomId, 'xqc');
      final args = room.runtime.danmakuHandle! as KickDanmakuArgs;
      expect(args.chatroomId, 101689);
      expect(args.channelId, 668);
      expect(args.slug, 'xqc');
      expect(http.sent.single.headers['user-agent'], contains('Chrome/140'));
      expect(http.sent.single.url.path, '/api/v2/channels/xqc');
    });

    test('getRoom of a missing channel is a not-found left', () async {
      final http = _FakeHttp((req) => _resp(404, 'Channel not found.'));
      final site = KickSite(http: KickHttp(http));
      final error = _left(await KickRoomProvider(site: site).getRoom('ghost'));
      expect(error, isA<LiveSiteNotFound>());
    });

    test('a non-slug room id fails without a request', () async {
      final http = _FakeHttp((req) => _resp(200, '{}'));
      final site = KickSite(http: KickHttp(http));
      final error = _left(await KickRoomProvider(site: site).getRoom('has spaces'));
      expect(error, isA<LiveSiteNotFound>());
      expect(http.sent, isEmpty);
    });

    test('qualities and lines go channel answer then master playlist', () async {
      final http = _FakeHttp(
        (req) => req.url.host.endsWith(KickEndpoints.ivsHostSuffix)
            ? _resp(200, _masterPlaylist)
            : _resp(200, _channelLive()),
      );
      final site = KickSite(http: KickHttp(http), now: () => DateTime.utc(2026, 10));
      final provider = KickPlaybackProvider(site: site);
      final qualities = _right(await provider.getQualities(roomId: 'xqc'));
      expect(qualities.map((q) => q.label), ['1080p60', '720p60', '480p', '160p']);
      final lines = _right(await provider.getLines(roomId: 'xqc', quality: qualities[2]));
      expect(lines.single.url, endsWith('/v1/playlist/480.m3u8'));
      expect(lines.single.format, LiveStreamFormat.hls);
      expect(lines.single.lease?.expiresAt, _expiry);
      // The second lines request reuses the cached master: still two requests.
      await provider.getLines(roomId: 'xqc', quality: qualities.first);
      expect(http.sent.length, 2);
      final media = http.sent.last;
      expect(media.headers['referer'], 'https://kick.com/xqc/');
    });

    test('an offline room is content-unavailable for playback', () async {
      final http = _FakeHttp((req) => _resp(200, _channelOffline));
      final site = KickSite(http: KickHttp(http));
      final error = _left(await KickPlaybackProvider(site: site).getQualities(roomId: 'xqcisoffline'));
      expect(error, isA<LiveSiteContentUnavailable>());
    });

    test('search answers room results, one page only', () async {
      final body = jsonEncode({
        'channels': [
          {
            'id': 668,
            'slug': 'xqc',
            'isLive': true,
            'is_banned': false,
            'followers_count': 1117677,
            'user': {'username': 'xQc', 'profilePic': 'https://files.kick.com/a.png'},
          },
        ],
        'livestreams': {'tags': <Object?>[]},
      });
      final http = _FakeHttp((req) => _resp(200, body));
      final site = KickSite(http: KickHttp(http));
      final provider = KickSearchProvider(site: site);
      final page = _right(await provider.search(const LiveSearchRequest(query: 'xqc', target: LiveSearchTarget.rooms)));
      expect((page.items.single as RoomSearchResult).room.roomId, 'xqc');
      expect(provider.supportedTargets, {LiveSearchTarget.rooms});
      expect(
        _left(await provider.search(const LiveSearchRequest(query: 'xqc', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      // A keyword longer than 50 is truncated; page two answers without a request.
      await provider.search(LiveSearchRequest(query: 'x' * 60, target: LiveSearchTarget.rooms));
      expect(http.sent.last.url.queryParameters['searched_word']!.length, 50);
      final before = http.sent.length;
      _right(await provider.search(const LiveSearchRequest(query: 'xqc', target: LiveSearchTarget.rooms, page: 2)));
      expect(http.sent.length, before);
    });

    test("areas walk every category's subcategories flat", () async {
      final http = _FakeHttp(
        (req) => switch (req.url.path) {
          '/api/v1/categories' => _resp(
            200,
            jsonEncode([
              {'name': 'Games', 'slug': 'games'},
              {'name': 'IRL', 'slug': 'irl'},
            ]),
          ),
          '/api/v1/subcategories' when req.url.queryParameters['category'] == 'games' => _resp(
            200,
            jsonEncode({
              'data': [
                {'name': 'Tickets, Please', 'slug': 'tickets-please'},
              ],
            }),
          ),
          '/api/v1/subcategories' => _resp(200, jsonEncode({'data': <Object?>[]})),
          _ => _resp(404, '{}'),
        },
      );
      final site = KickSite(http: KickHttp(http));
      final provider = KickAreaProvider(site: site);
      final areas = _right(await provider.getAreas());
      expect(areas.single.areaId, 'tickets-please');
      expect(areas.single.parentAreaName, '游戏');
      // A slug that cannot be a subcategory fails without a request.
      final before = http.sent.length;
      expect(_left(await provider.getAreaRooms(areaId: 'not a slug!')), isA<LiveSiteNotFound>());
      expect(http.sent.length, before);
      // Kick answers the whole directory for one of its own top-level
      // categories, so the parent the catalog just named is refused without a
      // request instead of being read back as an empty area.
      expect(_left(await provider.getAreaRooms(areaId: 'games')), isA<LiveSiteInvalidArgument>());
      expect(_left(await provider.getAreaRooms(areaId: 'irl')), isA<LiveSiteInvalidArgument>());
      expect(http.sent.length, before);
    });

    test('a spent lease makes the lines request re-read the channel and master', () async {
      final soon = DateTime.utc(2026, 10).add(const Duration(minutes: 1));
      final body = _channelLive().replaceFirst(_jwt(_exp), _jwt(soon.millisecondsSinceEpoch ~/ 1000));
      final http = _FakeHttp(
        (req) => req.url.host.endsWith(KickEndpoints.ivsHostSuffix) ? _resp(200, _masterPlaylist) : _resp(200, body),
      );
      final site = KickSite(http: KickHttp(http), now: () => DateTime.utc(2026, 10));
      final provider = KickPlaybackProvider(site: site);
      final qualities = _right(await provider.getQualities(roomId: 'xqc'));
      expect(http.sent.length, 2);
      // The master is still inside its own lifetime, but its token dies within
      // the recovery lead: the lines request is a new channel answer and a new
      // master rather than the cached (soon-dead) one.
      final lines = _right(await provider.getLines(roomId: 'xqc', quality: qualities.first));
      expect(lines.single.lease?.expiresAt, soon);
      expect(http.sent.length, 4);
    });

    test('every capability is wired and the site is built in', () {
      final site = KickSite(http: KickHttp(_FakeHttp((req) => _resp(200, '{}'))));
      expect(site.capability<LiveRoomProvider>(), isNotNull);
      expect(site.capability<LiveAreaProvider>(), isNotNull);
      expect(site.capability<LiveDiscoveryProvider>(), isNotNull);
      expect(site.capability<LiveSearchProvider>(), isNotNull);
      expect(site.capability<LivePlaybackProvider>(), isNotNull);
      expect(site.capability<LiveDanmakuProvider>(), isNotNull);
      expect(site.capability<LiveLinkResolver>(), isNotNull);
      expect(site.capability<LiveHotProvider>(), isNull);
      expect(site.capability<LiveRoomProvider>(), same(site.capability<LiveRoomProvider>()));
      expect(
        createBuiltInLiveSites(http: _FakeHttp((req) => _resp(200, '{}'))).map((s) => s.manifest.id),
        contains('kick'),
      );
    });

    test('the link resolver canonicalizes without a request', () async {
      final http = _FakeHttp((req) => _resp(200, '{}'));
      final site = KickSite(http: KickHttp(http));
      final resolver = KickLinkResolver(site: site);
      expect(_right(await resolver.resolve(Uri.parse('https://www.kick.com/XQC'))).toString(), 'https://kick.com/xqc');
      expect(_left(await resolver.resolve(Uri.parse('https://kick.com/xqc/videos'))), isA<LiveSiteNotFound>());
      expect(_left(await resolver.resolve(Uri.parse('https://twitch.tv/xqc'))), isA<LiveSiteUnsupported>());
      expect(http.sent, isEmpty);
    });
  });

  group('json helpers', () {
    test('jsonTime converts an ISO offset to UTC and reads a plain stamp as UTC', () {
      expect(jsonTime('2026-09-30T19:24:14+08:00'), DateTime.utc(2026, 9, 30, 11, 24, 14));
      expect(jsonTime('2026-09-30 19:24:14'), DateTime.utc(2026, 9, 30, 19, 24, 14));
      expect(jsonTime('2026-09-30T19:24:14Z'), DateTime.utc(2026, 9, 30, 19, 24, 14));
      expect(jsonTime('nonsense'), isNull);
    });

    test('decodeJson refuses a body over the size cap', () {
      expect(decodeJson('{"a":1}'), isA<Map<String, Object?>>());
      expect(decodeJson('x' * (maxJsonBytes + 1)), isNull);
    });

    test('jsonString trims and blanks read as nothing', () {
      expect(jsonString('  reacting  '), 'reacting');
      expect(jsonString('   '), isNull);
      expect(jsonString(''), isNull);
      expect(jsonString(null), isNull);
      expect(jsonString(42), '42');
    });

    test('jsonCount keeps a zero count: a live room with no viewers says zero', () {
      expect(jsonCount(0), 0);
      expect(jsonCount('0'), 0);
      expect(jsonCount(-1), isNull);
      expect(jsonCount('45000'), 45000);
      expect(jsonCount(null), isNull);
    });

    test('normalizeImageUrl makes Kick CDN links absolute and drops junk', () {
      expect(normalizeImageUrl('//files.kick.com/a.png'), 'https://files.kick.com/a.png');
      expect(normalizeImageUrl('files.kick.com/a.png'), 'https://files.kick.com/a.png');
      expect(normalizeImageUrl('"https://files.kick.com/a.png"'), 'https://files.kick.com/a.png');
      expect(normalizeImageUrl('https://files.kick.com/a.png'), 'https://files.kick.com/a.png');
      expect(normalizeImageUrl('null'), '');
      expect(normalizeImageUrl('not a url at all'), '');
      expect(normalizeImageUrl(null), '');
    });
  });
}
