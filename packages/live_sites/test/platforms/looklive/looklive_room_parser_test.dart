import 'dart:convert';

import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/looklive/api/looklive_endpoints.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_room.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_room_parser.dart';
import 'package:test/test.dart';

import 'looklive_fixtures.dart';

const String _video = '21623631';
const String _audio = '181408025';
const String _offline = '325808387';
const String _appOnly = '645235480';
const String _injected = '495455091';

/// The `data` of an answer [body] with [edit] applied, as its JSON again.
String _edited(String body, void Function(Map<String, dynamic> data) edit) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  edit(json['data'] as Map<String, dynamic>);
  return jsonEncode(json);
}

/// A list [body] whose entry [index]'s `liveData` is edited by [edit].
String _editedLive(String body, void Function(Map<String, dynamic> live) edit, {int index = 0}) =>
    _edited(body, (data) {
      edit(((data['itemList'] as List)[index] as Map<String, dynamic>)['liveData'] as Map<String, dynamic>);
    });

/// The room answer [body] whose `roomInfo` is edited by [edit].
String _editedInfo(String body, void Function(Map<String, dynamic> info) edit) => _edited(body, (data) {
  edit(data['roomInfo'] as Map<String, dynamic>);
});

/// The failure kind [read] throws, or null when it was accepted.
Object? _kindOf(void Function() read) {
  try {
    read();
    return null;
  } on LookliveFailure catch (failure) {
    return failure.kind;
  }
}

void main() {
  group('the weapi envelope', () {
    test('the room request is the recorded form, byte for byte', () {
      expect(
        LookliveEndpoints.formBody(LookliveEndpoints.roomPayload(_video)),
        roomVideoRequestBody,
        reason: 'the recorded AES layers and encSecKey',
      );
      expect(LookliveEndpoints.encSecKey, hasLength(256));
      expect(LookliveEndpoints.listPayload(3), {'offset': 40, 'limit': 20});
      expect(LookliveEndpoints.chatAddressPayload('447365581'), {'liveRoomNo': '447365581', 'os': 0});
      expect(jsonEncode(LookliveEndpoints.chatAddressPayload('447365581')), '{"liveRoomNo":"447365581","os":0}');
    });

    test("the request and media headers are the web client's", () {
      expect(LookliveEndpoints.requestHeaders['origin'], 'https://look.163.com');
      expect(LookliveEndpoints.requestHeaders['referer'], 'https://look.163.com/');
      expect(LookliveEndpoints.requestHeaders['content-type'], 'application/x-www-form-urlencoded');
      expect(LookliveEndpoints.mediaHeaders(_video), {
        'origin': 'https://look.163.com',
        'referer': 'https://look.163.com/live?id=$_video',
        'user-agent': 'Mozilla/5.0',
      });
    });
  });

  group('the catalog', () {
    test('the one category with the video and voice areas', () {
      final areas = LookliveRoomParser.areas();
      expect(areas.map((area) => area.areaId), ['video', 'audio']);
      expect(areas.map((area) => area.areaName), ['视频直播', '语音直播']);
      expect(areas.every((area) => area.parentAreaName == 'LOOK 直播'), isTrue);
      expect(areas.map((area) => area.platform), everyElement('looklive'));
      expect(LookliveRoomParser.areas(pageSize: 1).map((area) => area.areaId), ['video']);
      expect(LookliveRoomParser.kindOf(LookliveEndpoints.videoArea), LookLiveKind.video);
      expect(LookliveRoomParser.kindOf(LookliveEndpoints.audioArea), LookLiveKind.audio);
      expect(LookliveRoomParser.kindOf(null), isNull);
      expect(
        _kindOf(() => LookliveRoomParser.kindOf(LookliveEndpoints.videoArea.rebuild((b) => b..areaId = 'other'))),
        LookliveFailureKind.invalidArgument,
        reason: 'another area of this platform is a caller error',
      );
    });
  });

  group('the recorded video list', () {
    test('three cards with heat, viewers and streams; the list ends', () {
      final page = LookliveRoomParser.directory(videoListP1Body, kind: LookLiveKind.video);
      expect(page.rooms.map((room) => room.roomId), [_video, '217327486', '95878198']);
      expect(page.hasMore, isFalse);
      final card = page.rooms.first;
      expect((card.popularity, card.currentViewers), (440, 1));
      expect(card.kind, LookLiveKind.video);
      expect(card.state, LookLiveState.live);
      expect(card.variants.map((variant) => variant.id), [LookliveEndpoints.hlsId, LookliveEndpoints.flvId]);
      expect(card.variants.map((variant) => variant.uri.scheme), everyElement('https'));
      expect(card.mediaChecked, isTrue);
      expect(card.hasAddress, isTrue);
      expect(card.userId, '351218439');
      expect(card.sessionId, '134543183');
      expect(card.title, 'ASOT电音电台直播中');
      expect(card.nick, 'Armin van Buuren');
      expect(card.chatroomId, '', reason: 'a card carries no chatroom');
      expect(card.danmakuArgs, isNull);
      expect(card.startedAt, isNull, reason: 'the lists do not say');
      expect(page.rooms.map((room) => room.streamType), [
        1,
        1,
        51,
      ], reason: "the stream type is the card's `type`; 51 is a type LOOK does not name, with streams");
      expect(page.rooms.map((room) => room.isAppOnly), everyElement(isFalse));
      expect(
        page.rooms.map((room) => room.block),
        everyElement(isNull),
        reason: 'a playable card does not tell tickets',
      );
    });

    test('the cards become rooms: the audience apart, the avatar on the anchor', () {
      final rooms = [
        for (final room in LookliveRoomParser.directory(videoListP1Body, kind: LookLiveKind.video).rooms)
          LookliveRoomParser.liveRoom(room),
      ];
      final card = rooms.first;
      expect(card.roomId, _video);
      expect(card.audience.onlineViewers, 1, reason: 'onlineNumber is current viewers');
      expect(card.audience.popularity, 440, reason: 'popularity is heat, kept apart');
      expect(card.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(card.broadcast.liveStatus, LiveStatus.live);
      expect(card.broadcast.restriction, isNull, reason: 'a playable card says nothing');
      expect(card.broadcast.startedAt, isNull);
      expect(card.area?.areaId, 'video');
      expect(card.links.webUrl, 'https://look.163.com/live?id=$_video');
      expect(card.anchor?.name, 'Armin van Buuren');
      expect(card.anchor?.avatarUrl, contains('https://'), reason: 'pictures are made https');
      expect(card.content.notice, LookliveEndpoints.chatNotice);
    });

    test('an entry that cannot be read is skipped, until none is left', () {
      final one = _editedLive(videoListP1Body, (live) => live['popularity'] = -1, index: 1);
      expect(LookliveRoomParser.directory(one, kind: LookLiveKind.video).rooms.map((room) => room.roomId), [
        _video,
        '95878198',
      ]);
      final every = _edited(videoListP1Body, (data) {
        for (final item in data['itemList'] as List) {
          (((item as Map<String, dynamic>)['liveData'] as Map<String, dynamic>)['userInfo'] as Map).remove('userId');
        }
      });
      expect(
        _kindOf(() => LookliveRoomParser.directory(every, kind: LookLiveKind.video)),
        LookliveFailureKind.apiChanged,
      );
      final quiet = _edited(videoListP1Body, (data) {
        (data['itemList'] as List)[1] = <String, dynamic>{'type': '2', 'liveData': null};
      });
      expect(LookliveRoomParser.directory(quiet, kind: LookLiveKind.video).rooms.map((room) => room.roomId), [
        _video,
        '95878198',
      ]);
    });

    test('the same room twice keeps the first place and the last card', () {
      final twice = _editedLive(videoListP1Body, (live) {
        (live['userInfo'] as Map<String, dynamic>)['liveRoomNo'] = int.parse(_video);
      }, index: 1);
      final page = LookliveRoomParser.directory(twice, kind: LookLiveKind.video);
      // The duplicate sits at the first card's place; the third card stays.
      expect(page.rooms.map((room) => room.roomId), [_video, '95878198']);
      expect(page.rooms.first.sessionId, '134388747', reason: "the last card's data");
    });

    test('a bad address costs only its stream, and a room without any is unplayable', () {
      final twoBad = _editedLive(videoListP1Body, (live) {
        (live['liveUrl'] as Map<String, dynamic>)
          ..['hlsPullUrl'] = 'http://example.com/live/x/playlist.m3u8'
          ..['httpPullUrl'] = 'rtmp://pull0583d674.live.126.net/live/x';
      });
      final card = LookliveRoomParser.directory(twoBad, kind: LookLiveKind.video).rooms.first;
      expect((card.roomId, card.variants.length, card.hasAddress), (_video, 0, true));
      expect(LookliveRoomParser.liveRoom(card).broadcast.restriction, LiveRestriction.unplayable);
      final onlyFlv = _editedLive(videoListP1Body, (live) {
        (live['liveUrl'] as Map<String, dynamic>)['hlsPullUrl'] = 'x';
      });
      final flvCard = LookliveRoomParser.directory(onlyFlv, kind: LookLiveKind.video).rooms.first;
      expect(flvCard.variants.map((variant) => variant.id), [LookliveEndpoints.flvId]);
      expect(flvCard.block, isNull);
    });

    test('voice cards of the video kind are skipped; the injected card is app-only on the video list', () {
      final audioAsVideo = LookliveRoomParser.directory(audioListP1Body, kind: LookLiveKind.video);
      expect(audioAsVideo.rooms, hasLength(1), reason: 'the voice list injects one video card');
      final injected = audioAsVideo.rooms.single;
      expect((injected.roomId, injected.streamType, injected.isAppOnly), (_injected, 50, true));
      expect(injected.variants, isEmpty, reason: 'its liveUrl is null');
      expect((injected.popularity, injected.currentViewers), (22104, 47));
      final room = LookliveRoomParser.liveRoom(injected);
      expect((room.broadcast.liveStatus, room.broadcast.restriction), (LiveStatus.live, LiveRestriction.appOnly));
      expect(room.broadcast.isLiveNow, isTrue);
      expect(room.broadcast.isRestricted, isTrue);
      expect(room.content.notice, '${LookliveEndpoints.appOnlyNotice}\n${LookliveEndpoints.chatNotice}');
      final asAudio = LookliveRoomParser.directory(audioListP1Body, kind: LookLiveKind.audio);
      expect(asAudio.rooms, hasLength(19), reason: 'the injected video card is skipped');
      expect(asAudio.rooms.map((room) => room.kind), everyElement(LookLiveKind.audio));
      expect(asAudio.rooms.map((room) => room.streamType), everyElement(6));
      expect(asAudio.hasMore, isTrue);
    });
  });

  group('the recorded voice list', () {
    test('page 2: twenty cards, the ended room among them', () {
      final page = LookliveRoomParser.directory(audioListP2Body, kind: LookLiveKind.audio);
      expect(page.rooms, hasLength(20));
      expect(page.hasMore, isTrue);
      expect(page.rooms.first.roomId, _audio);
      expect(page.rooms[1].roomId, _offline);
    });

    test('past its end the list answers itemList null: an empty last page', () {
      final page = LookliveRoomParser.directory(videoListP2Body, kind: LookLiveKind.video);
      expect(page.rooms, isEmpty);
      expect(page.hasMore, isFalse);
      final lying = jsonEncode({
        'code': 200,
        'data': {'itemList': null, 'hasMore': true},
      });
      expect(
        _kindOf(() => LookliveRoomParser.directory(lying, kind: LookLiveKind.video)),
        LookliveFailureKind.apiChanged,
      );
    });
  });

  group('the recorded rooms', () {
    test('the video room: live, both streams, the chatroom, the start', () {
      final room = LookliveRoomParser.room(roomVideoBody, roomId: _video);
      expect((room.kind, room.state, room.streamType), (LookLiveKind.video, LookLiveState.live, 1));
      expect(room.variants.map((variant) => variant.id), [LookliveEndpoints.hlsId, LookliveEndpoints.flvId]);
      expect(room.chatroomId, '462192286');
      expect(room.anonymousMode, isFalse);
      expect(room.startedAt, DateTime.utc(2026, 8, 26, 8, 33, 20, 612));
      expect(room.startedAt!.isUtc, isTrue);
      expect(room.paid, isFalse);
      expect(room.block, LookLiveBlock.none);
      expect(room.danmakuArgs, const LookLiveDanmakuArgs(roomId: _video, chatroomId: '462192286'));
      final refresh = LookliveRoomParser.room(roomVideoBody, roomId: _video, withMedia: false);
      expect(refresh.variants, isEmpty);
      expect(refresh.mediaChecked, isFalse);
      expect(refresh.hasAddress, isTrue);
      expect(refresh.danmakuArgs, room.danmakuArgs, reason: "the chat is the answer's, not the streams'");
      final detail = LookliveRoomParser.liveRoom(room);
      expect(detail.audience.onlineViewers, isNull, reason: 'no audience');
      expect(detail.audience.popularity, isNull, reason: 'the room answer has no figures');
      expect(detail.audience.primaryMetric, LiveAudienceMetricType.unknown);
      expect(detail.broadcast.startedAt, room.startedAt);
      expect(detail.broadcast.restriction, LiveRestriction.none);
      expect(detail.content.notice, LookliveEndpoints.chatNotice);
    });

    test('the voice room is in the voice area; the ended room is offline without streams', () {
      final audio = LookliveRoomParser.room(roomAudioBody, roomId: _audio);
      expect(audio.kind, LookLiveKind.audio);
      expect(audio.chatroomId, '16272838887');
      expect(audio.startedAt, DateTime.utc(2026, 9, 27, 17, 12, 0, 883));
      expect(LookliveRoomParser.liveRoom(audio).area?.areaId, 'audio');
      final ended = LookliveRoomParser.room(roomOfflineBody, roomId: _offline);
      expect(ended.state, LookLiveState.offline);
      expect(
        ended.variants,
        isEmpty,
        reason: 'the answer still lists the old addresses; streams are read only when live',
      );
      expect(ended.startedAt, isNull, reason: 'its startTime is the ended broadcast');
      expect(ended.unavailableReason, contains('offline'));
      expect(LookliveRoomParser.liveRoom(ended).broadcast.liveStatus, LiveStatus.offline);
      expect(ended.chatroomId, '909690154');
      expect(ended.danmakuArgs, isNull, reason: 'a room that is not live has no chat');
    });

    test('the app-only room: live, stream type 50, no streams', () {
      final room = LookliveRoomParser.room(roomAppOnlyBody, roomId: _appOnly);
      expect((room.state, room.streamType, room.isAppOnly), (LookLiveState.live, 50, true));
      expect(room.chatroomId, '15148749147');
      expect(room.startedAt, DateTime.utc(2026, 8, 18, 18, 4, 34, 614));
      final detail = LookliveRoomParser.liveRoom(room);
      expect(
        (detail.broadcast.liveStatus, detail.broadcast.restriction, detail.broadcast.isLiveNow),
        (LiveStatus.live, LiveRestriction.appOnly, true),
      );
      expect(room.unavailableReason, contains('LOOK app only'));
    });

    test('the answer must be for the room asked, and the number a room number', () {
      expect(_kindOf(() => LookliveRoomParser.room(roomVideoBody, roomId: '21623632')), LookliveFailureKind.apiChanged);
      final short = LookLiveRoom(
        roomId: '7',
        userId: '1',
        sessionId: '1',
        kind: LookLiveKind.video,
        state: LookLiveState.live,
      );
      expect(_kindOf(() => LookliveRoomParser.liveRoom(short)), LookliveFailureKind.apiChanged);
    });
  });

  group('restriction', () {
    LiveRoom at(String body, {bool withMedia = true}) =>
        LookliveRoomParser.liveRoom(LookliveRoomParser.room(body, roomId: _video, withMedia: withMedia));

    test('app-only, ticket and unplayable live rooms stay live; none otherwise', () {
      for (final (name, body, entry, refresh) in [
        ('recorded', roomVideoBody, LiveRestriction.none, LiveRestriction.none),
        (
          'type 50 without addresses',
          _editedInfo(roomVideoBody, (info) {
            info['liveStreamType'] = 50;
            info['liveUrl'] = null;
          }),
          LiveRestriction.appOnly,
          LiveRestriction.appOnly,
        ),
        (
          'a ticket',
          _edited(roomVideoBody, (data) => data['feeInfo'] = {'fee': true, 'sessionKey': ''}),
          LiveRestriction.paid,
          LiveRestriction.paid,
        ),
        (
          'a ticket without a session key',
          _edited(roomVideoBody, (data) => data['feeInfo'] = {'fee': 1}),
          LiveRestriction.paid,
          LiveRestriction.paid,
        ),
        (
          'a bought ticket',
          _edited(roomVideoBody, (data) => data['feeInfo'] = {'fee': true, 'sessionKey': 'k'}),
          LiveRestriction.none,
          LiveRestriction.none,
        ),
        (
          'no fee',
          _edited(roomVideoBody, (data) => data['feeInfo'] = {'fee': false}),
          LiveRestriction.none,
          LiveRestriction.none,
        ),
        (
          'no address',
          _editedInfo(roomVideoBody, (info) => info['liveUrl'] = null),
          LiveRestriction.unplayable,
          LiveRestriction.unplayable,
        ),
        (
          'only bad addresses',
          _editedInfo(
            roomVideoBody,
            (info) => info['liveUrl'] = {'hlsPullUrl': 'http://x.cn/a.m3u8', 'httpPullUrl': 'x'},
          ),
          LiveRestriction.unplayable,
          LiveRestriction.none,
        ),
        (
          'offline',
          _edited(roomVideoBody, (data) => data['liveStatus'] = -1),
          LiveRestriction.none,
          LiveRestriction.none,
        ),
        (
          'banned',
          _edited(roomVideoBody, (data) => data['liveStatus'] = -10),
          LiveRestriction.none,
          LiveRestriction.none,
        ),
        ('unknown', _edited(roomVideoBody, (data) => data['liveStatus'] = 2), null, null),
      ]) {
        final entered = at(body);
        final refreshed = at(body, withMedia: false);
        expect((entered.broadcast.restriction, refreshed.broadcast.restriction), (entry, refresh), reason: name);
        if (entry != null && entry != LiveRestriction.none) {
          expect(entered.broadcast.liveStatus, LiveStatus.live, reason: name);
          expect(entered.broadcast.isLiveNow, isTrue, reason: name);
        }
      }
      final paid = at(_edited(roomVideoBody, (data) => data['feeInfo'] = {'fee': true}));
      expect(paid.content.notice, '${LookliveEndpoints.paidNotice}\n${LookliveEndpoints.chatNotice}');
      final unknown = at(_edited(roomVideoBody, (data) => data['liveStatus'] = 2));
      expect(unknown.broadcast.restriction, isNull, reason: 'an unknown state does not tell');
      expect(unknown.broadcast.liveStatus, LiveStatus.unknown);
    });

    test('a refreshed type 50 room with addresses is not app-only', () {
      final body = _editedInfo(roomVideoBody, (info) => info['liveStreamType'] = 50);
      final refresh = at(body, withMedia: false);
      final entry = at(body);
      expect(
        (refresh.broadcast.restriction, entry.broadcast.restriction),
        (LiveRestriction.none, LiveRestriction.none),
      );
    });
  });

  group('enrich', () {
    LookLiveRoom card() => LookliveRoomParser.directory(videoListP1Body, kind: LookLiveKind.video).rooms.first;

    test("a live answer of the same broadcast takes the card's audience", () {
      final answer = LookliveRoomParser.room(roomVideoBody, roomId: _video);
      expect(answer.popularity, isNull, reason: 'the room answer has no audience');
      final completed = answer.enrich(card());
      expect((completed.popularity, completed.currentViewers), (440, 1));
      expect(completed.variants, hasLength(2), reason: "the answer's own streams stay");
      expect(completed.startedAt, answer.startedAt, reason: "the start is the answer's");
      final detail = LookliveRoomParser.liveRoom(completed);
      expect(detail.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
    });

    test("an empty live answer plays the card's streams", () {
      final refreshed = LookliveRoomParser.room(
        _editedInfo(roomVideoBody, (info) => info['liveUrl'] = null),
        roomId: _video,
        withMedia: false,
      );
      expect(LookliveRoomParser.liveRoom(refreshed).broadcast.restriction, LiveRestriction.unplayable);
      final completed = refreshed.enrich(card());
      expect(completed.variants, hasLength(2));
      expect(LookliveRoomParser.liveRoom(completed).broadcast.restriction, LiveRestriction.none);
    });

    test('the audience of the same broadcast only while this answer is live', () {
      final known = card();
      for (final (status, kept) in [
        (1, true),
        (0, false),
        (-1, false),
        (-2, false),
        (-4, false),
        (-10, false),
        (2, false),
      ]) {
        final answer = LookliveRoomParser.room(
          _edited(roomVideoBody, (data) => data['liveStatus'] = status),
          roomId: _video,
        );
        final completed = answer.enrich(known);
        expect(
          (completed.popularity, completed.currentViewers),
          kept ? (440, 1) : (null, null),
          reason: 'liveStatus $status',
        );
        expect((completed.nick, completed.userId), (answer.nick, answer.userId), reason: 'names are kept');
      }
      final other = LookliveRoomParser.room(
        _editedInfo(roomVideoBody, (info) => info['id'] = 5),
        roomId: _video,
      ).enrich(known);
      expect((other.popularity, other.currentViewers), (null, null), reason: 'another broadcast');
    });

    test("the chat stays the answer's when a card of the same broadcast completes it", () {
      final room = LookliveRoomParser.room(roomVideoBody, roomId: _video).enrich(card());
      expect(room.danmakuArgs, const LookLiveDanmakuArgs(roomId: _video, chatroomId: '462192286'));
      expect(card().enrich(LookliveRoomParser.room(roomVideoBody, roomId: _video)).danmakuArgs, isNull);
    });
  });

  group('qualities and lines', () {
    test('one quality per stream, HLS first, FLV second', () {
      final room = LookliveRoomParser.room(roomVideoBody, roomId: _video);
      final qualities = LookliveRoomParser.qualities(room);
      expect(qualities.map((quality) => quality.qualityId), [LookliveEndpoints.hlsId, LookliveEndpoints.flvId]);
      expect(qualities.map((quality) => quality.label), ['HLS 原始线路', 'FLV 原始线路']);
      expect(qualities.map((quality) => quality.platformOrder), [2, 1], reason: 'best first');
      final flvOnly = LookliveRoomParser.room(
        _editedInfo(roomVideoBody, (info) => (info['liveUrl'] as Map<String, dynamic>).remove('hlsPullUrl')),
        roomId: _video,
      );
      expect(LookliveRoomParser.qualities(flvOnly).map((quality) => quality.qualityId), [LookliveEndpoints.flvId]);
    });

    test('the HLS and FLV lines carry the media headers and no lease', () {
      final room = LookliveRoomParser.room(roomVideoBody, roomId: _video);
      final hls = LookliveRoomParser.line(room, LookliveEndpoints.hlsId);
      expect(hls.url, 'https://pull0583d674.live.126.net/live/800897349fe246e994f36976011de4d5/playlist.m3u8');
      expect((hls.format, hls.formatSource), (LiveStreamFormat.hls, LivePlayFormatSource.declared));
      expect(hls.lineLabel, 'pull0583d674.live.126.net');
      expect(hls.headers.toMap(), LookliveEndpoints.mediaHeaders(_video));
      expect(hls.lease, isNull, reason: 'the addresses carry no signature or expiry');
      expect(hls.codec, isNull);
      final flv = LookliveRoomParser.line(room, LookliveEndpoints.flvId);
      expect(flv.format, LiveStreamFormat.flv);
      expect(flv.url, endsWith('.flv?netease=pull0583d674.live.126.net'));
      expect(
        _kindOf(() => LookliveRoomParser.line(room, 'auto')),
        LookliveFailureKind.invalidArgument,
        reason: 'another quality is a caller error',
      );
      final noHls = LookliveRoomParser.room(
        _editedInfo(roomVideoBody, (info) => (info['liveUrl'] as Map<String, dynamic>).remove('hlsPullUrl')),
        roomId: _video,
      );
      expect(
        _kindOf(() => LookliveRoomParser.line(noHls, LookliveEndpoints.hlsId)),
        LookliveFailureKind.streamUnavailable,
      );
    });
  });

  group('statuses and gates', () {
    test('the state by liveStatus: -10 and -4 banned, -2 closed, anything else unknown', () {
      for (final (status, state) in [
        (1, LookLiveState.live),
        (0, LookLiveState.offline),
        (-1, LookLiveState.offline),
        (-2, LookLiveState.offline),
        (-10, LookLiveState.banned),
        (-4, LookLiveState.banned),
        (2, LookLiveState.unknown),
      ]) {
        final room = LookliveRoomParser.room(
          _edited(roomVideoBody, (data) => data['liveStatus'] = status),
          roomId: _video,
          withMedia: false,
        );
        expect(room.state, state, reason: 'liveStatus $status');
        final detail = LookliveRoomParser.liveRoom(room);
        expect(detail.broadcast.effectiveLiveStatus, switch (state) {
          LookLiveState.live => LiveStatus.live,
          LookLiveState.offline => LiveStatus.offline,
          LookLiveState.banned => LiveStatus.banned,
          LookLiveState.unknown => LiveStatus.unknown,
        }, reason: 'liveStatus $status');
        if (state == LookLiveState.banned) {
          expect(detail.broadcast.isExplicitlyOfflineNow, isTrue);
          expect(detail.content.notice, '${LookliveEndpoints.bannedNotice}\n${LookliveEndpoints.chatNotice}');
          expect(room.unavailableReason, contains('banned'));
        }
      }
    });

    test('code 404 is not-found; 424 and 555 say why on the room, risk control on the lists', () {
      expect(
        _kindOf(() => LookliveRoomParser.room(roomNotFoundBody, roomId: '99999999')),
        LookliveFailureKind.notFound,
      );
      expect(
        _kindOf(() => LookliveRoomParser.directory(roomNotFoundBody, kind: LookLiveKind.video)),
        LookliveFailureKind.notFound,
      );
      String code(Object? value) => jsonEncode({'code': value, 'message': 'm', 'data': null});
      for (final value in [424, 555]) {
        expect(
          _kindOf(() => LookliveRoomParser.room(code(value), roomId: _video)),
          LookliveFailureKind.streamUnavailable,
          reason: 'code $value says why the room cannot be watched',
        );
        expect(
          _kindOf(() => LookliveRoomParser.directory(code(value), kind: LookLiveKind.video)),
          LookliveFailureKind.riskControl,
          reason: 'on the lists $value stays access',
        );
        expect(_kindOf(() => LookliveRoomParser.chatAddresses(code(value))), LookliveFailureKind.riskControl);
      }
      for (final value in [520, 522]) {
        expect(
          _kindOf(() => LookliveRoomParser.room(code(value), roomId: _video)),
          LookliveFailureKind.riskControl,
          reason: 'code $value',
        );
      }
      expect(_kindOf(() => LookliveRoomParser.room(code(500), roomId: _video)), LookliveFailureKind.apiChanged);
      expect(_kindOf(() => LookliveRoomParser.room(code('200'), roomId: _video)), LookliveFailureKind.apiChanged);
      expect(_kindOf(() => LookliveRoomParser.room('{}', roomId: _video)), LookliveFailureKind.apiChanged);
    });

    test('HTTP statuses: 401 and 403 access, 404 missing, 429 throttle, the rest network', () {
      for (final (status, kind) in [
        (401, LookliveFailureKind.riskControl),
        (403, LookliveFailureKind.riskControl),
        (404, LookliveFailureKind.notFound),
        (429, LookliveFailureKind.rateLimited),
        (500, LookliveFailureKind.network),
        (302, LookliveFailureKind.network),
        (204, LookliveFailureKind.network),
      ]) {
        expect(
          _kindOf(() => LookliveRoomParser.room('', roomId: _video, status: status)),
          kind,
          reason: '$status',
        );
        expect(
          _kindOf(() => LookliveRoomParser.directory('', kind: LookLiveKind.audio, status: status)),
          kind,
          reason: '$status',
        );
      }
    });

    test('bodies: empty, not JSON and over 2 MiB are changed; exactly 2 MiB is read', () {
      expect(_kindOf(() => LookliveRoomParser.room('', roomId: _video)), LookliveFailureKind.apiChanged);
      expect(_kindOf(() => LookliveRoomParser.room('<html></html>', roomId: _video)), LookliveFailureKind.apiChanged);
      final exact = '$roomVideoBody${' ' * (LookliveEndpoints.responseLimit - utf8.encode(roomVideoBody).length)}';
      expect(LookliveRoomParser.room(exact, roomId: _video, withMedia: false).state, LookLiveState.live);
      expect(_kindOf(() => LookliveRoomParser.room('$exact ', roomId: _video)), LookliveFailureKind.apiChanged);
      final wide = '{"code":200,"data":{"x":"${'中' * (LookliveEndpoints.responseLimit ~/ 3)}"}}';
      expect(wide.length, lessThan(LookliveEndpoints.responseLimit));
      expect(
        _kindOf(() => LookliveRoomParser.room(wide, roomId: _video)),
        LookliveFailureKind.apiChanged,
        reason: 'counted in bytes',
      );
    });
  });

  group('stream addresses', () {
    test('the host, path and query rules, made https', () {
      const hls = 'http://pull0583d674.live.126.net/live/800897349fe246e994f36976011de4d5/playlist.m3u8';
      const flv = 'http://pull0583d674.live.126.net/live/800897349fe246e994f36976011de4d5.flv';
      expect('${LookliveEndpoints.mediaUri(hls, format: LiveStreamKind.hls)}', hls.replaceFirst('http:', 'https:'));
      expect(
        '${LookliveEndpoints.mediaUri(' $flv ', format: LiveStreamKind.flv)}',
        flv.replaceFirst('http:', 'https:'),
      );
      expect(
        '${LookliveEndpoints.mediaUri('$hls?netease=x', format: LiveStreamKind.hls)}',
        endsWith('?netease=x'),
        reason: 'a query within the budget stays',
      );
      expect(
        '${LookliveEndpoints.mediaUri(hls.replaceFirst('http:', 'HTTP:'), format: LiveStreamKind.hls)}',
        startsWith('https:'),
        reason: 'the scheme is read without regard to case',
      );
      for (final (raw, format) in [
        (hls, LiveStreamKind.flv),
        (flv, LiveStreamKind.hls),
        (hls.replaceFirst('pull0583d674.live.126.net', 'example.com'), LiveStreamKind.hls),
        (hls.replaceFirst('live.126.net', 'live.126.net.evil.test'), LiveStreamKind.hls),
        (hls.replaceFirst('.net/', '.net:8080/'), LiveStreamKind.hls),
        (hls.replaceFirst('//', '//u@'), LiveStreamKind.hls),
        ('$hls#x', LiveStreamKind.hls),
        (hls.replaceFirst('800897349fe246e9', '800897349FE246E9'), LiveStreamKind.hls),
        (flv, LiveStreamKind.hls),
        (hls.replaceFirst('http:', 'rtmp:'), LiveStreamKind.hls),
        ('$hls?${'a' * 2049}', LiveStreamKind.hls),
        ('x', LiveStreamKind.hls),
      ]) {
        expect(
          _kindOf(() => LookliveEndpoints.mediaUri(raw, format: format)),
          LookliveFailureKind.apiChanged,
          reason: raw,
        );
      }
    });
  });

  group('room numbers and links', () {
    test('a room number is 2 to 18 digits without a leading zero', () {
      for (final (value, ok) in [
        ('7', false),
        ('21623631', true),
        ('0123', false),
        ('9' * 19, false),
        ('9' * 18, true),
      ]) {
        expect(LookliveEndpoints.isRoomNumber(value), ok, reason: value);
      }
      expect(LookliveEndpoints.roomIdOf(' 21623631 '), _video);
      expect(LookliveEndpoints.roomUrl(_video), 'https://look.163.com/live?id=$_video');
    });

    test('the room link rules', () {
      expect(LookliveEndpoints.roomIdFromUrl('https://look.163.com/live?id=21623631&position=3'), _video);
      expect(LookliveEndpoints.roomIdFromUrl('https://LOOK.163.com/live?id=21623631'), _video);
      expect(LookliveEndpoints.roomIdFromUrl('http://look.163.com/live?id=21623631'), _video);
      expect(LookliveEndpoints.roomIdFromUrl('https://look.163.com:443/live?id=21623631'), _video);
      expect(LookliveEndpoints.roomIdFromUrl('https://look.163.com/LIVE/?id=21623631'), _video);
      // Surrounding blanks are trimmed away first, as the reference does.
      expect(LookliveEndpoints.roomIdFromUrl('https://look.163.com/live?id=21623631\n'), _video);
      for (final url in [
        'https://look.163.com/live?id=21623631&id=2',
        'https://look.163.com/live?id=021623631',
        'https://look.163.com/live?id=7',
        'https://look.163.com/live',
        'https://look.163.com/other?id=21623631',
        'https://evil.com/live?id=21623631',
        'https://look.163.com.evil.test/live?id=21623631',
        'https://u@look.163.com/live?id=21623631',
        'https://look.163.com:8080/live?id=21623631',
        'https://look.163.com/live?id=21623631#x',
        'ftp://look.163.com/live?id=21623631',
        'https://look.163.com/live\n?id=21623631',
        'https://look.163.com/live?id=216236 31',
        'room',
      ]) {
        expect(LookliveEndpoints.roomIdFromUrl(url), isNull, reason: url);
      }
      expect(LookliveEndpoints.roomIdOf('https://look.163.com/live?id=21623631'), _video);
    });
  });

  group('chat servers', () {
    test('the recorded answer names four Yunxin servers, in order', () {
      final addressFrame = liveFrames.first;
      expect(addressFrame.url, 'https://api.look.163.com/weapi/livestream/chat/address');
      expect(LookliveRoomParser.chatAddresses(addressFrame.text), [
        'chatwl01.yunxinfw.com:443',
        'chatwl01-bgp.yunxinfw.com:443',
        'chatwl02-bgp.yunxinfw.com:443',
        'chatwl02.yunxinfw.com:443',
      ]);
    });

    test('host:port entries only, in order, once; a room that is not live is not-found', () {
      String answer(Object? address, {Object? code = 200}) => jsonEncode({
        'code': code,
        'msg': null,
        'message': code == 404 ? '无资源' : null,
        'data': code == 200 ? {'address': address} : null,
        'success': code == 200,
      });
      expect(
        LookliveRoomParser.chatAddresses(
          answer([
            ' CHATWL01.yunxinfw.com:443 ',
            'chatwl01.yunxinfw.com:443',
            'chatwl02.yunxinfw.com:8443',
            '127.0.0.1:9000',
            'chatwl03.yunxinfw.com',
            'chatwl04.yunxinfw.com:0',
            'chatwl05.yunxinfw.com:65536',
            'chatwl06.yunxinfw.com:443/path',
            'https://chatwl07.yunxinfw.com:443',
            'user@chatwl08.yunxinfw.com:443',
            'localhost:443',
            '-bad.yunxinfw.com:443',
            'chatwl09.yunxinfw.com:65535',
            443,
            null,
            {'host': 'chatwl10.yunxinfw.com'},
          ]),
        ),
        ['chatwl01.yunxinfw.com:443', 'chatwl02.yunxinfw.com:8443', '127.0.0.1:9000', 'chatwl09.yunxinfw.com:65535'],
      );
      expect(_kindOf(() => LookliveRoomParser.chatAddresses(answer(null, code: 404))), LookliveFailureKind.notFound);
      for (final address in [
        <Object?>[],
        ['nothing'],
        'chatwl01.yunxinfw.com:443',
        null,
        {'a': 1},
      ]) {
        expect(
          _kindOf(() => LookliveRoomParser.chatAddresses(answer(address))),
          LookliveFailureKind.apiChanged,
          reason: '$address',
        );
      }
      expect(_kindOf(() => LookliveRoomParser.chatAddresses(answer(null, code: 500))), LookliveFailureKind.apiChanged);
      expect(_kindOf(() => LookliveRoomParser.chatAddresses('not json')), LookliveFailureKind.apiChanged);
      expect(
        _kindOf(() => LookliveRoomParser.chatAddresses(answer(['chatwl01.yunxinfw.com:443']), status: 503)),
        LookliveFailureKind.network,
      );
      expect(
        _kindOf(() => LookliveRoomParser.chatAddresses(answer(['chatwl01.yunxinfw.com:443']), status: 403)),
        LookliveFailureKind.riskControl,
      );
    });
  });
}
