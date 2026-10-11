// Module: test/weibo/weibo_source_test.dart
// Purpose: The Weibo source against a canned transport: the finite snapshot, the identity check, the access gate
// and the play url.
// Author: liuchuancong
// Created: 2026-10-11
//
// Bodies are written to the field names the v1 line reads, not recorded from the site (see README 未验证).

import 'dart:convert';

import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_network/testing.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_sites/pure_live_sites.dart';
import 'package:test/test.dart';

const String _directoryKey = 'weibo.com/l/!/2/wblive/pc_recommend/list.json';
const String _roomKey = 'weibo.com/l/!/2/wblive/room/show_pc_live.json';

final DateTime _now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

const ContentRef _room9 = ContentRef(sourceId: 'weibo.live', contentId: '9001', kind: ContentKind.liveRoom);

NetworkClient _client(ScriptedTransport transport) => NetworkClient(
  adapter: transport,
  clock: () => _now,
  settings: const NetworkSettings(retry: RetryPolicy(attempts: 1)),
);

(ScriptedTransport, WeiboSource) _source(Map<String, List<String>> script) {
  final transport = ScriptedTransport(script);
  return (transport, WeiboSource(client: _client(transport), clock: () => _now));
}

String _envelope(Map<String, Object?> data) =>
    jsonEncode(<String, Object?>{'code': 100000, 'error_code': 0, 'data': data});

String _directory({List<Object?> rows = const <Object?>[]}) => _envelope(<String, Object?>{'data': rows});

Map<String, Object?> _card(String id, {String nickname = '主播甲'}) => <String, Object?>{
  'liveid': id,
  'uid': 7000,
  'nickname': nickname,
  'cover': 'https://c/$id.jpg',
};

String _room({
  String liveId = '9001',
  int uid = 7000,
  int status = 1,
  int watchLimit = 0,
  int playSwitch = 1,
  String? flv = 'https://media.example/a.flv?sign=1',
  String? hls = 'https://media.example/a.m3u8?sign=1',
}) => _envelope(<String, Object?>{
  'liveId': liveId,
  'status': status,
  'watch_limit': watchLimit,
  'play_switch': playSwitch,
  'pay_live_status': 1,
  'title': '深夜闲聊',
  'cover': 'https://c/9001.jpg',
  'width': 1920,
  'height': 1080,
  'live_origin_flv_url': flv,
  'live_origin_hls_url': hls,
  'user': <String, Object?>{'uid': uid, 'screenName': '主播甲', 'profileImageUrl': '//a/7000.gif'},
});

void main() {
  group('test_weiboSource_feed', () {
    test('test_theSnapshotIsOnePageAndSaysSo', () async {
      final (transport, weibo) = _source(<String, List<String>>{
        _directoryKey: <String>[
          _directory(
            rows: <Object?>[
              _card('9001'),
              _card('9002', nickname: '乙'),
            ],
          ),
        ],
      });
      final page = await weibo.feed(PageRequest.first);
      expect(page.items, hasLength(2));
      expect(page.mode, PageMode.singleShot);
      expect(page.hasMore, isFalse);
      expect(page.total, 2);
      expect(page.items.first.title, '主播甲');
      expect(transport.unconsumedKeys, isEmpty);
    });

    test('test_aSecondPageIsNothingRatherThanTheSameRoomsAgain', () async {
      final (transport, weibo) = _source(<String, List<String>>{
        _directoryKey: <String>[
          _directory(rows: <Object?>[_card('9001')]),
        ],
      });
      final page = await weibo.feed(const PageRequest(page: 2));
      expect(page.items, isEmpty);
      // Not asking again is the point: the second request is what turns a snapshot into an endless list.
      expect(transport.requestsTo(_directoryKey), 0);
    });

    test('test_aDuplicatedRoomIsRefusedNotDeDuplicatedQuietly', () async {
      final (_, weibo) = _source(<String, List<String>>{
        _directoryKey: <String>[
          _directory(rows: <Object?>[_card('9001'), _card('9001')]),
        ],
      });
      await expectLater(weibo.feed(PageRequest.first), throwsA(isA<WeiboFailure>()));
    });

    test('test_noCategoriesAreClaimed', () async {
      final (_, weibo) = _source(<String, List<String>>{});
      expect(await weibo.categories(), isEmpty);
      await expectLater(weibo.browse(const ContentQuery(category: '热门')), throwsA(isA<StateError>()));
    });

    test('test_aRefusalCodeIsNotAnEmptyList', () async {
      final (_, weibo) = _source(<String, List<String>>{
        _directoryKey: <String>[
          jsonEncode(<String, Object?>{'code': 100001, 'error_code': 0}),
        ],
      });
      // A refusal read as "this site has nothing" is the failure a viewer cannot distinguish from an empty page.
      await expectLater(weibo.feed(PageRequest.first), throwsA(isA<WeiboFailure>()));
    });
  });

  group('test_weiboSource_room', () {
    test('test_theRoomAnswerBecomesLivedRoomFieldsWithItsGate', () async {
      final (_, weibo) = _source(<String, List<String>>{
        _roomKey: <String>[_room()],
      });
      final room = await weibo.room(_room9);
      expect(room.state, LiveRoomState.live);
      expect(room.title, '深夜闲聊');
      expect(room.anchorName, '主播甲');
      expect(room.anchorId, '7000');
      expect(room.requiresAuth, isFalse);
      expect(room.extra['size'], '1920x1080');
    });

    test('test_anAnswerAboutSomeoneElseIsRefused', () async {
      final (_, weibo) = _source(<String, List<String>>{
        _roomKey: <String>[_room(liveId: '9002')],
      });
      await expectLater(weibo.room(_room9), throwsA(isA<WeiboFailure>()));
    });

    test('test_anUnrecognisedStatusIsUnknownNotFinished', () async {
      final (_, weibo) = _source(<String, List<String>>{
        _roomKey: <String>[_room(status: 77)],
      });
      final room = await weibo.room(_room9);
      expect(room.state, LiveRoomState.unknown);
      expect(room.isLive, isFalse);
    });

    test('test_aGatedRoomSaysSoInsteadOfShowingABlackScreen', () async {
      final (_, weibo) = _source(<String, List<String>>{
        _roomKey: <String>[_room(watchLimit: 12)],
      });
      final room = await weibo.room(_room9);
      expect(room.requiresAuth, isTrue);
      expect(room.extra['watchLimit'], 12);
      await expectLater(weibo.resolve(_room9), throwsA(isA<StateError>()));
    });

    test('test_aRoomWithPlaybackSwitchedOffHasNoLines', () async {
      final (_, weibo) = _source(<String, List<String>>{
        _roomKey: <String>[_room(playSwitch: 0)],
      });
      expect(await weibo.lines(_room9), isEmpty);
      await expectLater(weibo.resolve(_room9), throwsA(isA<StateError>()));
    });

    test('test_aTrialUrlUnderAPaidGateIsNeverHandedOut', () async {
      // pay_live_status says the broadcast is paid even though the answer carries urls; presence is not
      // permission, so the gated reading must expose none of them.
      final (_, weibo) = _source(<String, List<String>>{
        _roomKey: <String>[_room(watchLimit: 8)],
      });
      expect(await weibo.lines(_room9), isEmpty);
      await expectLater(weibo.resolve(_room9), throwsA(isA<StateError>()));
    });
  });

  group('test_weiboSource_play', () {
    test('test_resolve_opensTheFlvFirstAndNumbersThePaths', () async {
      final (_, weibo) = _source(<String, List<String>>{
        _roomKey: <String>[_room()],
      });
      final ticket = await weibo.resolve(_room9);
      expect(ticket.uri.path, '/a.flv');
      expect(ticket.metadata.extra['container'], 'flv');
      expect(ticket.metadata.extra['weibo.line'], 1);
      expect(ticket.headers['referer'], 'https://weibo.com/l/wblive/');
    });

    test('test_lines_areTheSitesOwnUrlsWithoutInventedNames', () async {
      final (_, weibo) = _source(<String, List<String>>{
        _roomKey: <String>[_room()],
      });
      final lines = await weibo.lines(_room9);
      expect(lines.map((line) => line.id), <String>['1', '2']);
      expect(lines.first.label, isNull);
      expect(lines.first.isDefault, isTrue);
    });

    test('test_aLineBeyondTheAnswerIsRefused', () async {
      final (_, weibo) = _source(<String, List<String>>{
        _roomKey: <String>[_room(hls: null)],
      });
      await expectLater(weibo.resolve(_room9, line: const SelectionRef('2')), throwsA(isA<StateError>()));
    });

    test('test_anOfflineRoomIsNamedNotAnEmptyTicket', () async {
      final (_, weibo) = _source(<String, List<String>>{
        _roomKey: <String>[_room(status: 5, flv: null, hls: null)],
      });
      await expectLater(weibo.resolve(_room9), throwsA(isA<StateError>()));
    });

    test('test_refresh_reopensTheSameLineAndRefusesForeignTickets', () async {
      final (_, weibo) = _source(<String, List<String>>{
        _roomKey: <String>[_room()],
      });
      final first = await weibo.resolve(_room9, line: const SelectionRef('2'));
      final second = await weibo.refresh(first, RefreshReason.expiring);
      expect(second.uri, first.uri);
      await expectLater(
        weibo.refresh(
          MediaTicket(
            id: 'douyu.live/1',
            uri: Uri.parse('https://example/x.flv'),
            kind: MediaKind.live,
            protocol: MediaProtocol.https,
            createdAt: _now.toUtc(),
          ),
          RefreshReason.manual,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('test_anOwnerIdOnTheRefIsCheckedAgainstTheAnswer', () async {
      final (_, weibo) = _source(<String, List<String>>{
        _roomKey: <String>[_room(uid: 7001)],
      });
      final ref = ContentRef(
        sourceId: weiboSourceId,
        contentId: '9001',
        kind: ContentKind.liveRoom,
        metadata: <String, Object?>{'ownerId': 7000},
      );
      await expectLater(weibo.resolve(ref), throwsA(isA<WeiboFailure>()));
    });

    test('test_aNonNumericLiveIdNeverReachesTheEndpoint', () async {
      final (transport, weibo) = _source(<String, List<String>>{
        _roomKey: <String>[_room()],
      });
      await expectLater(
        weibo.room(const ContentRef(sourceId: 'weibo.live', contentId: '99/../x', kind: ContentKind.liveRoom)),
        throwsA(isA<WeiboFailure>()),
      );
      expect(transport.requestsTo(_roomKey), 0);
    });

    test('test_anHtmlLoginWallIsReportedAsWhatItIs', () async {
      final (_, weibo) = _source(<String, List<String>>{
        _roomKey: <String>['<html>登录</html>'],
      });
      await expectLater(weibo.room(_room9), throwsA(isA<WeiboFailure>()));
    });
  });
}
