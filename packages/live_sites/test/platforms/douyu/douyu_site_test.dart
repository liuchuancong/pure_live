import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/douyu/api/douyu_http.dart';
import 'package:live_sites/src/platforms/douyu/capabilities/douyu_playback_provider.dart';
import 'package:live_sites/src/platforms/douyu/douyu_manifest.dart';
import 'package:live_sites/src/platforms/douyu/douyu_site.dart';
import 'package:test/test.dart';

/// The room the tests read (a numeric rid: no lookup asks).
const String _rid = '1024';

/// The instant the test's clock reads.
final DateTime _now = DateTime.utc(2026, 11, 6, 12);

/// The play answers' `expire`, about five minutes after [_now].
final int _expire = _now.add(const Duration(minutes: 5)).millisecondsSinceEpoch ~/ 1000;

/// The transport under the site: `getEncryption` answers one descriptor,
/// `getH5PlayV1` answers by what the form asked — the rate `-1` without a
/// CDN is the metadata (the first read advertises the `ws` CDN, later reads
/// `tct`), a named CDN is a line whose `rtmp_live` is a new address every
/// time. The asks are recorded; the metadata reads and the line answers
/// handed out are counted.
final class _Api implements LiveHttp {
  final asked = <Uri>[];
  int metadataReads = 0;
  int lineAnswers = 0;
  int _sigs = 0;

  /// The CDN the metadata answers advertise, by the read's number.
  String cdnOf(int read) => read == 1 ? 'ws' : 'tct';

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final url = request.url;
    asked.add(url);
    if (url.path == '/wgapi/livenc/liveweb/websec/getEncryption') return _json(_descriptor());
    if (url.path == '/lapi/live/getH5PlayV1/$_rid') {
      final fields = Uri(query: request.body ?? '').queryParameters;
      final rate = fields['rate'] ?? '';
      final cdn = fields['cdn'] ?? '';
      if (rate == '-1' && cdn.isEmpty) {
        metadataReads++;
        return _json({'error': 0, 'data': _metadata(cdnOf(metadataReads))});
      }
      lineAnswers++;
      return _json({'error': 0, 'data': _played(cdn)});
    }
    throw StateError('unexpected ask $url');
  }

  /// The play-request signing descriptor, good for the whole test.
  static Map<String, Object?> _descriptor() => {
    'error': 0,
    'data': {'key': 'k', 'rand_str': 'r', 'enc_data': 'e', 'enc_time': 1, 'expire_at': 4000000000, 'is_special': 0},
  };

  /// A metadata answer advertising [cdn], live with a pushed stream.
  Map<String, Object?> _metadata(String cdn) => {
    'streamStatus': 1,
    'rate': 0,
    'rtmp_cdn': cdn,
    'cdnsWithName': [
      {'cdn': cdn},
    ],
    'multirates': [
      {'rate': 0, 'name': '原画'},
    ],
  };

  /// A line answer on [cdn]: its absolute `rtmp_live` is new every ask.
  Map<String, Object?> _played(String cdn) => {
    'rate': 0,
    'rtmp_cdn': cdn,
    'rtmp_live': 'https://$cdn-send.example/live/$_rid.flv?expire=$_expire&sig=${++_sigs}',
  };

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}

/// The transport of a room whose stream stops pushing after the first line:
/// the metadata still names the room's CDN, but the signed play answers `-5`
/// (未开播) from the second ask on, a room state no retry fixes.
final class _StoppedApi extends _Api {
  int lineAsks = 0;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final url = request.url;
    asked.add(url);
    if (url.path == '/wgapi/livenc/liveweb/websec/getEncryption') return _json(_Api._descriptor());
    if (url.path == '/lapi/live/getH5PlayV1/$_rid') {
      final fields = Uri(query: request.body ?? '').queryParameters;
      final rate = fields['rate'] ?? '';
      final cdn = fields['cdn'] ?? '';
      if (rate == '-1' && cdn.isEmpty) {
        metadataReads++;
        return _json({'error': 0, 'data': _metadata('ws')});
      }
      lineAsks++;
      if (lineAsks == 1) {
        lineAnswers++;
        return _json({'error': 0, 'data': _played(cdn)});
      }
      return _json({'error': -5, 'msg': '房间未开播'});
    }
    throw StateError('unexpected ask $url');
  }
}

LiveResponse _json(Object body) => LiveResponse(
  statusCode: 200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
  bodyBytes: Uint8List.fromList(utf8.encode(jsonEncode(body))),
);

DouyuSite _site(_Api api) => DouyuSite(http: DouyuHttp(api), now: () => _now);

LiveRoom _room() => LiveRoom.normalized(platform: douyuSiteId, roomId: _rid);

void main() {
  group('recovery', () {
    test('the room table serves getLines; recovery reads the metadata and signs every CDN again', () async {
      final api = _Api();
      final site = _site(api);
      final playback = site.capability<LivePlaybackProvider>()! as DouyuPlaybackProvider;
      final room = _room();

      final held = (await playback.getLines(room: room)).getOrElse((error) => fail('$error'));
      expect(held, hasLength(1));
      expect(held.single.url, startsWith('https://ws-send.example/'));
      expect(held.single.lineLabel, 'ws');
      expect(api.metadataReads, 1, reason: 'the first getLines brings the room table with one metadata read');
      expect(api.lineAnswers, 1);

      final again = (await playback.getLines(room: room)).getOrElse((error) => fail('$error'));
      expect(again.single.url, startsWith('https://ws-send.example/'));
      expect(again.single.url, isNot(held.single.url), reason: 'every line is a play request sent now');
      expect(api.metadataReads, 1, reason: 'the room table serves the next getLines');
      expect(api.lineAnswers, 2);

      final recovery = site.capability<LivePlayRecovery>();
      expect(recovery, isNotNull);
      final fresh = (await recovery!.refetchLines(room: room)).getOrElse((error) => fail('$error'));
      expect(fresh, hasLength(1));
      expect(
        fresh.single.lineLabel,
        'tct',
        reason: 'the fresh metadata advertises another CDN, and recovery follows it',
      );
      expect(fresh.single.url, startsWith('https://tct-send.example/'));
      expect(api.metadataReads, 2, reason: 'recovery reads the play metadata again');
      expect(api.lineAnswers, 3, reason: 'recovery signs the fresh CDN with a play request sent now');
      expect(api.asked.where((url) => url.path.endsWith('getEncryption')), hasLength(1), reason: 'one descriptor');
    });

    test('a room that stopped pushing says so, and no line is handed back', () async {
      final api = _StoppedApi();
      final site = _site(api);
      final playback = site.capability<LivePlaybackProvider>()!;
      final room = _room();

      expect((await playback.getLines(room: room)).getOrElse((error) => fail('$error')), hasLength(1));

      final answer = await site.capability<LivePlayRecovery>()!.refetchLines(room: room);
      expect(answer.getLeft().toNullable(), isA<LiveSiteContentUnavailable>());
      expect(api.metadataReads, 2, reason: 'recovery asked the metadata again before giving up');
      expect(api.lineAnswers, 1, reason: 'the stopped room answers no line, and none is handed back');
    });
  });
}
