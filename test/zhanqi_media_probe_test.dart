import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/zhanqi/zhanqi_api.dart';
import 'package:pure_live/core/site/zhanqi/zhanqi_media_api.dart';

void main() {
  test('routed candidate failure falls through to byte-verified direct FLV', () async {
    final requested = <Uri>[];
    final api = ZhanqiMediaApi(
      probeTransport: (uri, headers, cancel) async {
        requested.add(uri);
        expect(headers['Referer'], ZhanqiApi.headers['Referer']);
        if (uri.host.endsWith('.tbcache.com')) {
          return ZhanqiMediaProbeResponse(status: 502, prefix: Uint8List(0));
        }
        return ZhanqiMediaProbeResponse(status: 206, prefix: _flv());
      },
    );
    final result = await api.validate(
      _resolution(
        _source(
          'https://alhdl-cdn.zhanqi.tv/zqlive/101_fixture.flv?k=direct',
          routed: ['https://route.tbcache.com/alhdl-cdn.zhanqi.tv/zqlive/101_fixture.flv?k=routed'],
        ),
      ),
    );

    expect(requested.map((uri) => uri.host), ['route.tbcache.com', 'alhdl-cdn.zhanqi.tv']);
    expect(result, hasLength(1));
    expect(result.single.kind, ZhanqiMediaKind.flv);
    expect(result.single.uri, Uri.parse('https://alhdl-cdn.zhanqi.tv/zqlive/101_fixture.flv?k=direct'));
  });

  test('HLS marker with UTF-8 BOM is admitted while HTML success is rejected', () async {
    final hls = _source('https://wshls-cdn.zhanqi.tv/zqlive/101_fixture/playlist.m3u8');
    final valid = ZhanqiMediaApi(
      probeTransport: (_, _, _) async => ZhanqiMediaProbeResponse(
        status: 200,
        prefix: Uint8List.fromList([0xef, 0xbb, 0xbf, ...'#EXTM3U\n#EXT-X-VERSION:3'.codeUnits]),
      ),
    );
    final result = await valid.validate(_resolution(hls));
    expect(result.single.kind, ZhanqiMediaKind.hls);

    final html = ZhanqiMediaApi(
      probeTransport: (_, _, _) async =>
          ZhanqiMediaProbeResponse(status: 200, prefix: Uint8List.fromList('<!DOCTYPE html>'.codeUnits)),
    );
    await expectLater(html.validate(_resolution(hls)), _failure(ZhanqiFailure.mediaUnavailable));
  });

  test('probe budget is global and leaves later sources untouched', () async {
    final requested = <Uri>[];
    final api = ZhanqiMediaApi(
      probeTransport: (uri, _, _) async {
        requested.add(uri);
        return ZhanqiMediaProbeResponse(status: 404, prefix: Uint8List(0));
      },
    );
    await expectLater(
      api.validate(
        _resolution(
          _source('https://first.example/zqlive/101_fixture.flv'),
          _source('https://second.example/zqlive/101_fixture.flv'),
        ),
        maxCandidates: 1,
      ),
      _failure(ZhanqiFailure.mediaUnavailable),
    );
    expect(requested.map((uri) => uri.host), ['first.example']);
  });

  test('all transport failures stay distinct from negative media evidence', () async {
    final api = ZhanqiMediaApi(probeTransport: (_, _, _) async => throw StateError('offline'));
    await expectLater(
      api.validate(_resolution(_source('https://media.example/zqlive/101_fixture.flv'))),
      _failure(ZhanqiFailure.transport),
    );

    var attempt = 0;
    final mixed = ZhanqiMediaApi(
      probeTransport: (_, _, _) async {
        attempt++;
        if (attempt == 1) throw StateError('route failed');
        return ZhanqiMediaProbeResponse(status: 404, prefix: Uint8List(0));
      },
    );
    await expectLater(
      mixed.validate(
        _resolution(
          _source(
            'https://media.example/zqlive/101_fixture.flv',
            routed: ['https://route.tbcache.com/media.example/zqlive/101_fixture.flv'],
          ),
        ),
      ),
      _failure(ZhanqiFailure.mediaUnavailable),
    );
  });

  test('caller cancellation stops a pending probe', () async {
    final api = ZhanqiMediaApi(
      probeTransport: (_, _, cancel) async {
        await cancel.whenCancel;
        throw cancel.cancelError!;
      },
    );
    final token = CancelToken();
    final pending = api.validate(_resolution(_source('https://media.example/zqlive/101_fixture.flv')), cancel: token);
    token.cancel('done');
    await expectLater(pending, _failure(ZhanqiFailure.cancelled));
  });

  test('identity and budget bounds fail before a network probe', () async {
    var calls = 0;
    final api = ZhanqiMediaApi(
      probeTransport: (_, _, _) async {
        calls++;
        return ZhanqiMediaProbeResponse(status: 200, prefix: _flv());
      },
    );
    final invalid = ZhanqiMediaResolution(
      roomId: '101',
      videoId: '102_fixture',
      routeState: ZhanqiRouteState.notRequired,
      sources: [_source('https://media.example/zqlive/101_fixture.flv')],
    );
    await expectLater(api.validate(invalid), _failure(ZhanqiFailure.identity));
    await expectLater(
      api.validate(_resolution(_source('https://media.example/zqlive/101_fixture.flv')), maxCandidates: 0),
      _failure(ZhanqiFailure.schema),
    );
    expect(calls, 0);
  });
}

Uint8List _flv() => Uint8List.fromList([0x46, 0x4c, 0x56, 1, 5, 0, 0, 0, 9, 0, 0, 0, 0]);

ZhanqiMediaSource _source(String direct, {List<String> routed = const []}) => ZhanqiMediaSource(
  cdnKey: 202,
  suffix: '',
  lineIndices: const [0],
  qualityIndices: const [0],
  directUrl: Uri.parse(direct),
  routedUrls: routed.map(Uri.parse),
  headers: ZhanqiApi.headers,
);

ZhanqiMediaResolution _resolution(ZhanqiMediaSource first, [ZhanqiMediaSource? second]) => ZhanqiMediaResolution(
  roomId: '101',
  videoId: '101_fixture',
  routeState: ZhanqiRouteState.resolved,
  sources: [first, ?second],
);

Matcher _failure(ZhanqiFailure kind) => throwsA(isA<ZhanqiException>().having((error) => error.kind, 'kind', kind));
