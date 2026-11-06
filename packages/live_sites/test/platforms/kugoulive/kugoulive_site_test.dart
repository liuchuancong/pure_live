import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_status_check.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kugoulive/api/kugoulive_endpoints.dart';
import 'package:live_sites/src/platforms/kugoulive/api/kugoulive_http.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_site.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

const String _room = '1234567';

/// The transport under the site: every URL asked is recorded, and the answer
/// is the handler's for it.
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

/// `getEnterRoomInfo` of the room: live with a session, offline with
/// `liveType` -1, or neither.
String _info({String session = '6709e5c0h1a', int? liveType}) => jsonEncode({
  'code': 0,
  'data': {
    'normalRoomInfo': {'nickName': '主播', 'kugouId': '26', 'userId': '88'},
    'liveSessionId': session,
    'liveType': ?liveType,
  },
});

/// A stream answer of one FLV variant signed with [secret].
String _stream(String secret) => jsonEncode({
  'code': 0,
  'data': {
    'roomId': int.parse(_room),
    'status': 1,
    'lines': [
      {
        'sid': 5,
        'streamProfiles': [
          {
            'rate': 4,
            'codec': 1,
            'layout': 2,
            'httpsFlv': ['https://liveplay.live.kugou.com/live/a.flv?txSecret=$secret&txTime=6709e5c0'],
          },
        ],
      },
    ],
  },
});

bool _isStream(Uri url) => url.path.endsWith('/streamaddr');

void main() {
  group('recovery', () {
    test('the kept variants serve the lines; recovery enters the room again', () async {
      var secret = 'first';
      final http = _Http((url) => _isStream(url) ? _stream(secret) : _info());
      final site = KugouliveSite(http: KugouliveHttp(http));
      final room = await site.detail(_room);
      expect(http.asked, hasLength(2), reason: 'the room info, then the stream answer');

      final playback = site.capability<LivePlaybackProvider>()!;
      final held = (await playback.getLines(room: room)).getOrElse((error) => fail('$error'));
      expect(held.single.url, contains('txSecret=first'));
      expect(held.single.lineLabel, 'sid5');
      expect(http.asked, hasLength(2), reason: 'the kept variants need no request');

      secret = 'second';
      final recovery = site.capability<LivePlayRecovery>();
      expect(recovery, isNotNull);
      final fresh = (await recovery!.refetchLines(room: room)).getOrElse((error) => fail('$error'));
      expect(fresh.single.url, contains('txSecret=second'));
      expect(http.asked.skip(2).map((url) => url.host), [KugouliveEndpoints.roomHost, KugouliveEndpoints.apiHost]);
    });

    test('a room no longer live is not recovered', () async {
      var live = true;
      final http = _Http((url) => _isStream(url) ? _stream('s') : (live ? _info() : _info(session: '', liveType: -1)));
      final site = KugouliveSite(http: KugouliveHttp(http));
      final room = await site.detail(_room);
      live = false;
      final answer = await site.capability<LivePlayRecovery>()!.refetchLines(room: room);
      expect(answer.getLeft().toNullable(), isA<LiveSiteContentUnavailable>());
      expect(http.asked, hasLength(3), reason: 'the offline room info ends it before a stream request');
    });
  });

  group('the one-bit status', () {
    LiveRoom card() => LiveRoom.normalized(platform: 'kugoulive', roomId: _room);

    test('a live session is live, liveType -1 is offline', () async {
      final live = KugouliveSite(http: KugouliveHttp(_Http((_) => _info())));
      expect((await live.capability<LiveStatusCheck>()!.getLiveStatus(room: card())).toNullable(), isTrue);
      final offline = KugouliveSite(http: KugouliveHttp(_Http((_) => _info(session: '', liveType: -1))));
      expect((await offline.capability<LiveStatusCheck>()!.getLiveStatus(room: card())).toNullable(), isFalse);
    });

    test('a room with neither has no answer, never an invented offline', () async {
      final site = KugouliveSite(http: KugouliveHttp(_Http((_) => _info(session: '', liveType: 2))));
      final answer = await site.capability<LiveStatusCheck>()!.getLiveStatus(room: card());
      expect(answer.getLeft().toNullable(), isA<LiveSiteParseError>());
    });
  });
}
