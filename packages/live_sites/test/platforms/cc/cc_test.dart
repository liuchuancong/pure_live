import 'dart:convert';

import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/platforms/cc/api/cc_endpoints.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_failure.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_room_parser.dart';
import 'package:test/test.dart';

final DateTime _issuedAt = DateTime.utc(2026, 9, 27, 12);

int _epoch(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;

String _media(String host, {bool hls = false, int? expires}) {
  final key = expires == null ? '' : '?auth_key=$expires-1-2-abc';
  return 'https://$host/live${hls ? '.m3u8' : '.flv'}$key';
}

Map<String, dynamic> _answer({
  String? sel = 'high',
  Object? video,
  String? cdn,
  Object? backup,
  String? backupCdn,
  Object? list,
  Object? mapping,
}) => {
  'vbrname_sel': ?sel,
  'videourl': ?video,
  'cdn_sel': ?cdn,
  'bakvideourl': ?backup,
  'bakcdn_sel': ?backupCdn,
  'vbrname_list': ?list,
  'vbrname_mapping': ?mapping,
};

void main() {
  group('qualities', () {
    test('the tier list is deduplicated, named by the answer and ordered best first', () {
      final qualities = CcRoomParser.qualities(
        _answer(
          list: ['original', 'blueray_5M_avc', 'high', 'original'],
          mapping: {'blueray_5M_avc': '蓝光5M', 'high': '高清'},
        ),
      );
      expect(qualities.map((quality) => quality.qualityId), ['original', 'blueray_5M_avc', 'high']);
      expect(qualities.map((quality) => quality.label), ['原画', '蓝光5M', '高清']);
      expect(qualities.map((quality) => quality.platformOrder), [3, 2, 1]);
      expect(qualities.every((quality) => !quality.isPlaybackUnconfirmed), isTrue);
    });

    test('a selection alone is one tier; no selection marks the list unconfirmed', () {
      final selected = CcRoomParser.qualities(_answer(sel: 'standard'));
      expect(selected.single.qualityId, 'standard');
      expect(selected.single.label, '标清');

      final unconfirmed = CcRoomParser.qualities(_answer(sel: null, list: ['original', 'standard']));
      expect(unconfirmed, hasLength(2));
      expect(unconfirmed.every((quality) => quality.isPlaybackUnconfirmed), isTrue);
      expect(() => CcRoomParser.qualities(_answer(sel: null)), throwsA(isA<CcFailure>()));
    });

    test('an answer says which tier it played, by its own mapping', () {
      expect(CcRoomParser.appliedQuality(_answer(sel: 'ultra', mapping: {'ultra': '蓝光'}))?.label, '蓝光');
      expect(CcRoomParser.appliedQuality(_answer(sel: 'original'))?.label, '原画');
      expect(CcRoomParser.appliedQuality(_answer())?.label, '高清');
      expect(CcRoomParser.appliedQuality(_answer(sel: null)), isNull);
    });
  });

  group('lines', () {
    final expiry = _epoch(_issuedAt.add(const Duration(seconds: 300)));

    test('the answer lines come first, labelled by CDN and leased by auth_key', () {
      final first = _answer(
        video: _media('cdn-a.example', expires: expiry),
        cdn: 'hs',
        backup: _media('cdn-b.example', hls: true, expires: expiry),
        backupCdn: 'ali',
      );
      final second = _answer(
        video: _media('cdn-c.example', expires: expiry),
        cdn: 'ks',
      );
      final otherTier = _answer(
        video: _media('cdn-d.example', expires: expiry),
        cdn: 'fws',
        sel: 'standard',
      );
      final repeat = _answer(
        video: _media('cdn-e.example', expires: expiry),
        cdn: 'hs',
      );
      final resolved = CcRoomParser.resolutionWithApplied([
        (data: first, issuedAt: _issuedAt),
        (data: second, issuedAt: _issuedAt),
        (data: otherTier, issuedAt: _issuedAt),
        (data: repeat, issuedAt: _issuedAt),
      ], roomId: '1001');
      expect(resolved.appliedQualityId, 'high');
      expect(resolved.lines.map((line) => line.lineLabel), ['hs', 'ali', 'ks']);
      expect(resolved.lines.map((line) => line.format), [
        LiveStreamFormat.flv,
        LiveStreamFormat.hls,
        LiveStreamFormat.flv,
      ]);
      expect(resolved.lines.first.headers['referer'], '${CcEndpoints.origin}/1001/');
      expect(resolved.lines.first.lease?.expiresAt, DateTime.fromMillisecondsSinceEpoch(expiry * 1000, isUtc: true));
      expect(
        resolved.lines.first.lease?.refreshAt,
        resolved.lines.first.lease!.expiresAt!.subtract(CcEndpoints.leaseLead),
      );
      expect(resolved.lines.first.lease?.requiresReconnect, isFalse);
      expect(resolved.lines[1].lease?.requiresReconnect, isTrue);
    });

    test('no answer, or an answer without a URL, is api-changed', () {
      expect(() => CcRoomParser.resolutionWithApplied(const [], roomId: '1001'), throwsA(isA<CcFailure>()));
      expect(
        () => CcRoomParser.resolution([(data: _answer(), issuedAt: _issuedAt)], roomId: '1001'),
        throwsA(isA<CcFailure>()),
      );
    });

    test('the CDN codes no line covers are listed once each', () {
      final answer =
          _answer(
            video: _media('cdn-a.example', expires: expiry),
            cdn: 'hs',
            backup: _media('cdn-b.example', expires: expiry),
            backupCdn: 'ali',
          )..addAll({
            'cdn_list': ['hs', 'ali', 'ks', 'ks'],
          });
      expect(CcRoomParser.uncoveredCdns(answer), ['ks']);
    });
  });

  group('lease', () {
    test('a 300-second key is renewed a minute before it ends', () {
      final expiry = _epoch(_issuedAt.add(const Duration(seconds: 300)));
      final lease = CcRoomParser.lease(Uri.parse(_media('cdn-a.example', expires: expiry)), _issuedAt)!;
      expect(lease.expiresAt, DateTime.fromMillisecondsSinceEpoch(expiry * 1000, isUtc: true));
      expect(lease.refreshAt, lease.expiresAt!.subtract(CcEndpoints.leaseLead));
      expect(lease.requiresReconnect, isFalse);
      expect(
        CcRoomParser.lease(
          Uri.parse(_media('cdn-b.example', hls: true, expires: expiry)),
          _issuedAt,
        )!.requiresReconnect,
        isTrue,
      );
    });

    test('a short lifetime is led by a quarter, and no key means no lease', () {
      final expiry = _epoch(_issuedAt.add(const Duration(seconds: 120)));
      final lease = CcRoomParser.lease(Uri.parse(_media('cdn-a.example', expires: expiry)), _issuedAt)!;
      expect(lease.refreshAt, lease.expiresAt!.subtract(const Duration(seconds: 30)));
      expect(CcRoomParser.lease(Uri.parse(_media('cdn-a.example')), _issuedAt), isNull);
      expect(CcRoomParser.lease(Uri.parse(_media('cdn-a.example', expires: 0)), _issuedAt), isNull);
    });

    test('an expired key is no lease unless the caller allows it', () {
      final past = _epoch(_issuedAt.subtract(const Duration(minutes: 1)));
      final url = Uri.parse(_media('cdn-a.example', hls: true, expires: past));
      expect(CcRoomParser.lease(url, _issuedAt), isNull);
      final lease = CcRoomParser.lease(url, _issuedAt, allowExpired: true)!;
      expect(lease.expiresAt, DateTime.fromMillisecondsSinceEpoch(past * 1000, isUtc: true));
      expect(lease.refreshAt, lease.expiresAt!.subtract(CcEndpoints.leaseLead));
      expect(lease.requiresReconnect, isTrue);
    });
  });

  group('answers', () {
    test('a play answer must be an object, and a gone one is stream-unavailable', () {
      expect(CcRoomParser.playData('{"videourl":"x"}'), containsPair('videourl', 'x'));
      expect(
        () => CcRoomParser.playData('[]'),
        throwsA(isA<CcFailure>().having((failure) => failure.kind, 'kind', CcFailureKind.apiChanged)),
      );
      expect(
        () => CcRoomParser.playData('{}', status: 410),
        throwsA(isA<CcFailure>().having((failure) => failure.kind, 'kind', CcFailureKind.streamUnavailable)),
      );
      expect(() => CcRoomParser.playData('{}', status: 404), throwsA(isA<CcFailure>()));
      expect(
        () => CcRoomParser.playData(jsonEncode({'x': 1}), status: 429),
        throwsA(isA<CcFailure>().having((failure) => failure.kind, 'kind', CcFailureKind.rateLimited)),
      );
    });
  });
}
