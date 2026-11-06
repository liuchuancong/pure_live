import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/weibo/api/weibo_endpoints.dart';
import 'package:live_sites/src/platforms/weibo/api/weibo_http.dart';
import 'package:live_sites/src/platforms/weibo/parsers/weibo_failure.dart';
import 'package:live_sites/src/platforms/weibo/parsers/weibo_room_parser.dart';
import 'package:live_sites/src/platforms/weibo/weibo_site.dart';
import 'package:live_sites/src/platforms/weibo/weibo_streams.dart';
import 'package:test/test.dart';

// The fakes reuse the platform's constructor-name style, and the FLV bytes
// need no type annotation to be read.
// ignore_for_file: unnecessary_type_name_in_constructor

const String _id = '1022:2321325347923495092258';
const String _canonical = 'https://plwb00.live.weibo.com/alicdn/5000000000000000_wb720avc.flv';

/// A minimal FLV answer: a header and one video tag whose sequence header
/// announces codec `code` (7 AVC, 12 HEVC).
List<int> _flv({int codec = 7}) {
  final payload = <int>[0x10 | codec, 0, 0, 0, 0, 1, 0x64, 0, 0x1f, 0xff, 0xe1, 0, 1, 0x67];
  return [
    70, 76, 86, 1, 5, 0, 0, 0, 9, // header: 'FLV', version, flags, offset 9
    0, 0, 0, 0, // PreviousTagSize0
    9, // tag type: video
    0, 0, payload.length, // data size
    0, 0, 0, 0, // timestamp + extension
    0, 0, 0, // stream id
    ...payload,
    0, 0, 0, payload.length + 11, // PreviousTagSize
  ];
}

/// A streamed answer of `chunks`, remembering whether its stream was closed.
final class _FakeStream implements LiveStreamedResponse {
  _FakeStream(this._status, List<List<int>> chunks) : _controller = StreamController<Uint8List>(), _chunks = chunks {
    _controller.onCancel = () {
      wasCancelled = true;
    };
  }

  final int _status;
  final StreamController<Uint8List> _controller;
  final List<List<int>> _chunks;
  bool wasCancelled = false;
  bool delivered = false;

  void deliver() {
    if (delivered) return;
    delivered = true;
    for (final chunk in _chunks) {
      _controller.add(Uint8List.fromList(chunk));
    }
  }

  @override
  int get statusCode => _status;

  @override
  Map<String, String> get headers => const {};

  @override
  Stream<Uint8List> get stream => _controller.stream;

  @override
  Future<void> close() async {
    wasCancelled = true;
    if (!_controller.isClosed) await _controller.close();
  }
}

/// A transport whose API answers are scripted and whose CDN opens are too.
final class _FakeHttp implements LiveHttp {
  _FakeHttp({this.onOpen});

  /// The streamed answer of every `open`, or null for none scripted.
  _FakeStream? Function(LiveRequest request)? onOpen;

  /// The detail body `send` answers with, rewritten per test.
  String detailBody = _liveDetail();

  final List<LiveRequest> opened = [];
  int details = 0;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    if (request.url.path == WeiboEndpoints.detailPath) {
      details++;
      return LiveResponse(statusCode: 200, headers: const {}, bodyBytes: _body(detailBody));
    }
    return LiveResponse(statusCode: 404, headers: const {}, bodyBytes: _body('nope'));
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async {
    opened.add(request);
    return onOpen?.call(request) ?? (throw StateError('no scripted open'));
  }

  @override
  void close() {}

  static Uint8List _body(String text) => Uint8List.fromList(utf8.encode(text));
}

/// The detail of one live broadcast whose FLV is the canonical public address.
String _liveDetail({int status = 1, int watchLimit = 0, String? flv = _canonical}) => jsonEncode({
  'code': 100000,
  'error_code': 0,
  'data': {
    'liveId': _id,
    'status': status,
    'watch_limit': watchLimit,
    'play_switch': 1,
    'title': '晚间弹唱',
    'startTime': 1790733600000,
    'live_origin_flv_url': ?flv,
    'user': {'uid': 9001, 'screenName': '主播甲'},
  },
});

/// The codec each profile address answers with.
int _codecByteOf(String path) {
  if (path.endsWith('/5000000000000000.flv')) return 12; // the source answers HEVC
  return 7; // the transcodes answer AVC
}

_FakeStream _flvStream(LiveRequest request) {
  final stream = _FakeStream(200, [_flv(codec: _codecByteOf(request.url.path))]);
  scheduleMicrotask(stream.deliver);
  return stream;
}

void main() {
  group('candidates', () {
    test('the canonical address offers source, 1080 and 480 on its own host', () {
      final candidates = WeiboStreams.candidates([_canonical, '$_canonical?again']);
      expect(candidates.map((candidate) => candidate.id), [
        'weibo-source',
        'weibo-1080-avc',
        'weibo-480-avc',
      ]);
      expect(candidates.map((candidate) => candidate.url.path), [
        '/alicdn/5000000000000000.flv',
        '/alicdn/5000000000000000_wb1080avc.flv',
        '/alicdn/5000000000000000_wb480avc.flv',
      ]);
      expect(candidates.map((candidate) => candidate.avcOnly), [false, true, true]);
      expect(WeiboStreams.knows('weibo-1080-avc'), isTrue);
      expect(WeiboStreams.knows('original'), isFalse);
    });

    test('a signed, plain-http, foreign or non-FLV address offers nothing', () {
      for (final bad in [
        '$_canonical?signature=x',
        '$_canonical#x',
        _canonical.replaceFirst('https:', 'http:'),
        _canonical.replaceFirst('plwb00.live.weibo.com', 'plwb00.live.weibo.com.evil.test'),
        _canonical.replaceFirst('https://', 'https://viewer@'),
        _canonical.replaceFirst('/alicdn/', '/other/'),
        _canonical.replaceFirst('.flv', '.m3u8'),
        'https://kitty.live.weibo.net/alicdn/1022_2321_wb720avc.flv?t=1',
      ]) {
        expect(WeiboStreams.candidates([bad]), isEmpty, reason: bad);
      }
    });
  });

  group('codecFromFlv', () {
    test('a complete bounded sequence header announces its codec', () {
      expect(WeiboStreams.codecFromFlv(_flv()), LiveStreamCodec.avc);
      expect(WeiboStreams.codecFromFlv(_flv(codec: 12)), LiveStreamCodec.hevc);
      expect(WeiboStreams.codecFromFlv(_flv(codec: 2)), isNull);
      expect(WeiboStreams.codecFromFlv(List.filled(100, 0)), isNull);
    });

    test('a prefix that stops inside the tag announces nothing yet', () {
      final whole = _flv();
      for (var end = 0; end < whole.length - 4; end++) {
        expect(WeiboStreams.codecFromFlv(whole.take(end).toList()), isNull, reason: '$end');
      }
    });

    test('an offset over the prefix bound is refused', () {
      final huge = _flv()..setRange(14, 17, [255, 255, 255]);
      expect(WeiboStreams.codecFromFlv(huge), isNull);
    });
  });

  group('probe', () {
    test('a fragmented answer names its codec and closes only its own stream', () async {
      final bytes = _flv();
      final stream = _FakeStream(200, [bytes.sublist(0, 8), bytes.sublist(8)]);
      final http = _FakeHttp(
        onOpen: (request) {
          scheduleMicrotask(stream.deliver);
          return stream;
        },
      );
      final parent = CancelToken();
      expect(await WeiboStreams.probe(http, Uri.parse(_canonical), cancel: parent), LiveStreamCodec.avc);
      expect(stream.wasCancelled, isTrue);
      expect(http.opened.single.cancelToken.isCancelled, isTrue);
      expect(identical(http.opened.single.cancelToken, parent), isFalse);
      expect(parent.isCancelled, isFalse);
    });

    test('the probe asks for a bounded prefix with its own agent', () async {
      final http = _FakeHttp(onOpen: _flvStream);
      await WeiboStreams.probe(http, Uri.parse(_canonical));
      final request = http.opened.single;
      expect(request.headers['range'], 'bytes=0-65535');
      expect(request.headers['user-agent'], 'Mozilla/5.0');
      expect(request.timeout, WeiboStreams.probeTimeout);
    });

    test('a non-200 answer is a missing profile, its stream closed', () async {
      final stream = _FakeStream(404, const []);
      final http = _FakeHttp(onOpen: (_) => stream);
      expect(await WeiboStreams.probe(http, Uri.parse(_canonical)), isNull);
      expect(stream.wasCancelled, isTrue);
    });

    test('bytes that are no FLV answer are a missing profile', () async {
      final stream = _FakeStream(200, [utf8.encode('<html>no media</html>')]);
      final http = _FakeHttp(
        onOpen: (request) {
          scheduleMicrotask(stream.deliver);
          return stream;
        },
      );
      expect(await WeiboStreams.probe(http, Uri.parse(_canonical)), isNull);
    });
  });

  group('discovery over the site', () {
    test('a canonical live broadcast offers the probed profiles beside 超清', () async {
      final http = _FakeHttp(onOpen: _flvStream);
      final site = WeiboSite(http: WeiboHttp(http));
      final room = await site.detail(_id);
      final qualities = await site.discoveredQualities(room.roomId);
      expect(qualities.map((quality) => quality.qualityId), [
        'weibo-source',
        'weibo-1080-avc',
        'original',
        'weibo-480-avc',
      ]);
      expect(qualities.map((quality) => quality.codec), [
        LiveStreamCodec.hevc,
        LiveStreamCodec.avc,
        LiveStreamCodec.avc,
        LiveStreamCodec.avc,
      ]);
    });

    test('a profile nothing serves leaves the API answer as 超清', () async {
      final http = _FakeHttp(
        onOpen: (request) {
          final stream = _FakeStream(404, const []);
          scheduleMicrotask(stream.close);
          return stream;
        },
      );
      final site = WeiboSite(http: WeiboHttp(http));
      await site.detail(_id);
      final qualities = await site.discoveredQualities(_id);
      // The API's own 720 AVC address stays offered; only the derived
      // profiles fell away.
      expect(qualities.map((quality) => quality.qualityId), ['original']);
      expect(qualities.single.label, '超清');
      expect(qualities.single.codec, LiveStreamCodec.avc);
    });

    test('a replay is not probed', () async {
      final http = _FakeHttp();
      final site = WeiboSite(http: WeiboHttp(http));
      final parsed = WeiboRoomParser.detail(
        _liveDetail(status: 3).replaceFirst('"startTime":1790733600000,', '"startTime":1790733600000,"replay_origin_url":"http://playback.weibo.com/r/index.m3u8",'),
        liveId: _id,
      );
      final qualities = await site.discoveredQualities(
        parsed.roomId,
        data: parsed.runtime.streamHandle! as WeiboRoomData,
      );
      expect(qualities.map((quality) => quality.qualityId), ['replay']);
      expect(http.opened, isEmpty);
    });

    test('a probed profile is rebuilt from the fresh answer and probed again', () async {
      final http = _FakeHttp(onOpen: _flvStream);
      final site = WeiboSite(http: WeiboHttp(http));
      final room = await site.detail(_id);
      final lines = await site.linesOf(room.roomId, quality: LivePlayQuality.of(label: '蓝光', qualityId: 'weibo-1080-avc'));
      expect(lines.single.url, endsWith('_wb1080avc.flv'));
      expect(lines.single.codec, LiveStreamCodec.avc);
      expect(lines.single.format, LiveStreamFormat.flv);
      expect(lines.single.lineLabel, 'alicdn');
      // The line request read the detail again (entry + line call).
      expect(http.details, greaterThanOrEqualTo(2));
    });

    test('a restricted broadcast refuses a profile before any probe', () async {
      final http = _FakeHttp()..detailBody = _liveDetail(watchLimit: 10);
      final site = WeiboSite(http: WeiboHttp(http));
      await expectLater(
        site.linesOf(_id, quality: LivePlayQuality.of(label: '蓝光', qualityId: 'weibo-1080-avc')),
        throwsA(isA<WeiboFailure>().having((failure) => failure.kind, 'kind', WeiboFailureKind.streamUnavailable)),
      );
      expect(http.opened, isEmpty);
    });

    test('a profile the broadcast does not offer is refused', () async {
      final http = _FakeHttp(
        onOpen: (request) {
          // The 1080 profile is refused; the others answer.
          if (request.url.path.endsWith('_wb1080avc.flv')) {
            final stream = _FakeStream(404, const []);
            scheduleMicrotask(stream.close);
            return stream;
          }
          return _flvStream(request);
        },
      );
      final site = WeiboSite(http: WeiboHttp(http));
      await expectLater(
        site.linesOf(_id, quality: LivePlayQuality.of(label: '蓝光', qualityId: 'weibo-1080-avc')),
        throwsA(isA<WeiboFailure>().having((failure) => failure.kind, 'kind', WeiboFailureKind.streamUnavailable)),
      );
    });
  });
}
