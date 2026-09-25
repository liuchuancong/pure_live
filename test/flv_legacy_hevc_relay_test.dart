import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/player/core/flv_legacy_hevc_relay.dart';
import 'package:pure_live/player/core/playback_source_transport.dart';

const _upstream = 'http://play-hw-las.livetech.shopee.co.id/live/id-live-1.flv?auditkey=fixture';

Uint8List _tag(int type, int timestamp, List<int> body) {
  final out = BytesBuilder()
    ..add([type, body.length >> 16, (body.length >> 8) & 0xff, body.length & 0xff])
    ..add([(timestamp >> 16) & 0xff, (timestamp >> 8) & 0xff, timestamp & 0xff, timestamp >> 24, 0, 0, 0])
    ..add(body);
  final size = 11 + body.length;
  out.add([size >> 24, (size >> 16) & 0xff, (size >> 8) & 0xff, size & 0xff]);
  return out.toBytes();
}

const _flvHeader = [0x46, 0x4c, 0x56, 1, 5, 0, 0, 0, 9, 0, 0, 0, 0];
const _hvc1 = [0x68, 0x76, 0x63, 0x31];

void main() {
  group('FlvLegacyHevcTagRewriter', () {
    test('maps sequence header, coded frames and end of sequence to Enhanced FLV', () {
      final rewriter = FlvLegacyHevcTagRewriter();
      final config = [1, 2, 3, 4];
      final nalus = [0, 0, 0, 2, 0x26, 0x01];

      final start = rewriter.rewrite(_tag(9, 100, [0x1c, 0, 0, 0, 0, ...config]));
      expect(start, _tag(9, 100, [0x90, ..._hvc1, ...config]));

      final frame = rewriter.rewrite(_tag(9, 133, [0x2c, 1, 0, 0, 0x21, ...nalus]));
      expect(frame, _tag(9, 133, [0xa1, ..._hvc1, 0, 0, 0x21, ...nalus]));

      final end = rewriter.rewrite(_tag(9, 166, [0x1c, 2, 0, 0, 0]));
      expect(end, _tag(9, 166, [0x92, ..._hvc1]));
      expect(rewriter.rewrittenTags, 3);
    });

    test('leaves audio, AVC, Enhanced and truncated tags untouched', () {
      final rewriter = FlvLegacyHevcTagRewriter();
      for (final tag in [
        _tag(8, 0, [0xaf, 1, 9, 9]),
        _tag(9, 0, [0x17, 1, 0, 0, 0, 1, 2]),
        _tag(9, 0, [0x91, ..._hvc1, 0, 0, 0, 1]),
        _tag(9, 0, [0x1c, 1, 0]),
        _tag(18, 0, [2, 0, 10]),
      ]) {
        expect(identical(rewriter.rewrite(tag), tag), isTrue);
      }
      expect(rewriter.rewrittenTags, 0);
    });
  });

  test('only Shopee Live FLV hosts are routed through the relay', () {
    expect(FlvLegacyHevcRelay.appliesTo('https://play-tx-las.livetech.shopee.co.id/live/a.flv?x=1'), isTrue);
    expect(FlvLegacyHevcRelay.appliesTo(_upstream), isTrue);
    expect(FlvLegacyHevcRelay.appliesTo('https://play-spe.livestream.shopee.co.id/live/id-live-1-2.flv?x=1'), isTrue);
    expect(FlvLegacyHevcRelay.appliesTo('https://play-tx-las.livetech.shopee.co.id/live/a.m3u8'), isFalse);
    expect(FlvLegacyHevcRelay.appliesTo('https://livetech.shopee.co.id.evil.example/live/a.flv'), isFalse);
    expect(FlvLegacyHevcRelay.appliesTo('https://hw.flv.huya.com/src/a.flv'), isFalse);
    expect(FlvLegacyHevcRelay.appliesTo('rtmp://play.livetech.shopee.co.id/live/a.flv'), isFalse);
  });

  group('relay', () {
    late HttpServer proxy;
    final requests = <HttpRequest>[];
    late Uint8List body;

    setUp(() async {
      requests.clear();
      body = Uint8List.fromList([
        ..._flvHeader,
        ..._tag(18, 0, [2, 0, 1, 0x41]),
        ..._tag(9, 0, [0x1c, 0, 0, 0, 0, 7, 7]),
        ..._tag(8, 0, [0xaf, 1, 5]),
        ..._tag(9, 33, [0x2c, 1, 0, 0, 0, 0, 0, 0, 1, 0x02]),
      ]);
      // Acts as the configured HTTP proxy so the CDN host needs no DNS.
      proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      proxy.listen((request) async {
        requests.add(request);
        request.response.headers.contentType = ContentType('video', 'x-flv');
        // Split mid-tag to exercise the framer across chunks.
        request.response.add(body.sublist(0, 20));
        await request.response.flush();
        request.response.add(body.sublist(20));
        await request.response.close();
      });
    });
    tearDown(() => proxy.close(force: true));

    Future<Uint8List> fetch(Uri uri) async {
      final client = HttpClient();
      try {
        final response = await (await client.getUrl(uri)).close();
        expect(response.statusCode, HttpStatus.ok);
        final out = BytesBuilder();
        await response.forEach(out.add);
        return out.toBytes();
      } finally {
        client.close(force: true);
      }
    }

    test('streams upstream FLV with only codec-12 video tags rewritten', () async {
      final relay = await FlvLegacyHevcRelay.start(_upstream, {
        'Referer': 'https://live.shopee.co.id/',
      }, findProxy: (_) => 'PROXY 127.0.0.1:${proxy.port}');
      expect(relay.inputUri.host, '127.0.0.1');
      final output = await fetch(relay.inputUri);
      expect(output, [
        ..._flvHeader,
        ..._tag(18, 0, [2, 0, 1, 0x41]),
        ..._tag(9, 0, [0x90, ..._hvc1, 7, 7]),
        ..._tag(8, 0, [0xaf, 1, 5]),
        ..._tag(9, 33, [0xa1, ..._hvc1, 0, 0, 0, 0, 0, 0, 1, 0x02]),
      ]);
      expect(requests.single.uri.toString(), _upstream);
      expect(requests.single.headers.value('referer'), 'https://live.shopee.co.id/');

      // libmpv may reconnect; each local request gets a fresh upstream.
      await fetch(relay.inputUri);
      expect(requests, hasLength(2));
      await relay.close();
      expect(relay.isClosed, isTrue);
    });

    test('rejects requests for any other local path', () async {
      final relay = await FlvLegacyHevcRelay.start(_upstream, const {}, findProxy: (_) => 'DIRECT');
      final client = HttpClient();
      try {
        final response = await (await client.getUrl(relay.inputUri.replace(path: '/guess/live.flv'))).close();
        expect(response.statusCode, HttpStatus.notFound);
        await response.drain<void>();
      } finally {
        client.close(force: true);
        await relay.close();
      }
      expect(requests, isEmpty);
    });
  });

  test('transport routes only libmpv opens of legacy HEVC hosts through a private relay', () async {
    final owner = PlaybackSourceTransport(createInput: (_, _, _) => throw StateError('unexpected HLS relay'));
    final opened = <(String, List<String>, Map<String, String>, bool)>[];
    Future<void> nativeOpen(String url, List<String> urls, Map<String, String> headers, bool private) async =>
        opened.add((url, urls, headers, private));

    await owner.open(
      url: _upstream,
      urls: const [_upstream],
      headers: const {'Referer': 'https://live.shopee.co.id/'},
      policy: null,
      nativeOpen: nativeOpen,
    );
    await owner.open(
      url: _upstream,
      urls: const [_upstream],
      headers: const {'Referer': 'https://live.shopee.co.id/'},
      policy: null,
      nativeOpen: nativeOpen,
      rewriteLegacyHevcFlv: true,
    );
    expect(opened.first.$1, _upstream);
    expect(opened.first.$4, isFalse);
    final local = Uri.parse(opened.last.$1);
    expect(local.host, '127.0.0.1');
    expect(opened.last.$2, [opened.last.$1]);
    expect(opened.last.$3, isEmpty);
    expect(opened.last.$4, isTrue);
    await owner.close();
  });
}
