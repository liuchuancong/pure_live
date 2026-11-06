import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/capabilities/live_status_check.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/liveme/api/liveme_http.dart';
import 'package:live_sites/src/platforms/liveme/liveme_site.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

// The ids of the S03/S04/S05 samples (a live anchor, 2026-09-27).
const String _shortId = '209683072';
const String _userId = '932385543319330816';
const String _videoId = '17904580585651396476';
const String _nextVideoId = '17904580585651399999';

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

/// The source FLV of broadcast [videoId], as the CDN names it.
String _flv(String videoId) =>
    'https://game.live11.linkv.fun/yolo/$videoId.flv?wsSecret=a01f1912f57a1e829cc30b93fe7a2f48&wsABStime=6ab98a4a';

/// The site's answers, in the samples' shapes: `uid_vid_by_short_id` names
/// the broadcast [videoId] gives (none when empty), and `queryinfosimple`
/// describes it, live unless [stated] is false (no `online`, `status` or
/// `roomstate`: a state the answer does not give).
String Function(Uri url) _site(String Function() videoId, {bool stated = true}) => (url) {
  final vid = videoId();
  return jsonEncode({
    'status': '200',
    'msg': '',
    'data': switch (url.path) {
      '/liveme_ent/v1/user/uid_vid_by_short_id' => {'uid': _userId, 'vid': vid},
      '/user/getinfo' => {
        'user': {
          'user_info': {'cm_openid': _userId, 'short_id': _shortId, 'uname': 'LIVEME-NIGHTCLUB', 'usign': ''},
          'count_info': {'follower_count': '120'},
        },
      },
      '/live/queryinfosimple' => {
        'video_info': {
          'vid': vid,
          'userid': _userId,
          'ushortid': _shortId,
          'uname': 'LIVEME-NIGHTCLUB',
          'title': '.',
          if (stated) ...{'online': '1', 'status': '0', 'roomstate': '0'},
          'playnumber': '201',
          'videosource': _flv(vid).replaceFirst('https:', 'http:'),
        },
      },
      _ => throw StateError('unexpected request $url'),
    },
  });
};

LiveRoom _card() => LiveRoom.normalized(platform: 'liveme', roomId: _shortId);

void main() {
  group('the one-bit status', () {
    Future<Object?> statusOf(_Http http) async {
      final site = LivemeSite(http: LivemeHttp(http));
      final read = await site.capability<LiveStatusCheck>()!.getLiveStatus(room: _card());
      return read.fold<Object?>((error) => error, (live) => live);
    }

    test('a broadcasting anchor is live, one without a broadcast is not', () async {
      expect(await statusOf(_Http(_site(() => _videoId))), isTrue);
      expect(await statusOf(_Http(_site(() => ''))), isFalse);
    });

    test('a broadcast answer that gives no state is no answer, never an invented offline', () async {
      final http = _Http(_site(() => _videoId, stated: false));
      final refreshed = await LivemeSite(
        http: LivemeHttp(http),
      ).capability<LiveRoomRefresh>()!.getRoomForRefresh(roomId: _shortId);
      expect(
        refreshed.getOrElse((error) => fail('$error')).broadcast.liveStatus,
        LiveStatus.unknown,
        reason: 'the room reads; only its state is not given',
      );
      expect(await statusOf(_Http(_site(() => _videoId, stated: false))), isA<LiveSiteParseError>());
    });
  });

  group('recovery', () {
    test('the kept stream data serves the lines; recovery asks for the current broadcast', () async {
      var videoId = _videoId;
      final http = _Http(_site(() => videoId));
      final site = LivemeSite(http: LivemeHttp(http));
      final room = await site.detail(_shortId);
      expect(http.asked, hasLength(3), reason: 'the mapping, then the profile and the broadcast');

      final playback = site.capability<LivePlaybackProvider>()!;
      final held = (await playback.getLines(room: room)).getOrElse((error) => fail('$error'));
      expect(held.first.url, _flv(_videoId));
      expect(http.asked, hasLength(3), reason: 'the kept data needs no request');

      videoId = _nextVideoId;
      final recovery = site.capability<LivePlayRecovery>();
      expect(recovery, isNotNull);
      final fresh = (await recovery!.refetchLines(room: room)).getOrElse((error) => fail('$error'));
      expect(fresh.first.url, _flv(_nextVideoId));
      expect(http.asked.skip(3).map((url) => url.path), [
        '/liveme_ent/v1/user/uid_vid_by_short_id',
        '/live/queryinfosimple',
      ], reason: 'the profile adds nothing to a stream');

      final after = (await playback.getLines(room: room)).getOrElse((error) => fail('$error'));
      expect(after.first.url, _flv(_nextVideoId), reason: "recovery's broadcast is the one kept");
      expect(http.asked, hasLength(5));
    });

    test('a broadcast that ended meanwhile says so, and its lines are not handed back', () async {
      var videoId = _videoId;
      final http = _Http(_site(() => videoId));
      final site = LivemeSite(http: LivemeHttp(http));
      final room = await site.detail(_shortId);

      videoId = '';
      final answer = await site.capability<LivePlayRecovery>()!.refetchLines(room: room);
      expect(answer.getLeft().toNullable(), isA<LiveSiteContentUnavailable>());
      expect(http.asked, hasLength(4), reason: 'no broadcast to ask about after the mapping');

      final again = await site.capability<LivePlaybackProvider>()!.getLines(room: room);
      expect(again.getLeft().toNullable(), isA<LiveSiteContentUnavailable>());
      expect(http.asked, hasLength(5), reason: 'the dead data is forgotten, so the mapping is asked again');
    });
  });
}
