import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/huya/api/huya_http.dart';
import 'package:live_sites/src/platforms/huya/capabilities/huya_playback_provider.dart';
import 'package:live_sites/src/platforms/huya/capabilities/huya_room_provider.dart';
import 'package:live_sites/src/platforms/huya/huya_site.dart';
import 'package:live_sites/src/platforms/huya/huya_tars.dart';
import 'package:test/test.dart';

// Platform-internal code: constructor-name rules that govern the public
// surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The room the tests read.
const String _rid = '1234567';

/// The instant every answer is judged at.
final DateTime _now = DateTime.utc(2026, 11, 6, 12);

/// A `wsTime` an hour before [_now] plus [minutes], hexadecimal.
String _wsTime(int minutes) => (_now.add(Duration(minutes: minutes)).millisecondsSinceEpoch ~/ 1000).toRadixString(16);

/// A static web play token (no template): the whole token is the line query.
String _token(String wsTime) => 'wsTime=$wsTime&ctype=huya_webh5&t=100&fs=bgct';

/// A live `profileRoom` whose one FLV line sits on [host].
Map<String, Object?> _liveRoom(String host) => {
  'liveStatus': 'ON',
  'liveData': {'roomName': 'room', 'introduction': 'intro', 'bitRateInfo': '[]'},
  'profileInfo': {'nick': 'Ann', 'uid': 100, 'avatar180': 'https://img.huya.com/a.jpg'},
  'stream': {
    'baseSteamInfoList': [
      {
        'sCdnType': 'TX',
        'sFlvUrl': 'https://$host',
        'sStreamName': '$_rid-$_rid-5294329-2533951',
        'sFlvAntiCode': 'wsTime=${_wsTime(-1)}&ctype=huya_webh5&t=100',
        'lPresenterUid': 100,
      },
    ],
    'flv': {
      'multiLine': [
        {'cdnType': 'TX', 'url': 'https://$host/$_rid-$_rid-5294329-2533951.flv'},
      ],
    },
  },
};

/// A `profileRoom` body of [data].
String _profile(Object? data) => jsonEncode({'status': 200, 'message': '', 'data': data});

/// A `getCdnTokenInfoEx` answer naming [token].
Uint8List _tokenAnswer(String token) => WupPacket(
  servant: 'liveui',
  function: 'getCdnTokenInfoEx',
  params: {
    '': WupPacket.intParam(0),
    'tRsp': WupPacket.structParam(
      (writer) => writer
        ..writeString(0, token)
        ..writeInt(1, 0),
    ),
  },
).encode();

/// The transport under the site: `profileRoom` answers live on [hosts]' next
/// host (the last repeats), an [offlineFrom] read and past it answers OFF;
/// every play-token ask is [tokens]' next (the last repeats). The asks are
/// recorded, the profile and token reads counted.
final class _Api implements LiveHttp {
  _Api({required this.hosts, required this.tokens, this.offlineFrom});

  final List<String> hosts;
  final List<String> tokens;

  /// The profile read (counting the entry's) from which the room answers OFF.
  final int? offlineFrom;

  final asked = <Uri>[];
  int profileReads = 0;
  int tokenReads = 0;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final url = request.url;
    asked.add(url);
    if (url.host == 'wup.huya.com') {
      final token = tokenReads < tokens.length ? tokens[tokenReads] : tokens.last;
      tokenReads++;
      return LiveResponse(statusCode: 200, headers: const {}, bodyBytes: _tokenAnswer(token));
    }
    if (url.query.contains('do=profileRoom')) {
      final offline = offlineFrom != null && profileReads >= offlineFrom!;
      final host = profileReads < hosts.length ? hosts[profileReads] : hosts.last;
      profileReads++;
      return LiveResponse(
        statusCode: 200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
        bodyBytes: Uint8List.fromList(utf8.encode(_profile(offline ? {'liveStatus': 'OFF'} : _liveRoom(host)))),
      );
    }
    throw StateError('unexpected ask $url');
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}

HuyaSite _site(_Api api) => HuyaSite(http: HuyaHttp(api), loginCookie: () => 'yyuid=123456;', now: () => _now);

void main() {
  group('recovery', () {
    test('the shared entry serves the lines; recovery reads profileRoom and signs a new token', () async {
      final api = _Api(
        hosts: ['hw.flv.huya.com', 'tx.flv.huya.com'],
        tokens: [_token(_wsTime(-1)), _token(_wsTime(3))],
      );
      final site = _site(api);
      final playback = site.capability<LivePlaybackProvider>()! as HuyaPlaybackProvider;

      final room = await (site.capability<LiveRoomProvider>()! as HuyaRoomProvider).detail(_rid);
      expect(api.asked, hasLength(1), reason: 'the entry reads the room once');
      final held = (await playback.getLines(room: room)).getOrElse((error) => fail('$error'));
      expect(held, hasLength(1));
      expect(held.single.url, startsWith('https://hw.flv.huya.com/'));
      expect(api.profileReads, 1, reason: 'the shared answer serves the lines with no read of its own');

      final recovery = site.capability<LivePlayRecovery>();
      expect(recovery, isNotNull);
      final fresh = (await recovery!.refetchLines(room: room)).getOrElse((error) => fail('$error'));
      expect(fresh, hasLength(1));
      expect(
        fresh.single.url,
        startsWith('https://tx.flv.huya.com/'),
        reason: 'the fresh answer names the host, never the kept one',
      );
      expect(fresh.single.url, contains(_wsTime(3)), reason: 'the fresh token is the one the line carries');
      expect(api.profileReads, 2, reason: 'recovery reads profileRoom again, inside the share window');
      expect(api.tokenReads, 2, reason: 'recovery signs with a token fetched now');
      expect(api.asked, hasLength(4), reason: 'one profileRoom and one token per read');
    });

    test('a room that went off air meanwhile says so, and no line is handed back', () async {
      final api = _Api(hosts: ['hw.flv.huya.com'], tokens: [_token(_wsTime(-1))], offlineFrom: 1);
      final site = _site(api);
      final playback = site.capability<LivePlaybackProvider>()! as HuyaPlaybackProvider;

      final room = await (site.capability<LiveRoomProvider>()! as HuyaRoomProvider).detail(_rid);
      expect((await playback.getLines(room: room)).getOrElse((error) => fail('$error')), hasLength(1));

      final answer = await site.capability<LivePlayRecovery>()!.refetchLines(room: room);
      expect(answer.getLeft().toNullable(), isA<LiveSiteContentUnavailable>());
      expect(api.profileReads, 2, reason: 'the fresh read is what says the room is off air');
      expect(api.tokenReads, 1, reason: 'no token is asked for a room that cannot play');
      expect(api.asked, hasLength(3));
    });
  });
}
