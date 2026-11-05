import 'dart:convert';

import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/platforms/acfun/api/acfun_endpoints.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_failure.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_play_parser.dart';
import 'package:test/test.dart';

/// One representation of a `startPlay` answer.
Map<String, Object?> _representation({
  String url = 'https://a.kouji.5695cdn.com/1.m3u8?auth_key=2',
  String? name,
  String? qualityType,
  Object? id,
  Object? level,
  Object? bitrate,
  bool? hidden,
}) => {
  'url': url,
  'name': ?name,
  'qualityType': ?qualityType,
  'id': ?id,
  'level': ?level,
  'bitrate': ?bitrate,
  'hidden': ?hidden,
};

/// A `videoPlayRes` with one manifest holding [representations].
Map<String, Object?> _res(List<Map<String, Object?>> representations, {int manifests = 1}) => {
  'liveAdaptiveManifest': [
    for (var index = 0; index < manifests; index++)
      {
        'adaptationSet': {'representation': representations},
      },
  ],
};

List<AcfunQuality> _qualities(Object? videoPlayRes) => AcfunPlayParser.qualities(videoPlayRes);

/// What `startPlay` makes of [videoPlayRes]: the kind it refuses with, or null
/// when it found lines to give.
Object? _kindOf(Object? videoPlayRes) {
  try {
    _qualities(videoPlayRes);
    return null;
  } on AcfunFailure catch (failure) {
    return failure.kind;
  }
}

/// A signed URL whose `auth_key` ends at [expiresAt].
String _signed(DateTime expiresAt, {String host = 'a.kouji.5695cdn.com', String path = '1.m3u8'}) =>
    'https://$host/live.flv/$path?did=1&auth_key=${expiresAt.millisecondsSinceEpoch ~/ 1000}-0-0-abc';

void main() {
  group('the order of a representation', () {
    test('a level and a bitrate are different scales, and the level wins', () {
      expect(AcfunPlayParser.qualityRank(level: 130), 1000130);
      expect(
        AcfunPlayParser.qualityRank(level: 130),
        greaterThan(AcfunPlayParser.qualityRank(bitrate: 8000000)),
        reason: 'the level-130 source beats an 8000 kbps line with no level',
      );
      expect(AcfunPlayParser.qualityRank(bitrate: 8000000), 999999, reason: 'a bitrate is capped, not scaled');
      expect(AcfunPlayParser.qualityRank(level: 0), 1000000, reason: 'level zero is still a level');
      expect(AcfunPlayParser.qualityRank(level: -1, bitrate: 500), 500, reason: 'a negative level says nothing');
      expect(AcfunPlayParser.qualityRank(), 0);
      expect(AcfunPlayParser.qualityRank(bitrate: -9), 0);
    });

    test("the model keeps the answer's order with the best first", () {
      final qualities = _qualities(
        _res([
          _representation(qualityType: 'SUPER', level: 100),
          _representation(qualityType: 'HIGH', level: 40),
          _representation(qualityType: 'STANDARD', level: 10),
        ]),
      );
      expect(qualities.map((quality) => quality.id), ['SUPER', 'HIGH', 'STANDARD']);
      final model = AcfunPlayParser.toModel(qualities);
      expect(model.map((quality) => quality.platformOrder), [3, 2, 1]);
      expect(model.map((quality) => quality.qualityId), ['SUPER', 'HIGH', 'STANDARD']);
      expect(model.map((quality) => quality.label), ['蓝光', '超清', '高清']);
      expect(AcfunPlayParser.toModel(const <AcfunQuality>[]), isEmpty);
    });
  });

  group('the quality table of startPlay', () {
    test('a JSON string answer is read like the object it holds', () {
      final res = _res([_representation(qualityType: 'SUPER', level: 100, name: '蓝光 8M')]);
      final fromObject = _qualities(res);
      final fromText = _qualities(jsonEncode(res));
      expect(
        fromText.map((quality) => (quality.id, quality.label, quality.rank)).toList(),
        fromObject.map((quality) => (quality.id, quality.label, quality.rank)).toList(),
        reason: 'the answer arrives as text and as an object alike',
      );
      expect(fromText.single.urls, fromObject.single.urls);
      expect(fromObject.single.label, '蓝光 8M', reason: 'the representation names itself');
      expect(() => _qualities('not json'), throwsA(isA<AcfunFailure>()));
    });

    test("the id is the quality type, else the answer's own id, else nothing", () {
      final qualities = _qualities(
        _res([
          _representation(qualityType: 'HIGH', id: 3),
          _representation(id: 7),
          _representation(id: '8'),
          _representation(),
        ]),
      );
      expect(qualities.map((quality) => quality.id), ['HIGH', 'id:7', 'id:8']);
      expect(qualities.first.label, '超清', reason: 'a type with no name is called by the platform');
      expect(qualities[1].label, '画质 id:7', reason: 'a typeless quality is named by its id');
      expect(qualities[2].label, '画质 id:8', reason: 'an id written as text is still an id');
    });

    test('one quality per id: the first label, the highest rank and every url once', () {
      final qualities = _qualities(
        _res([
          _representation(url: 'https://a.cdn/1.m3u8', qualityType: 'SUPER', name: '蓝光 8M', level: 100),
          _representation(url: 'https://b.cdn/1.m3u8', qualityType: 'SUPER', name: '别的名字', level: 40),
          _representation(url: 'https://a.cdn/1.m3u8', qualityType: 'SUPER', level: 130),
        ], manifests: 2),
      );
      expect(qualities, hasLength(1));
      expect(qualities.single.rank, 1000130, reason: 'the best of the ids occurrences orders it');
      expect(qualities.single.label, '蓝光 8M', reason: 'the first label the answer gave wins');
      expect(qualities.single.urls, ['https://a.cdn/1.m3u8', 'https://b.cdn/1.m3u8'], reason: 'both CDNs, once each');
    });

    test('a representation the player cannot use is left out', () {
      expect(
        _kindOf(
          _res([
            _representation(qualityType: 'A', hidden: true),
            _representation(qualityType: 'B', url: 'ftp://a.cdn/1.m3u8'),
            _representation(qualityType: 'C', url: 'https:///no-host'),
            _representation(qualityType: 'D', url: 'https://user:pw@a.cdn/1.m3u8'),
            _representation(qualityType: 'E', url: '1.m3u8'),
          ]),
        ),
        AcfunFailureKind.streamUnavailable,
        reason: 'hidden, non-http, hostless, credentialed and relative urls are no lines',
      );
      expect(
        _kindOf(
          _res([
            {'url': 'https://a.cdn/1.m3u8', 'hidden': 'true'},
          ]),
        ),
        AcfunFailureKind.streamUnavailable,
        reason: 'only the JSON true hides a representation',
      );
      expect(_kindOf(_res(const <Map<String, Object?>>[])), AcfunFailureKind.streamUnavailable);
      expect(_kindOf({'liveAdaptiveManifest': 'not a list'}), AcfunFailureKind.apiChanged);
      expect(_kindOf({'other': 1}), AcfunFailureKind.apiChanged);
      expect(_kindOf(null), AcfunFailureKind.apiChanged);
    });

    test('best first, and equal ranks by id', () {
      final qualities = _qualities(
        _res([
          _representation(qualityType: 'B', level: 20),
          _representation(qualityType: 'A', level: 20),
          _representation(qualityType: 'C', level: 90),
          _representation(qualityType: 'D', bitrate: 8000000),
        ]),
      );
      expect(qualities.map((quality) => quality.id), ['C', 'A', 'B', 'D']);
      expect(qualities.last.rank, 999999, reason: 'the highest bitrate still sits under the lowest level');
    });
  });

  group('the lines of a quality', () {
    test("a quality the answer does not have is never filled with another's urls", () {
      final qualities = _qualities(_res([_representation(qualityType: 'SUPER', level: 100)]));
      expect(
        () => AcfunPlayParser.lines(qualities, qualityId: 'HIGH', issuedAt: DateTime.now()),
        throwsA(
          isA<AcfunFailure>()
              .having((f) => f.kind, 'kind', AcfunFailureKind.streamUnavailable)
              .having((f) => f.message, 'message', contains('no quality HIGH')),
        ),
      );
    });

    test("the format is the path's, the label names the CDN, and a repeat is numbered", () {
      final expires = DateTime.utc(2026, 10);
      final qualities = _qualities(
        _res([
          _representation(qualityType: 'SUPER', url: _signed(expires)),
          _representation(
            qualityType: 'SUPER',
            url: _signed(expires, host: 'b.kouji.5695cdn.com', path: '2.flv'),
          ),
          _representation(
            qualityType: 'SUPER',
            url: _signed(expires, path: '3.M3U8'),
          ),
        ]),
      );
      final lines = AcfunPlayParser.lines(
        qualities,
        qualityId: 'SUPER',
        issuedAt: expires.subtract(const Duration(days: 1)),
      );
      expect(lines, hasLength(3));
      expect(lines.map((line) => line.format), [LiveStreamFormat.hls, LiveStreamFormat.flv, LiveStreamFormat.hls]);
      expect(lines.map((line) => line.lineLabel), [
        'a.kouji.5695cdn.com',
        'b.kouji.5695cdn.com',
        'a.kouji.5695cdn.com#2',
      ]);
      expect(lines.first.headers.toMap(), AcfunPlayParser.mediaHeaders());
      expect(lines.first.lease?.expiresAt, expires);
      expect(lines[2].url, contains('/3.M3U8?'));
    });

    test('a blank url in the answer gives no line', () {
      final qualities = <AcfunQuality>[
        (id: 'A', label: 'A', rank: 1, urls: ['  ', 'https://a.cdn/2.m3u8']),
      ];
      final lines = AcfunPlayParser.lines(qualities, qualityId: 'A', issuedAt: DateTime.utc(2026));
      expect(lines, hasLength(1));
      expect(lines.single.url, 'https://a.cdn/2.m3u8');
      expect(lines.single.lineLabel, 'a.cdn');
    });
  });

  group('the lease a signed url carries', () {
    test('the first field of auth_key is the expiry', () {
      final issued = DateTime.utc(2026);
      final expires = issued.add(const Duration(days: 30));
      final lease = AcfunPlayParser.lease(Uri.parse(_signed(expires)), issued)!;
      expect(lease.expiresAt, expires);
      expect(lease.refreshAt, expires.subtract(AcfunPlayParser.leaseLead), reason: 'ten minutes before, by default');

      final soon = AcfunPlayParser.lease(Uri.parse(_signed(issued.add(const Duration(minutes: 8)))), issued)!;
      expect(
        soon.expiresAt!.difference(soon.refreshAt),
        const Duration(minutes: 2),
        reason: 'never more than a quarter',
      );
    });

    test('no key, or a key that cannot be read, says nothing about a lease', () {
      final issued = DateTime.utc(2026);
      expect(AcfunPlayParser.lease(Uri.parse('https://a.cdn/1.m3u8'), issued), isNull);
      expect(AcfunPlayParser.lease(Uri.parse('https://a.cdn/1.m3u8?auth_key='), issued), isNull);
      expect(AcfunPlayParser.lease(Uri.parse('https://a.cdn/1.m3u8?auth_key=soon-x'), issued), isNull);
      expect(
        AcfunPlayParser.lease(Uri.parse('https://a.cdn/1.m3u8?auth_key=-1-x'), issued),
        isNull,
        reason: 'a negative expiry is a number, and a past one gives no lease',
      );
    });

    test('an expired address is dead unless the caller asks what it was', () {
      final issued = DateTime.utc(2026);
      final past = Uri.parse(_signed(issued.subtract(const Duration(hours: 1))));
      expect(AcfunPlayParser.lease(past, issued), isNull);
      final known = AcfunPlayParser.lease(past, issued, allowExpired: true)!;
      expect(known.expiresAt!.isBefore(known.refreshAt), isFalse);
      expect(known.refreshAt, known.expiresAt!.subtract(AcfunPlayParser.leaseLead));
    });

    test('the CDN checks all three of agent, origin and referer', () {
      expect(AcfunPlayParser.mediaHeaders(), {
        'user-agent': AcfunEndpoints.userAgent,
        'referer': AcfunEndpoints.referer,
        'origin': AcfunEndpoints.origin,
      });
      expect(AcfunPlayParser.leaseLead, const Duration(minutes: 10));
    });
  });
}
