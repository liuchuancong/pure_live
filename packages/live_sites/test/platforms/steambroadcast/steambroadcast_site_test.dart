import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/steambroadcast/api/steambroadcast_http.dart';
import 'package:live_sites/src/platforms/steambroadcast/capabilities/steambroadcast_playback_provider.dart';
import 'package:live_sites/src/platforms/steambroadcast/steambroadcast_site.dart';
import 'package:test/test.dart';

/// The Steam id of the broadcaster the tests read.
const String _id = '76561198000000000';

/// The CDN host of the broadcast's manifests.
const String _host = 'p7d9.steamcontent.com';

/// An `hls_url` that passes every address rule of `getbroadcastmpd`.
Uri _masterUrl() =>
    Uri.parse('https://$_host/broadcast/$_id/12345/hls_manifest/0/$_host/master.m3u8?broadcast_origin=xyz.steamserver.net');

/// A child (variant) of the master on [_host].
String _child(String file) =>
    'https://$_host/broadcast/$_id/12345/hls_manifest/0/$_host/$file?broadcast_origin=xyz.steamserver.net';

/// One `#EXT-X-STREAM-INF` and its address.
String _variant({required String resolution, required int bandwidth, required String file, String? frameRate}) =>
    '#EXT-X-STREAM-INF:BANDWIDTH=$bandwidth,RESOLUTION=$resolution'
    '${frameRate == null ? '' : ',FRAME-RATE=$frameRate'}'
    ',CODECS="avc1.640028,mp4a.40.2"\n${_child(file)}';

/// A master of two variants: `1080p60` best, then `720p`.
String _twoVariants() => [
  '#EXTM3U',
  _variant(resolution: '1920x1080', bandwidth: 4800000, file: 'a.m3u8', frameRate: '60'),
  _variant(resolution: '1280x720', bandwidth: 1600000, file: 'b.m3u8'),
].join('\n');

/// A master whose one variant offers no choice: the adaptive quality alone.
String _oneVariant() => [
  '#EXTM3U',
  _variant(resolution: '1920x1080', bandwidth: 4800000, file: 'a.m3u8', frameRate: '60'),
].join('\n');

/// A `getbroadcastmpd` answer, live with the master of [_masterUrl()].
String _mpd() => jsonEncode({
  'success': 'ready',
  'title': '直播标题',
  'num_viewers': 812,
  'broadcastid': '98765',
  'hls_url': '${_masterUrl()}',
});

/// A [LiveResponse] of [body].
LiveResponse _answer(String body, {int status = 200}) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: Uint8List.fromList(utf8.encode(body)));

/// The transport of a room entry: the mini profile, `getbroadcastmpd`,
/// `getbroadcastinfo` (refused with 404, its loss the room's) and the HLS
/// master, whose body is the next of [masters] (the last repeats). The asks
/// are recorded in order.
final class _Api implements LiveHttp {
  /// The body of each HLS master read, in order; the last repeats.
  List<String> masters = [];

  /// Every requested address, in order.
  final List<Uri> asked = [];

  int _masterReads = 0;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final url = request.url;
    asked.add(url);
    if (url.host == _host) {
      final body = _masterReads < masters.length ? masters[_masterReads] : masters.last;
      _masterReads++;
      return _answer(body);
    }
    if (url.path.startsWith('/miniprofile/')) return _answer('{"persona_name":"主播"}');
    if (url.path == '/broadcast/getbroadcastmpd/') return _answer(_mpd());
    if (url.path == '/broadcast/getbroadcastinfo/') return _answer('{}', status: 404);
    throw StateError('unexpected ask $url');
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}

void main() {
  group('recovery', () {
    test('the kept entry serves the lines; recovery reads mpd and the master again', () async {
      final api = _Api()..masters = [_twoVariants()];
      final site = SteambroadcastSite(http: SteambroadcastHttp(api));
      final playback = site.capability<LivePlaybackProvider>()! as SteambroadcastPlaybackProvider;

      final room = await site.detail(_id);
      expect(api.asked, hasLength(4), reason: 'the mini profile, getbroadcastmpd, getbroadcastinfo and the master');
      final lines = (await playback.getLines(room: room)).getOrElse((_) => throw StateError('no lines'));
      expect(lines, hasLength(1));
      expect(lines.single.url, '${_masterUrl()}');
      expect(api.asked, hasLength(4), reason: 'the checked answer the room entry brought serves the lines');

      final recovery = site.capability<LivePlayRecovery>();
      expect(recovery, isNotNull);
      final fresh = (await recovery!.refetchLines(room: room)).getOrElse((_) => throw StateError('no fresh lines'));
      expect(fresh, hasLength(1));
      expect(fresh.single.url, '${_masterUrl()}');
      expect(api.asked, hasLength(6), reason: 'recovery re-reads getbroadcastmpd and the master, never the kept answer');
      expect(api.asked[4].path, '/broadcast/getbroadcastmpd/', reason: 'recovery asks no mini profile');
      expect(api.asked[5].host, _host, reason: 'recovery checks the fresh master');
    });

    test('a variant gone from the fresh master plays the adaptive quality', () async {
      final api = _Api()..masters = [_twoVariants(), _oneVariant()];
      final site = SteambroadcastSite(http: SteambroadcastHttp(api));

      final room = await site.detail(_id);
      final qualities = await site.qualitiesOf(room.roomId);
      expect(qualities.map((quality) => quality.qualityId), ['auto', '1080p60', '720p']);
      expect(api.asked, hasLength(4), reason: 'the qualities read the kept checked answer');

      final recovery = site.capability<LivePlayRecovery>()!;
      final fresh = (await recovery.refetchLines(room: room, quality: qualities[1])).getOrElse(
        (_) => throw StateError('no fresh lines'),
      );
      expect(fresh, hasLength(1));
      expect(fresh.single.url, '${_masterUrl()}');
      expect(fresh.single.lineLabel, isNull, reason: 'the fresh master has the variant no more: the adaptive line');
      expect(api.asked, hasLength(6));
    });
  });
}
