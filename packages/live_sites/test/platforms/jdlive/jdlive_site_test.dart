import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_status_check.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/jdlive/api/jdlive_http.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_site.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

const String _liveId = '48378944';
const String _cdn = 'https://zt-pull-ai.jdcloud.com/live';

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

/// `getImmediatePlayToM` of the broadcast in [status], its streams named
/// [key] (the website's shape, S02-play-live).
String _play({int status = 1, int secret = 0, String key = 'ABC_fhd'}) => jsonEncode({
  'code': '0',
  'subCode': '0',
  'data': {
    'liveId': int.parse(_liveId),
    'status': status,
    'secret': secret,
    'h5VideoUrl': '$_cdn/$key.m3u8',
    'videoUrl': '$_cdn/$key.flv',
  },
});

/// The playlist of the stream [key].
String _playlist(String key) => '#EXTM3U\n#EXTINF:2.000,\n$key-ss-1.ts\n';

/// The site's answers: a playlist for an `.m3u8` address (named after its
/// stream), the play answer [play] gives for anything else.
String Function(Uri url) _site(String Function() play) => (url) {
  if (url.path.endsWith('.m3u8')) return _playlist(url.pathSegments.last.replaceFirst('.m3u8', ''));
  return play();
};

LiveRoom _card() => LiveRoom.normalized(platform: 'jdlive', roomId: _liveId);

void main() {
  group('the one-bit status', () {
    Future<Object?> statusOf(String answer) async {
      final site = JdliveSite(http: JdliveHttp(_Http((_) => answer)));
      final read = await site.capability<LiveStatusCheck>()!.getLiveStatus(room: _card());
      return read.fold<Object?>((error) => error, (live) => live);
    }

    test('live, app-only live, announced and ended are answers', () async {
      expect(await statusOf(_play()), isTrue);
      expect(await statusOf(_play(secret: 1)), isTrue, reason: 'app-only is live; its restriction says why');
      expect(await statusOf(_play(status: 0)), isFalse);
      expect(await statusOf(_play(status: 2)), isFalse);
      expect(await statusOf(_play(status: 3)), isFalse);
    });

    test('paused and an unknown status are no answer, never an invented offline', () async {
      expect(await statusOf(_play(status: 10)), isA<LiveSiteContentUnavailable>());
      expect(await statusOf(_play(status: 11)), isA<LiveSiteContentUnavailable>());
      expect(await statusOf(_play(status: 99)), isA<LiveSiteParseError>());
    });
  });

  group('recovery', () {
    test('the kept play answer serves the lines; recovery asks it and the playlist again', () async {
      var key = 'ABC_fhd';
      final http = _Http(_site(() => _play(key: key)));
      final site = JdliveSite(http: JdliveHttp(http));
      final room = await site.detail(_liveId);
      expect(http.asked, hasLength(2), reason: 'the play answer, then the playlist check');

      final playback = site.capability<LivePlaybackProvider>()!;
      final held = (await playback.getLines(room: room)).getOrElse((error) => fail('$error'));
      expect(held.single.url, '$_cdn/ABC_fhd.m3u8');
      expect(http.asked, hasLength(2), reason: 'the kept answer needs no request');

      key = 'XYZ_fhd';
      final recovery = site.capability<LivePlayRecovery>();
      expect(recovery, isNotNull);
      final fresh = (await recovery!.refetchLines(room: room)).getOrElse((error) => fail('$error'));
      expect(fresh.single.url, '$_cdn/XYZ_fhd.m3u8');
      expect(http.asked, hasLength(4));
    });

    test('a broadcast that ended meanwhile says so instead of replaying its address', () async {
      var status = 1;
      final http = _Http(_site(() => _play(status: status)));
      final site = JdliveSite(http: JdliveHttp(http));
      final room = await site.detail(_liveId);
      status = 2;
      final answer = await site.capability<LivePlayRecovery>()!.refetchLines(room: room);
      expect(answer.getLeft().toNullable(), isA<LiveSiteContentUnavailable>());
      expect(http.asked, hasLength(3), reason: 'an ended broadcast has no playlist to check');
    });
  });
}
