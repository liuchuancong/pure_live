// Module: test/live_room_test.dart
// Purpose: Each site's reader turns its own room envelope into the shared LiveRoom, with the live facts as fields.
// Author: liuchuancong
// Created: 2026-10-11
//
// The three readers are pure functions over an already-parsed envelope, so they are tested as such - the transport
// paths that fetch those envelopes belong to each site's own suite. What is pinned here is the mapping a room page
// and a follow-list poller actually consume: state, the anchor, the audience figure, and the two flags a source
// must not guess at.

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_sites/pure_live_sites.dart';
import 'package:test/test.dart';

ContentRef _ref(String source, String id) => ContentRef(sourceId: source, contentId: id, kind: ContentKind.liveRoom);

void main() {
  group('test_huyaLiveRoom', () {
    test('test_aProfileBecomesFieldsNotStringKeys', () {
      final profile = HuyaRoomProfile.fromJson('123456', <String, Object?>{
        'liveStatus': 1,
        'liveData': <String, Object?>{
          'sRoomName': '午夜电台',
          'nick': '主播甲',
          'introduction': '今晚打联盟',
          'screenshot': 'https://img.huya.com/s.jpg',
          'userCount': 98765,
        },
        'stream': <String, Object?>{
          'baseSteamInfoList': <Object?>[
            <String, Object?>{'sStreamName': 'hd-x', 'sHlsUrl': 'https://a/', 'sHlsUrlSuffix': 'm3u8'},
            <String, Object?>{'sStreamName': 'hd-x', 'sHlsUrl': 'https://b/', 'sHlsUrlSuffix': 'm3u8'},
          ],
        },
      });
      final room = huyaLiveRoom(profile);
      expect(room.state, LiveRoomState.live);
      expect(room.title, '午夜电台');
      expect(room.anchorName, '主播甲');
      expect(room.cover, 'https://img.huya.com/s.jpg');
      expect(room.viewers, 98765);
      // The per-broadcast stream name, never the room's identity.
      expect(room.streamId, 'hd-x');
      expect(room.extra['cdnLines'], 2);
      expect(room.summary.ref, room.ref);
      expect(room.anchor()?.currentRoom, room.ref);
    });

    test('test_anAbsentLiveFlagIsUnknownNotEnded', () {
      final room = huyaLiveRoom(HuyaRoomProfile.fromJson('1', <String, Object?>{'liveData': <String, Object?>{}}));
      // A poll that timed out reads here; storing it as "finished" stops a follow list watching a live room.
      expect(room.state, LiveRoomState.unknown);
      expect(room.isLive, isFalse);
      expect(room.anchor(), isNull, reason: 'no anchor name means no person to link to');
    });

    test('test_huyaNeverClaimsAPaywallItWasNotToldAbout', () {
      final room = huyaLiveRoom(
        HuyaRoomProfile.fromJson('1', <String, Object?>{'liveStatus': 1, 'liveData': <String, Object?>{}}),
      );
      expect(room.requiresAuth, isFalse);
      expect(room.isScheduled, isFalse);
    });
  });

  group('test_douyuLiveRoom', () {
    test('test_aProfileDocumentBecomesFields', () {
      final room = douyuLiveRoom(<Object?, Object?>{
        'room_id': 123,
        'room_name': '房间一',
        'owner_name': '主播一',
        'owner_id': 900,
        'second_lvl_name': '星球',
        'show_details': '简介',
        'room_pic': '//p/1.jpg',
        'show_status': 1,
        'videoLoop': 0,
        'show_time': 1700000000,
        'room_biz_all': <String, Object?>{'hot': 2048},
      }, roomId: '123');
      expect(room.state, LiveRoomState.live);
      expect(room.title, '房间一');
      expect(room.anchorName, '主播一');
      // The anchor id is separate from the room id here, so the person and the room do not collapse into one ref.
      expect(room.anchorId, '900');
      expect(room.anchor()?.ref.kind, ContentKind.anchor);
      expect(room.anchor()?.ref.contentId, '900');
      expect(room.cover, 'https://p/1.jpg');
      expect(room.viewers, 2048);
      expect(room.startedAt, DateTime.utc(2023, 11, 14, 22, 13, 20));
      expect(room.extra['showStatus'], 1);
    });

    test('test_aReplayLoopIsEndedAndCarriesNoStartTime', () {
      final room = douyuLiveRoom(<Object?, Object?>{
        'room_id': 123,
        'room_name': '【回放】昨天的直播',
        'show_status': 1,
        'videoLoop': 1,
        'show_time': 1700000000,
      }, roomId: '123');
      expect(room.state, LiveRoomState.ended);
      expect(room.startedAt, isNull, reason: 'an ended broadcast does not report a running clock');
    });

    test('test_aRoomWithoutTheBusinessBlockHasNoAudienceRatherThanZero', () {
      final room = douyuLiveRoom(<Object?, Object?>{'room_id': 1, 'show_status': 1}, roomId: '1');
      expect(room.viewers, isNull);
      expect(room.title, '1', reason: 'a nameless room is still addressable by its id');
    });
  });

  group('test_acfunLiveRoom', () {
    test('test_thePaidShowGateIsTheOneThingThatExplainsABlackScreen', () {
      final envelope = <String, Object?>{
        'authorId': '1001',
        'title': '深夜分类',
        'onlineCount': 42,
        'liveId': '900001',
        'streamName': 'acflv-900001',
        'createTime': 1700000000000,
        'paidShowUuid': 'paid-1',
        'paidShowUserBuyStatus': false,
        'user': <String, Object?>{'id': '1001', 'name': '主播甲', 'headUrl': '//avatar/a.png', 'fanCountValue': '1.2万'},
        'type': <String, Object?>{'name': '手游'},
      };
      final room = AcfunApi.liveRoom('1001', envelope, live: true);
      expect(room.state, LiveRoomState.live);
      expect(room.requiresAuth, isTrue);
      expect(room.streamId, '900001');
      expect(room.viewers, 42);
      expect(room.startedAt, DateTime.utc(2023, 11, 14, 22, 13, 20));
      // The page gives a label, not a number: it stays a label instead of becoming our arithmetic.
      expect(room.followers, isNull);
      expect(room.extra['followers'], '1.2万');
    });

    test('test_aBoughtPaidShowIsNotAGate', () {
      final room = AcfunApi.liveRoom('1001', <String, Object?>{
        'authorId': '1001',
        'liveId': '9',
        'streamName': 's',
        'paidShowUuid': 'paid-1',
        'paidShowUserBuyStatus': true,
        'user': <String, Object?>{'id': '1001', 'name': '甲'},
      }, live: true);
      expect(room.requiresAuth, isFalse);
    });

    test('test_anOfflineRoomHasNoStreamIdToReuse', () {
      final room = AcfunApi.liveRoom('1001', <String, Object?>{
        'authorId': '1001',
        'user': <String, Object?>{'id': '1001', 'name': '甲'},
      }, live: false);
      expect(room.state, LiveRoomState.ended);
      expect(room.streamId, isNull);
      expect(room.isLive, isFalse);
    });
  });

  group('test_liveRoomJson', () {
    test('test_roundTripsThroughTheGeneratedModel', () {
      final room = LiveRoom(
        ref: _ref('acfun.live', '1001'),
        state: LiveRoomState.live,
        title: '深夜分类',
        anchorName: '甲',
        viewers: 42,
        tags: const <String>['电竞'],
        extra: const <String, Object?>{'followers': '1.2万'},
      );
      expect(LiveRoom.fromJson(room.toJson()), room);
    });

    test('test_anUnknownStateStringIsUnknownNotACrash', () {
      final room = LiveRoom.fromJson(<String, Object?>{
        'ref': <String, Object?>{'sourceId': 'acfun.live', 'contentId': '1', 'kind': 'liveRoom'},
        'state': 'replaying',
        'title': '',
      });
      expect(room.state, LiveRoomState.unknown);
      expect(room.isLive, isFalse);
    });

    test('test_aViewersFieldWrittenAsTextIsStillCounted', () {
      final room = LiveRoom.fromJson(<String, Object?>{
        'ref': <String, Object?>{'sourceId': 'huya.live', 'contentId': '1', 'kind': 'liveRoom'},
        'state': 'live',
        'title': 't',
        'viewers': '98765',
        'tags': <Object?>['', '热门', null],
      });
      expect(room.viewers, 98765);
      // Blank and null entries are not tags; the list keeps only what the source actually said.
      expect(room.tags, <String>['热门']);
    });
  });
}
