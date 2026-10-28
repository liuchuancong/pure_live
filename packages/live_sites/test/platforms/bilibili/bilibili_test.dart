import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_endpoints.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_play_parser.dart';
import 'package:test/test.dart';

/// The issue time the tests read a response at (late 2026).
final DateTime _issued = DateTime.fromMillisecondsSinceEpoch(1790733600000, isUtc: true);

/// The `expires` an hour after [_issued] (Unix seconds).
int get _expires => _issued.millisecondsSinceEpoch ~/ 1000 + 3600;

/// One `codec` entry of a `getRoomPlayInfo` answer.
Map<String, dynamic> _codec({
  required String protocol,
  required String format,
  required String codec,
  required int qn,
  required List<String> hosts,
  required String base,
  List<int> accept = const [],
  String extra = '',
}) => {
  'protocol_name': protocol,
  'format': [
    {
      'format_name': format,
      'codec': [
        {
          'codec_name': codec,
          'current_qn': qn,
          'accept_qn': accept,
          'base_url': base,
          'url_info': [
            for (final host in hosts) {'host': host, 'extra': extra},
          ],
        },
      ],
    },
  ],
};

/// A `getRoomPlayInfo` `data` with [streams] and [names] (`qn` → name).
Map<String, dynamic> _data(List<Map<String, dynamic>> streams, {Map<int, String> names = const {}}) => {
  'playurl_info': {
    'playurl': {
      'g_qn_desc': [
        for (final MapEntry(key: qn, value: name) in names.entries) {'qn': qn, 'desc': name},
      ],
      'stream': streams,
    },
  },
};

void main() {
  group('play lines', () {
    test('lines order by protocol, format, codec and CDN; one codec is kept and URLs never repeat', () {
      final data = _data([
        _codec(
          protocol: 'http_hls',
          format: 'ts',
          codec: 'avc',
          qn: 250,
          hosts: ['https://a.example.com'],
          base: '/live.m3u8',
        ),
        _codec(
          protocol: 'http_stream',
          format: 'flv',
          codec: 'avc',
          qn: 250,
          hosts: ['https://b.example.com'],
          base: '/live.flv',
          extra: '?expires=$_expires',
          accept: [250, 400],
        ),
        _codec(
          protocol: 'http_stream',
          format: 'flv',
          codec: 'avc',
          qn: 250,
          hosts: ['https://mcdn.example.com'],
          base: '/m.flv',
        ),
        _codec(
          protocol: 'http_stream',
          format: 'flv',
          codec: 'hevc',
          qn: 250,
          hosts: ['https://d.example.com'],
          base: '/d.flv',
        ),
        // The same URL as the first line: it must survive once.
        _codec(
          protocol: 'http_stream',
          format: 'flv',
          codec: 'avc',
          qn: 250,
          hosts: ['https://b.example.com'],
          base: '/live.flv',
          extra: '?expires=$_expires',
        ),
      ]);
      final resolution = BilibiliPlayParser.resolvedLines(
        data,
        requestedQn: 250,
        roomId: '42062',
        issuedAt: _issued,
        cookie: 'buvid3=x;',
      );
      final lines = resolution.lines;
      expect(resolution.appliedQn, 250);
      expect(
        [for (final line in lines) Uri.parse(line.url).host],
        ['b.example.com', 'mcdn.example.com', 'a.example.com'],
      );
      expect(
        [for (final line in lines) line.format],
        [LiveStreamFormat.flv, LiveStreamFormat.flv, LiveStreamFormat.hls],
      );
      expect({for (final line in lines) line.codec}, {LiveStreamCodec.avc});
      expect(lines.first.headers.toMap(), BilibiliEndpoints.mediaHeaders('42062', cookie: 'buvid3=x;'));
      expect(lines.first.lease?.expiresAt, DateTime.fromMillisecondsSinceEpoch(_expires * 1000, isUtc: true));
      expect(lines.first.lease?.refreshAt, DateTime.fromMillisecondsSinceEpoch((_expires - 60) * 1000, isUtc: true));
      expect(lines.last.lease, isNull, reason: 'no expires, no lease');
    });

    test("the qualities are the codecs' own qn, best first, named from g_qn_desc", () {
      final data = _data(
        [
          _codec(
            protocol: 'http_stream',
            format: 'flv',
            codec: 'avc',
            qn: 250,
            hosts: ['https://b.example.com'],
            base: '/live.flv',
            accept: [250, 400],
          ),
        ],
        names: {250: '超清', 400: '蓝光'},
      );
      expect([for (final quality in BilibiliPlayParser.qualities(data)) quality.qualityId], ['400', '250']);
      expect([for (final quality in BilibiliPlayParser.qualities(data)) quality.label], ['蓝光', '超清']);
    });

    test('a guest asking for the source is served what the answer says it served', () {
      final data = _data(
        [
          _codec(
            protocol: 'http_stream',
            format: 'flv',
            codec: 'avc',
            qn: 250,
            hosts: ['https://b.example.com'],
            base: '/live.flv',
            accept: [250, 10000],
          ),
        ],
        names: {250: '超清', 10000: '原画'},
      );
      final resolution = BilibiliPlayParser.resolvedLines(data, requestedQn: 10000, roomId: '1', issuedAt: _issued);
      expect(resolution.appliedQn, 250, reason: 'the platform downgraded the guest (REG-BILIBILI-001)');
      expect(BilibiliPlayParser.qualityOf(data, 250).label, '超清');
    });

    test('no codec the model knows leaves no line, and a missing playurl is api-changed', () {
      final data = _data([
        _codec(
          protocol: 'http_stream',
          format: 'mp4',
          codec: 'avc',
          qn: 250,
          hosts: ['https://b.example.com'],
          base: '/live.mp4',
        ),
      ]);
      final resolution = BilibiliPlayParser.resolvedLines(data, requestedQn: 250, roomId: '1', issuedAt: _issued);
      expect(resolution.lines, isEmpty);
      expect(resolution.appliedQn, isNull);
      expect(
        () => BilibiliPlayParser.resolvedLines(const {}, requestedQn: 250, roomId: '1', issuedAt: _issued),
        throwsA(isA<BilibiliFailure>()),
      );
    });
  });
}
