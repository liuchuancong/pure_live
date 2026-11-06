import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/platforms/tiktok/api/tiktok_http.dart';
import 'package:live_sites/src/platforms/tiktok/capabilities/tiktok_playback_provider.dart';
import 'package:live_sites/src/platforms/tiktok/tiktok_site.dart';
import 'package:test/test.dart';

/// The username the tests read.
const String _user = 'ann';

/// The instant the answers are issued at (the start of the URLs' lifetime).
final DateTime _issuedAt = DateTime.utc(2026, 9, 27, 12);

/// A pull URL of [file], signed for fourteen days from the issue instant.
String _pull(String file) {
  final expire = _issuedAt.add(const Duration(days: 14)).millisecondsSinceEpoch ~/ 1000;
  return 'https://pull.tiktokcdn-us.com/live/$file?expire=$expire';
}

/// `api-live/user/room` for [_user], live with one H.264 origin stream.
String _room() {
  String sdk(String codec) => jsonEncode({'VCodec': codec, 'resolution': '720x1280', 'vbitrate': 1200000});
  String tier(String codec) => jsonEncode({
    'data': {
      'origin': {
        'main': {'flv': _pull('a.flv'), 'hls': _pull('a.m3u8'), 'sdk_params': sdk(codec)},
      },
    },
  });
  return jsonEncode({
    'statusCode': 0,
    'data': {
      'user': {'uniqueId': _user, 'id': '123456789012345', 'nickname': 'Ann', 'status': 2},
      'liveRoom': {
        'status': 2,
        'title': '直播',
        'startTime': _issuedAt.millisecondsSinceEpoch ~/ 1000 - 60,
        'liveRoomStats': {'userCount': 5, 'enterCount': 9},
        'streamData': {
          'pull_data': {
            'stream_data': tier('h264'),
            'options': {
              'qualities': [
                {'sdk_key': 'origin', 'name': 'Original'},
              ],
            },
          },
        },
      },
    },
  });
}

/// The transport answering every request with the room answer and recording
/// the asks.
final class _Api implements LiveHttp {
  final List<Uri> asked = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    asked.add(request.url);
    return LiveResponse(
      statusCode: 200,
      headers: const {},
      bodyBytes: Uint8List.fromList(utf8.encode(_room())),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}

void main() {
  group('recovery', () {
    test('the held streams serve the lines; recovery reads the LIVE again', () async {
      final api = _Api();
      final site = TiktokSite(http: TiktokHttp(api), now: () => _issuedAt);
      final playback = site.capability<LivePlaybackProvider>()! as TiktokPlaybackProvider;

      final room = await site.detail(_user);
      expect(api.asked, hasLength(1));
      final lines = (await playback.getLines(room: room)).getOrElse((_) => throw StateError('no lines'));
      expect(lines, isNotEmpty);
      expect(api.asked, hasLength(1), reason: 'the streams room entry brought serve the lines');

      final recovery = site.capability<LivePlayRecovery>();
      expect(recovery, isNotNull);
      final fresh = (await recovery!.refetchLines(room: room)).getOrElse((_) => throw StateError('no fresh lines'));
      expect(fresh, hasLength(lines.length));
      expect(api.asked, hasLength(2), reason: 'recovery re-reads the user LIVE, whatever is kept');
      expect(fresh.first.url, lines.first.url, reason: 'the same signed address, freshly issued');
      expect(fresh.first.lease?.expiresAt, lines.first.lease?.expiresAt);
    });

    test('an unknown room is entered by recovery alone', () async {
      final api = _Api();
      final site = TiktokSite(http: TiktokHttp(api), now: () => _issuedAt);
      final recovery = site.capability<LivePlayRecovery>()!;

      final room = await site.detail(_user);
      final fresh = (await recovery.refetchLines(room: room)).getOrElse((_) => throw StateError('no fresh lines'));
      expect(fresh, isNotEmpty);
      expect(api.asked, hasLength(2));
    });
  });
}
