import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_hot_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/capabilities/live_status_check.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/looklive/api/looklive_endpoints.dart';
import 'package:live_sites/src/platforms/looklive/api/looklive_http.dart';
import 'package:live_sites/src/platforms/looklive/danmaku/looklive_danmaku_session.dart';
import 'package:live_sites/src/platforms/looklive/looklive_site.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_room.dart';
import 'package:test/test.dart';

import 'looklive_fixtures.dart';

const String _video = '21623631';
const String _audio = '181408025';
const String _offline = '325808387';

/// The `data` of an answer [body] with [edit] applied, as its JSON again.
String _edited(String body, void Function(Map<String, dynamic> data) edit) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  edit(json['data'] as Map<String, dynamic>);
  return jsonEncode(json);
}

/// The room answer [body] whose `roomInfo` is edited by [edit].
String _editedInfo(String body, void Function(Map<String, dynamic> info) edit) => _edited(body, (data) {
  edit(data['roomInfo'] as Map<String, dynamic>);
});

/// The transport under the site: every request recorded, answered by path
/// from a script whose last entry repeats.
final class _Http implements LiveHttp {
  /// Per path: the answers in turn (a `String` body, or a
  /// `(status, body)` record); the last repeats.
  new(this._answers);

  final Map<String, List<Object>> _answers;
  final List<LiveRequest> requests = [];

  List<LiveRequest> asked(String path) => [
    for (final request in requests)
      if (request.url.path == path) request,
  ];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    requests.add(request);
    final answers = _answers.putIfAbsent(request.url.path, () => ['{}']);
    final step = answers.length > 1 ? answers.removeAt(0) : answers.first;
    final (status, body) = switch (step) {
      final String body => (200, body),
      (final int status, final String body) => (status, body),
      _ => throw step as Exception,
    };
    return LiveResponse(statusCode: status, headers: const {}, bodyBytes: utf8.encode(body));
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnsupportedError('open');

  @override
  void close() {}
}

LookliveSite _site(_Http http) => LookliveSite(http: LookliveHttp(http));

/// The right value of [either], failing the test on a left.
T _value<T>(Either<LiveSiteError, T> either) => either.fold((error) => fail('left: $error'), (value) => value);

/// The left of [either], failing the test on a right.
LiveSiteError _error(Either<LiveSiteError, Object?> either) =>
    either.fold((error) => error, (value) => fail('right: $value'));

void main() {
  group('identity and capabilities', () {
    test('the manifest, the runtime and the lifecycle', () async {
      final site = _site(_Http({}));
      expect(site.manifest.id, 'looklive');
      expect(site.manifest.localizedName('zh-CN', 'en-US'), 'LOOK 直播');
      expect(site.runtimeInfo.status, LiveSiteStatus.ready);
      await site.initialize(
        const LiveSiteContext(platform: LiveTargetPlatform.android, locale: 'zh-CN', defaultLocale: 'zh-CN'),
      );
      await site.dispose();
    });

    test('the supported capabilities answer; the others are null', () {
      final site = _site(_Http({}));
      expect(site.capability<LiveRoomProvider>(), isA<LiveRoomProvider>());
      expect(site.capability<LiveAreaProvider>(), isA<LiveAreaProvider>());
      expect(site.capability<LiveDiscoveryProvider>(), isA<LiveDiscoveryProvider>());
      expect(site.capability<LiveSearchProvider>(), isA<LiveSearchProvider>());
      expect(site.capability<LivePlaybackProvider>(), isA<LivePlaybackProvider>());
      expect(site.capability<LivePlayRecovery>(), isA<LivePlayRecovery>());
      expect(site.capability<LiveDanmakuProvider>(), isA<LookliveDanmakuProvider>());
      expect(site.capability<LiveLinkResolver>(), isA<LiveLinkResolver>());
      expect(site.capability<LiveRoomRefresh>(), isA<LiveRoomRefresh>());
      expect(site.capability<LiveStatusCheck>(), isA<LiveStatusCheck>());
      expect(site.capability<LiveHotProvider>(), isNull, reason: 'the platform has no hot list of its own');
      // Singletons per site.
      expect(site.capability<LiveRoomProvider>(), same(site.capability<LiveRoomProvider>()));
    });
  });

  group('the merged recommendations', () {
    test('page 1: the video rooms, then the voice rooms, the lists asked once each', () async {
      final http = _Http({
        LookliveEndpoints.videoListPath: [videoListP1Body],
        LookliveEndpoints.audioListPath: [audioListP1Body],
      });
      final site = _site(http);
      final page = _value(
        await site.capability<LiveDiscoveryProvider>()!.getRecommendedRooms(request: LivePageRequest.of(pageSize: 30)),
      );
      expect(page.items.map((room) => room.roomId).take(3), [_video, '217327486', '95878198']);
      expect(page.items, hasLength(22), reason: '3 video cards, then 19 voice cards');
      expect(page.hasMore, isTrue, reason: 'the voice list has more pages');
      expect(page.items.first.audience.popularity, 440);
      for (final request in http.requests) {
        expect(request.method, 'POST');
        expect(request.url.host, 'api.look.163.com');
        expect(request.site, 'looklive');
        expect(request.headers, LookliveEndpoints.requestHeaders);
      }
      expect(http.requests.first.body, LookliveEndpoints.formBody({'offset': 0, 'limit': 20}));
    });

    test('page 2: the ended video list is not asked again; page 1 starts over', () async {
      final http = _Http({
        LookliveEndpoints.videoListPath: [videoListP1Body, videoListP1Body],
        LookliveEndpoints.audioListPath: [audioListP1Body, audioListP2Body],
      });
      final site = _site(http);
      final discovery = site.capability<LiveDiscoveryProvider>()!;
      await discovery.getRecommendedRooms(request: LivePageRequest.of());
      final second = _value(await discovery.getRecommendedRooms(request: LivePageRequest.of(page: 2)));
      expect(second.items, hasLength(20), reason: 'only the voice list answered');
      expect(second.items.first.roomId, _audio);
      expect(http.asked(LookliveEndpoints.videoListPath), hasLength(1), reason: 'the video list ended on page 1');
      await discovery.getRecommendedRooms(request: LivePageRequest.of());
      expect(http.asked(LookliveEndpoints.videoListPath), hasLength(2), reason: 'page 1 starts the record over');
    });

    test('a page or size below 1 gives nothing without a request', () async {
      final http = _Http({});
      final site = _site(http);
      final discovery = site.capability<LiveDiscoveryProvider>()!;
      expect(_value(await discovery.getRecommendedRooms(request: LivePageRequest.of(page: 0))).items, isEmpty);
      expect(_value(await discovery.getRecommendedRooms(request: LivePageRequest.of(pageSize: 0))).items, isEmpty);
      expect(http.requests, isEmpty);
    });

    test('getRooms is the same merged page', () async {
      final http = _Http({
        LookliveEndpoints.videoListPath: [videoListP1Body],
        LookliveEndpoints.audioListPath: [audioListP1Body],
      });
      final site = _site(http);
      final page = _value(await site.capability<LiveRoomProvider>()!.getRooms(LivePageRequest.of(pageSize: 5)));
      expect(page.items, hasLength(5), reason: 'the page is cut to the asked size');
      expect(page.hasMore, isTrue);
    });

    test('the area pages ask their own list; another area is a caller error', () async {
      final http = _Http({
        LookliveEndpoints.videoListPath: [videoListP1Body],
        LookliveEndpoints.audioListPath: [audioListP1Body],
      });
      final site = _site(http);
      final areas = site.capability<LiveAreaProvider>()!;
      final catalog = _value(await areas.getAreas());
      expect(catalog.map((area) => area.areaId), ['video', 'audio']);
      final video = _value(await areas.getAreaRooms(area: catalog.first, request: LivePageRequest.of()));
      expect(video.items.map((room) => room.roomId), [_video, '217327486', '95878198']);
      expect(video.hasMore, isFalse);
      final audio = _value(await areas.getAreaRooms(area: catalog.last, request: LivePageRequest.of()));
      expect(audio.items, hasLength(19));
      expect(http.asked(LookliveEndpoints.audioListPath), hasLength(1));
      final error = _error(await areas.getAreaRooms(area: catalog.first.rebuild((b) => b..areaId = 'other')));
      expect(error, isA<LiveSiteInvalidArgument>());
      expect(http.requests, hasLength(2), reason: 'the caller error refused before any request');
    });

    test('a changed answer is a parse failure at the boundary', () async {
      final http = _Http({
        LookliveEndpoints.videoListPath: ['<html>'],
        LookliveEndpoints.audioListPath: [audioListP1Body],
      });
      final site = _site(http);
      final error = _error(await site.capability<LiveDiscoveryProvider>()!.getRecommendedRooms());
      expect(error, isA<LiveSiteParseError>());
    });
  });

  group('search', () {
    LookliveSite siteOf() => _site(
      _Http({
        LookliveEndpoints.videoListPath: [videoListP1Body],
        LookliveEndpoints.audioListPath: [audioListP1Body],
        LookliveEndpoints.roomPath: [roomVideoBody],
      }),
    );

    Future<(LiveSiteError?, List<LiveSearchResult>)> run(
      LookliveSite site,
      String query, {
      int page = 1,
      int pageSize = 30,
      LiveSearchTarget target = LiveSearchTarget.rooms,
    }) async {
      final searched = await site.capability<LiveSearchProvider>()!.search(
        LiveSearchRequest.of(query: query, target: target, page: page, pageSize: pageSize),
      );
      return await searched.fold(
        (error) => (error, const <LiveSearchResult>[]),
        (result) => (null, result.items.toList()),
      );
    }

    test('the provider searches rooms only', () {
      expect(siteOf().capability<LiveSearchProvider>()!.supportedTargets, {LiveSearchTarget.rooms});
    });

    test('a room number or room link finds that room, without its streams', () async {
      final site = siteOf();
      for (final query in [_video, ' $_video ', 'https://look.163.com/live?id=$_video&position=3']) {
        final (error, hits) = await run(site, query);
        expect(error, isNull, reason: query);
        expect(hits, hasLength(1), reason: query);
        final hit = hits.single as RoomSearchResult;
        expect(hit.room.roomId, _video);
        expect(hit.room.runtime.streamHandle, isNull, reason: 'the searched room carries no streams');
        expect(hit.room.broadcast.liveStatus, LiveStatus.live);
      }
    });

    test('a room the site does not know is no result, without a list request', () async {
      final http = _Http({
        LookliveEndpoints.roomPath: [roomNotFoundBody],
      });
      final site = _site(http);
      final (error, hits) = await run(site, '99999999');
      expect(error, isNull);
      expect(hits, isEmpty);
      expect(http.requests, hasLength(1), reason: 'only the room was asked');
    });

    test('a keyword filters the first page of both lists by name and title; a number asks its own answer', () async {
      final site = siteOf();
      final (error, byNick) = await run(site, 'armin');
      expect(error, isNull);
      expect((byNick.single as RoomSearchResult).room.roomId, _video, reason: 'the name, case ignored');
      final (_, byTitle) = await run(site, '电音电台');
      expect((byTitle.single as RoomSearchResult).room.roomId, _video);
      // A keyword that is a room number never filters: it asks for that room
      // (the reference only forgives a 404 there), and the recorded answer
      // anchors another room.
      final (numberError, numberHits) = await run(site, '217327486');
      expect(numberError, isA<LiveSiteParseError>(), reason: 'the answered room is not the asked one');
      expect(numberHits, isEmpty);
    });

    test('a blank keyword, another page, a page size over 100 or a foreign link give nothing', () async {
      final http = _Http({});
      final site = _site(http);
      for (final (query, page, pageSize) in [
        ('  ', 1, 30),
        (_video, 2, 30),
        (_video, 1, 101),
        (_video, 1, 0),
        ('https://evil.com/live?id=$_video', 1, 30),
      ]) {
        final (error, hits) = await run(site, query, page: page, pageSize: pageSize);
        expect(error, isNull, reason: query);
        expect(hits, isEmpty, reason: query);
      }
      expect(http.requests, isEmpty, reason: 'nothing was asked');
      final anchors = await site.capability<LiveSearchProvider>()!.search(
        LiveSearchRequest.of(query: _video, target: LiveSearchTarget.anchors),
      );
      expect(_error(anchors), isA<LiveSiteUnsupported>());
    });
  });

  group('rooms', () {
    test('room entry: the room answer, with its streams and its chat', () async {
      final http = _Http({
        LookliveEndpoints.roomPath: [roomVideoBody],
      });
      final site = _site(http);
      final room = _value(await site.capability<LiveRoomProvider>()!.getRoom(_video));
      expect(room.roomId, _video);
      expect(room.content.title, 'ASOT电音电台直播中');
      expect(room.anchor?.name, 'Armin van Buuren');
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, DateTime.utc(2026, 8, 26, 8, 33, 20, 612));
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.audience.primaryMetric, isNot(LiveAudienceMetricType.onlineViewers), reason: 'no audience');
      expect(room.area?.areaId, 'video');
      expect(room.links.webUrl, 'https://look.163.com/live?id=$_video');
      final data = room.runtime.streamHandle! as LookLiveRoom;
      expect(data.roomId, _video);
      expect(data.variants, hasLength(2));
      expect(room.runtime.danmakuHandle, const LookLiveDanmakuArgs(roomId: _video, chatroomId: '462192286'));
      expect(http.requests.single.body, LookliveEndpoints.formBody({'liveRoomNo': _video}));
      expect(http.requests.single.url, Uri.parse('https://api.look.163.com/weapi/livestream/room/get/v3'));
    });

    test('a room link is read as its number; a non-number is not-found without a request', () async {
      final http = _Http({
        LookliveEndpoints.roomPath: [roomVideoBody],
      });
      final site = _site(http);
      expect(
        _value(await site.capability<LiveRoomProvider>()!.getRoom('https://look.163.com/live?id=$_video')).roomId,
        _video,
      );
      final error = _error(await site.capability<LiveRoomProvider>()!.getRoom('room'));
      expect(error, isA<LiveSiteNotFound>());
      expect(http.requests, hasLength(1));
    });

    test('not-found and other failures at the boundary', () async {
      final site = _site(
        _Http({
          LookliveEndpoints.roomPath: [roomNotFoundBody],
        }),
      );
      expect(_error(await site.capability<LiveRoomProvider>()!.getRoom('99999999')), isA<LiveSiteNotFound>());
      final throttled = _site(
        _Http({
          LookliveEndpoints.roomPath: [(429, '')],
        }),
      );
      expect(_error(await throttled.capability<LiveRoomProvider>()!.getRoom(_video)), isA<LiveSiteRateLimitError>());
      final refused = _site(
        _Http({
          LookliveEndpoints.roomPath: [(403, '')],
        }),
      );
      expect(_error(await refused.capability<LiveRoomProvider>()!.getRoom(_video)), isA<LiveSiteRateLimitError>());
    });

    test('the refresh reads no streams and carries no handles', () async {
      final site = _site(
        _Http({
          LookliveEndpoints.roomPath: [roomVideoBody],
        }),
      );
      final room = _value(await site.capability<LiveRoomRefresh>()!.getRoomForRefresh(roomId: _video));
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.runtime.streamHandle, isNull);
      expect(room.runtime.danmakuHandle, isNull);
      final recorded = _value(await site.capability<LiveRoomRefresh>()!.getRoomForRecording(roomId: _video));
      expect(recorded.runtime.streamHandle, isA<LookLiveRoom>());
    });

    test('the status ask: live, offline, banned; an unknown state is a left', () async {
      final http = _Http({
        LookliveEndpoints.roomPath: [
          roomVideoBody,
          roomOfflineBody,
          _edited(roomVideoBody, (data) => data['liveStatus'] = -10),
          _edited(roomVideoBody, (data) => data['liveStatus'] = 2),
        ],
      });
      final site = _site(http);
      final status = site.capability<LiveStatusCheck>()!;
      final video = LiveRoom.normalized(platform: 'looklive', roomId: _video);
      final ended = LiveRoom.normalized(platform: 'looklive', roomId: _offline);
      expect(
        _value(await status.getLiveStatus(room: video)),
        isTrue,
        reason: 'app-only and ticketed rooms are live too',
      );
      expect(_value(await status.getLiveStatus(room: ended)), isFalse);
      expect(_value(await status.getLiveStatus(room: video)), isFalse, reason: 'banned');
      expect(_error(await status.getLiveStatus(room: video)), isA<LiveSiteParseError>(), reason: 'unknown liveStatus');
    });
  });

  group('playback', () {
    Future<(LookliveSite, _Http, LiveRoom)> entered(String body) async {
      final http = _Http({
        LookliveEndpoints.roomPath: [body],
      });
      final site = _site(http);
      final room = _value(await site.capability<LiveRoomProvider>()!.getRoom(_video));
      return (site, http, room);
    }

    test('the qualities and lines of the entered room, no further request', () async {
      final (site, http, room) = await entered(roomVideoBody);
      final playback = site.capability<LivePlaybackProvider>()!;
      expect(http.requests, hasLength(1), reason: 'the entry was the only request so far');
      final qualities = _value(await playback.getQualities(room: room));
      expect(qualities.map((quality) => quality.qualityId), [LookliveEndpoints.hlsId, LookliveEndpoints.flvId]);
      final lines = _value(await playback.getLines(room: room));
      expect(lines, hasLength(1));
      expect(lines.single.format, LiveStreamFormat.hls, reason: "the room's first stream");
      expect(lines.single.headers.toMap(), LookliveEndpoints.mediaHeaders(_video));
      final flv = _value(await playback.getLines(room: room, quality: qualities.last));
      expect(flv.single.format, LiveStreamFormat.flv);
      expect(
        _error(
          await playback.getLines(
            room: room,
            quality: LivePlayQuality.of(label: 'x', qualityId: 'auto'),
          ),
        ),
        isA<LiveSiteInvalidArgument>(),
      );
    });

    test('a room without its entry cannot be played; an unusable one says why', () async {
      final (site, _, _) = await entered(roomVideoBody);
      final playback = site.capability<LivePlaybackProvider>()!;
      final stranger = LiveRoom.normalized(platform: 'looklive', roomId: _audio);
      final noEntry = _error(await playback.getQualities(room: stranger));
      expect(noEntry, isA<LiveSiteContentUnavailable>());
      expect(noEntry.message, contains('has no room answer'));
      final offline = LiveRoom.normalized(
        platform: 'looklive',
        roomId: _video,
        broadcast: RoomBroadcast.of(liveStatus: LiveStatus.offline),
      );
      expect(_error(await playback.getQualities(room: offline)), isA<LiveSiteContentUnavailable>());
      final foreign = LiveRoom.normalized(platform: 'kilakila', roomId: _video);
      expect(_error(await playback.getQualities(room: foreign)), isA<LiveSiteInvalidArgument>());
      final (appOnlySite, _, appOnlyRoom) = await entered(
        _editedInfo(roomVideoBody, (info) {
          info['liveStreamType'] = 50;
          info['liveUrl'] = null;
        }),
      );
      expect(appOnlyRoom.broadcast.restriction, LiveRestriction.appOnly);
      final appOnlyError = _error(
        await appOnlySite.capability<LivePlaybackProvider>()!.getQualities(room: appOnlyRoom),
      );
      expect(appOnlyError, isA<LiveSiteContentUnavailable>());
      expect(appOnlyError.message, contains('LOOK app only'));
    });

    test('recovery asks a fresh room answer and takes its line', () async {
      final http = _Http({
        LookliveEndpoints.roomPath: [
          roomVideoBody,
          _editedInfo(roomVideoBody, (info) {
            (info['liveUrl'] as Map<String, dynamic>)['hlsPullUrl'] =
                'http://pull0583d674.live.126.net/live/ffffffffffffffffffffffffffffffff/playlist.m3u8';
          }),
        ],
      });
      final site = _site(http);
      final room = _value(await site.capability<LiveRoomProvider>()!.getRoom(_video));
      final fresh = _value(await site.capability<LivePlayRecovery>()!.refetchLines(room: room));
      expect(fresh.single.url, contains('/live/ffffffffffffffffffffffffffffffff/'));
      expect(http.asked(LookliveEndpoints.roomPath), hasLength(2));
      final refused = _error(
        await site.capability<LivePlayRecovery>()!.refetchLines(
          room: room,
          quality: LivePlayQuality.of(label: 'x', qualityId: 'auto'),
        ),
      );
      expect(refused, isA<LiveSiteInvalidArgument>(), reason: 'refused before any request');
      expect(http.asked(LookliveEndpoints.roomPath), hasLength(2));
    });
  });

  group('links', () {
    test('a room page is canonicalized without a request; the rest is refused', () async {
      final http = _Http({});
      final site = _site(http);
      final resolver = site.capability<LiveLinkResolver>()!;
      expect(
        _value(await resolver.resolve(Uri.parse('https://look.163.com/live?id=$_video&position=3'))),
        Uri.parse('https://look.163.com/live?id=$_video'),
      );
      expect(_error(await resolver.resolve(Uri.parse('https://look.163.com/live'))), isA<LiveSiteNotFound>());
      expect(_error(await resolver.resolve(Uri.parse('https://evil.com/live?id=$_video'))), isA<LiveSiteUnsupported>());
      expect(http.requests, isEmpty, reason: 'no link costs a request');
    });
  });
}
