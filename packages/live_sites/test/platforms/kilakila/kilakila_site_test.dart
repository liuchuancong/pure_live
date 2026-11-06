import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kilakila/api/kilakila_endpoints.dart';
import 'package:live_sites/src/platforms/kilakila/api/kilakila_http.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_site.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

const String _uid = '501';
final DateTime _issued = DateTime.utc(2026, 10, 1, 4);

/// The transport under the site: every URL asked is recorded, and the answer
/// is the handler's for the path.
final class _Http implements LiveHttp {
  _Http(this.answer);

  final String Function(Uri url) answer;
  final asked = <Uri>[];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    asked.add(request.url);
    return LiveResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
      bodyBytes: Uint8List.fromList(utf8.encode(answer(request.url))),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

Map<String, Object?> _user() => {'id': _uid, 'nickname': '主播甲', 'headPortraitUrl': 'https://img.kilakila.cn/a.jpg'};

/// A broadcast [id] of the anchor, live.
Map<String, Object?> _broadcast(String id) => {
  'roomIdStr': id,
  'uid': _uid,
  'title': '直播标题',
  'status': 4,
  'goldPrice': 0,
  'backPic': 'https://img.kilakila.cn/cover.jpg',
};

/// The anchor's profile, advertising the broadcast [id].
String _profile(String id) => jsonEncode({
  'code': 200,
  'data': {'userResp': _user(), 'liveCard': _broadcast(id)},
});

/// `getRoomInfo` of the broadcast [id], with its two signed pull URLs.
String _info(String id) {
  final expires = _issued.add(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000;
  String pull(String extension) =>
      'https://${KilakilaEndpoints.mediaHost}/hrs/$id.$extension?auth_key=$expires-0-0-md5';
  return jsonEncode({
    'h': {'code': 200, 'success': true},
    'b': {..._broadcast(id), 'userInfo': _user(), 'flvPlayUrl': pull('flv'), 'hlsPlayUrl': pull('m3u8')},
  });
}

void main() {
  group('search', () {
    test('a keyword past the limit is cut where it is sent, not refused', () async {
      final http = _Http((_) => '<html><div class="userList"></div></html>');
      final site = KilakilaSite(http: KilakilaHttp(http));
      final page = await site.search('主播' * 60);
      expect(page.rooms, isEmpty);
      final sent = http.asked.single;
      expect(sent.pathSegments.take(3), ['aboutus', 'serach', 'kw']);
      expect(sent.pathSegments[3], '主播' * 50, reason: '100 code units of the 120 typed');
    });

    test('a keyword within the limit goes out as typed, trimmed', () async {
      final http = _Http((_) => '<html><div class="userList"></div></html>');
      await KilakilaSite(http: KilakilaHttp(http)).search('  主播  ', page: 2);
      expect(http.asked.single.pathSegments, ['aboutus', 'serach', 'kw', '主播', 'p', '2']);
    });
  });

  group('recovery', () {
    test('the held stream serves the lines; recovery enters the anchor again', () async {
      var current = '7001';
      final http = _Http(
        (url) => url.path == '/Tg/personalH5' ? _profile(current) : _info(url.queryParameters['roomId']!),
      );
      final site = KilakilaSite(http: KilakilaHttp(http), now: () => _issued);
      final room = await site.detail(_uid);
      expect(http.asked, hasLength(2), reason: 'the profile, then the broadcast');

      final playback = site.capability<LivePlaybackProvider>()!;
      final held = (await playback.getLines(room: room)).getOrElse((error) => fail('$error'));
      expect(held.map((line) => line.format), [LiveStreamFormat.flv, LiveStreamFormat.hls]);
      expect(held.first.url, contains('/hrs/7001.flv'));
      expect(http.asked, hasLength(2), reason: 'the held stream data needs no request');

      // The anchor went live again on a new broadcast with new pull URLs.
      current = '7002';
      final recovery = site.capability<LivePlayRecovery>();
      expect(recovery, isNotNull);
      final fresh = (await recovery!.refetchLines(room: room)).getOrElse((error) => fail('$error'));
      expect(http.asked, hasLength(4), reason: 'recovery reads the profile and the broadcast again');
      expect(fresh.first.url, contains('/hrs/7002.flv'));
      expect(fresh.last.url, contains('/hrs/7002.m3u8'));
      expect(fresh.last.lease?.requiresReconnect, isTrue, reason: 'an HLS playlist stops at its expiry');

      // The fresh entry is now the one held.
      final again = (await playback.getLines(room: room)).getOrElse((error) => fail('$error'));
      expect(again.first.url, contains('/hrs/7002.flv'));
      expect(http.asked, hasLength(4));
    });

    test('an anchor without a broadcast cannot be recovered', () async {
      final http = _Http(
        (_) => jsonEncode({
          'code': 200,
          'data': {'userResp': _user(), 'liveCard': <String, Object?>{}},
        }),
      );
      final site = KilakilaSite(http: KilakilaHttp(http), now: () => _issued);
      final room = LiveRoom.normalized(platform: 'kilakila', roomId: _uid);
      final answer = await site.capability<LivePlayRecovery>()!.refetchLines(room: room);
      expect(answer.isLeft(), isTrue);
      expect(http.asked, hasLength(1), reason: 'the profile says there is no broadcast');
    });
  });
}
