import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/pandalive/api/pandalive_endpoints.dart';
import 'package:live_sites/src/platforms/pandalive/api/pandalive_http.dart';
import 'package:live_sites/src/platforms/pandalive/pandalive_site.dart';
import 'package:test/test.dart';

const String _id = 'tester_1';

/// The broadcaster's number (`bjInfo.idx`).
const int _index = 60321;

/// One request the site made, as the tests read it.
final class _Seen {
  new(LiveRequest request) : method = request.method, path = request.url.path;

  final String method;
  final String path;
}

/// The transport the tests answer through [onSend].
final class _Router implements LiveHttp {
  new(this.onSend);

  final FutureOr<LiveResponse> Function(_Seen request) onSend;
  final List<_Seen> sent = [];

  List<_Seen> get posts => sent.where((seen) => seen.method == 'POST').toList();

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final seen = _Seen(request);
    sent.add(seen);
    return await onSend(seen);
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}

LiveResponse _resp(int status, Object body) => LiveResponse(
  statusCode: status,
  headers: const {},
  bodyBytes: body is String ? Uint8List.fromList(utf8.encode(body)) : Uint8List.fromList(body as List<int>),
);

/// A `member/bj` answer of [live] being listed (an [adult] broadcast).
String _memberBody({bool live = true, bool adult = false}) => jsonEncode({
  'result': true,
  'bjInfo': {
    'id': _id,
    'idx': _index,
    'nick': '主播甲',
    'channelTitle': '频道名',
    'channelDesc': '频道介绍',
    'channelBannerUrl': 'https://img.pandalive.co.kr/banner.jpg',
    'thumbUrl': 'https://img.pandalive.co.kr/avatar.jpg',
    'fanCnt': 900,
  },
  if (live)
    'media': {
      'userId': _id,
      'userIdx': _index,
      'isLive': true,
      'title': '直播标题',
      'userNick': '主播甲',
      'userImg': 'https://img.pandalive.co.kr/live_avatar.jpg',
      'thumbUrl': 'https://img.pandalive.co.kr/live_cover.jpg',
      'category': 'game',
      'user': 30,
      'playCnt': 4000,
      'fanCnt': 1000,
      'startTime': '2026-09-28 02:00:35',
      'type': 'free',
      if (adult) 'isAdult': true,
    },
});

void main() {
  group('the follow refresh', () {
    test('a broadcaster listed live refreshes to its broadcast, with its restriction', () async {
      final http = _Router((seen) async {
        expect(seen.path, PandaliveEndpoints.memberPath);
        return _resp(200, _memberBody(adult: true));
      });
      final site = PandaliveSite(http: PandaliveHttp(http));
      final room = await site.refreshRoom(_id);
      expect(room.roomId, _id);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.restriction, LiveRestriction.adult);
      expect(room.content.notice, PandaliveEndpoints.adultNotice);
      expect(room.audience.onlineViewers, 30);
      expect(http.posts, hasLength(1), reason: 'the refresh is the member answer alone');
    });

    test('a broadcaster not listed refreshes to the offline profile room', () async {
      final http = _Router((seen) async => _resp(200, _memberBody(live: false)));
      final site = PandaliveSite(http: PandaliveHttp(http));
      final room = await site.refreshRoom(_id);
      expect(room.roomId, _id);
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.broadcast.restriction, isNull);
      expect(room.content.notice, PandaliveEndpoints.chatNotice);
      expect(http.posts, hasLength(1), reason: 'the refresh is the member answer alone');
    });
  });
}
