import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/youtube/api/youtube_http.dart';
import 'package:live_sites/src/platforms/youtube/youtube_site.dart';
import 'package:test/test.dart';

/// The channel the tests read.
const String _channel = 'UCabc1234567890123456789';

/// The broadcast the tests read.
const String _video = 'abcDefGhIjk';

/// One endpoint's answer, [nth] naming its own ask (1 = the first).
typedef _Answer = LiveResponse Function(int nth);

/// The transport answering InnerTube endpoints by name; anything unmapped is a
/// test failure.
final class _Api implements LiveHttp {
  new(this.answers);

  final Map<String, _Answer> answers;
  final Map<String, int> _counts = {};
  final List<Uri> asked = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final url = request.url;
    asked.add(url);
    final path = url.path;
    final ep = path.endsWith('/navigation/resolve_url') ? 'navigation/resolve_url' : path.split('/').last;
    final answer = answers[ep];
    if (answer == null) throw StateError('the test does not answer $url');
    final nth = (_counts[ep] ?? 0) + 1;
    _counts[ep] = nth;
    return answer(nth);
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}

  /// How many times [ep] was asked.
  int times(String ep) => asked.where((url) => url.path.endsWith('/$ep')).length;

  /// Whether any `next` page was asked (the full entry pairs it).
  bool get askedNext => times('next') > 0;

  /// Whether the channel's broadcast was resolved.
  bool get askedResolve => times('navigation/resolve_url') > 0;
}

LiveResponse _resp(int status, Object body) => LiveResponse(
  statusCode: status,
  headers: const {},
  bodyBytes: body is String ? Uint8List.fromList(utf8.encode(body)) : Uint8List.fromList(body as List<int>),
);

/// A `player` answer of [videoId] of [channel], [live] or not.
String _player({String videoId = _video, String channel = _channel, bool live = true}) => jsonEncode({
  'playabilityStatus': {'status': 'OK'},
  'videoDetails': {'videoId': videoId, 'externalChannelId': channel, 'author': '频道', 'title': '直播标题', 'isLive': live},
  'microformat': {
    'playerMicroformatRenderer': {
      'liveBroadcastDetails': {'isLiveNow': live},
    },
  },
  'streamingData': <String, Object?>{},
});

/// A `navigation/resolve_url` answer naming [videoId] or [browseId].
String _resolve({String? videoId, String? browseId}) => jsonEncode({
  'endpoint': {
    if (videoId != null) 'watchEndpoint': {'videoId': videoId},
    if (browseId != null) 'browseEndpoint': {'browseId': browseId},
  },
});

/// An `updated_metadata` answer of [count] watching now.
String _viewers(int count) => jsonEncode({
  'videoViewCountRenderer': {
    'isLive': true,
    'viewCount': {'simpleText': '$count watching now'},
  },
});

/// A Live hub page whose one card is a live broadcast of [_channel].
String _hub() => jsonEncode({
  'contents': [
    {
      'richItemRenderer': {
        'content': {
          'videoRenderer': {
            'videoId': _video,
            'title': {'simpleText': '直播标题'},
            'ownerText': {
              'runs': [
                {'text': '频道'},
              ],
              'browseEndpoint': {'browseId': _channel},
            },
            'viewCountText': {'simpleText': '100 watching'},
            'thumbnail': {
              'thumbnails': [
                {'url': 'https://i.ytimg.com/vi/$_video/hq.jpg'},
              ],
            },
          },
        },
      },
    },
  ],
});

void main() {
  group('the broadcast memory', () {
    test('entering a channel opens the broadcast a card showed', () async {
      final clock = DateTime(2026);
      final api = _Api({
        'browse': (_) => _resp(200, _hub()),
        'navigation/resolve_url': (_) => _resp(200, _resolve(videoId: 'otherVideo11')),
        'player': (_) => _resp(200, _player()),
        'next': (_) => _resp(200, '{}'),
      });
      final site = YoutubeSite(http: YouTubeHttp(api), now: () => clock);
      await site.hub();
      final room = await site.detail(_channel);
      expect(room.roomId, _channel);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(api.times('player'), 1);
      expect(api.askedResolve, isFalse, reason: 'the card names the broadcast, no resolve is needed');
    });

    test('a broadcast remembered past half an hour resolves again', () async {
      var clock = DateTime(2026);
      final api = _Api({
        'navigation/resolve_url': (_) => _resp(200, _resolve(videoId: _video)),
        'player': (_) => _resp(200, _player()),
        'next': (_) => _resp(200, '{}'),
      });
      final site = YoutubeSite(http: YouTubeHttp(api), now: () => clock);
      await site.detail(_channel);
      clock = clock.add(YoutubeSite.broadcastLifetime);
      await site.detail(_channel);
      expect(api.times('navigation/resolve_url'), 2);
      expect(api.times('player'), 2);
    });

    test('a remembered broadcast that ended asks its channel instead', () async {
      final clock = DateTime(2026);
      final api = _Api({
        'navigation/resolve_url': (_) => _resp(200, _resolve(videoId: _video)),
        'player': (nth) => _resp(200, _player(live: nth == 1)),
        'next': (_) => _resp(200, '{}'),
      });
      final site = YoutubeSite(http: YouTubeHttp(api), now: () => clock);
      await site.detail(_channel);
      final room = await site.detail(_channel);
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(api.times('navigation/resolve_url'), 2, reason: 'the channel names the broadcast to open');
    });
  });

  group('the pageless refresh', () {
    test('a live channel refreshes through resolve, player and the viewer count', () async {
      final api = _Api({
        'navigation/resolve_url': (_) => _resp(200, _resolve(videoId: _video)),
        'player': (_) => _resp(200, _player()),
        'updated_metadata': (_) => _resp(200, _viewers(1256)),
      });
      final site = YoutubeSite(http: YouTubeHttp(api), now: DateTime.now);
      final room = await site.refreshRoom(_channel);
      expect(room.roomId, _channel);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.audience.onlineViewers, 1256);
      expect(api.times('player'), 1);
      expect(api.times('updated_metadata'), 1);
      expect(api.askedNext, isFalse, reason: 'the refresh reads no page');
    });

    test('a channel naming no broadcast refreshes to the bare offline room', () async {
      final api = _Api({'navigation/resolve_url': (_) => _resp(200, _resolve(browseId: _channel))});
      final site = YoutubeSite(http: YouTubeHttp(api), now: DateTime.now);
      final room = await site.refreshRoom(_channel);
      expect(room.roomId, _channel);
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.anchor, isNull, reason: 'the follow keeps the anchor it stored');
      expect(api.times('player'), 0);
    });

    test('a failing pageless step falls back to the full entry', () async {
      final api = _Api({
        'navigation/resolve_url': (_) => _resp(200, _resolve(videoId: _video)),
        'player': (nth) => nth == 1 ? _resp(500, 'server error') : _resp(200, _player()),
        'next': (_) => _resp(200, '{}'),
      });
      final site = YoutubeSite(http: YouTubeHttp(api), now: DateTime.now);
      final room = await site.refreshRoom(_channel);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(api.times('player'), 2);
      expect(api.askedNext, isTrue, reason: 'the fallback pairs the next answer');
    });
  });
}
