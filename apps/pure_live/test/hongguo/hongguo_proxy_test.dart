import 'dart:convert' show utf8;
import 'dart:io' show HttpClient, HttpHeaders;
import 'dart:math' as math;
import 'dart:typed_data' show ByteData, BytesBuilder, Uint8List;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:pointycastle/export.dart' show AESEngine, CTRStreamCipher, KeyParameter, ParametersWithIV;
import 'package:pure_live/modules/hongguo/official/hongguo_media_crypto.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart' show HongguoRendition;
import 'package:pure_live/modules/hongguo/official/hongguo_proxy.dart' show HongguoStreamProxy;

/// The local decrypting proxy, argued over a real loopback server and a
/// stubbed CDN: the first read dresses the header and decrypts in place,
/// ranges answer with exactly the plain bytes they name — a suffix wider
/// than the file is the whole file — a moov beyond the probe asks for the
/// rest, parallel first reads share the one probe, a stream without a key
/// rides through untouched, and the registry forgets what it handed out.
void main() {
  const keyHex = '00112233445566778899aabbccddeeff';
  final key = _hexBytes(keyHex);
  final iv1 = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 1]);
  final iv2 = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 2]);

  HttpClient? client;
  HongguoStreamProxy? proxy;

  setUp(() {
    client = HttpClient();
  });

  tearDown(() async {
    await proxy?.close();
    client?.close(force: true);
  });

  /// The encrypted stream and the plain bytes a correct proxy serves: a
  /// dressed header, two samples, filler either side of them. The cipher
  /// is always built with the one key — [encrypted] only decides whether
  /// the rendition carries it (and so whether the proxy decrypts).
  ({Uint8List file, Uint8List plain}) station({int skip = 0, int base = 2000, bool encrypted = true}) {
    final built = _mp4(
      sizes: [100, 60],
      perChunk: [2],
      offsets: [base],
      auxSizes: [8, 8],
      aux: [...iv1, ...iv2],
      skip: skip,
    );
    final plain0 = List<int>.generate(100, (i) => 0x10 + i);
    final plain1 = List<int>.generate(60, (i) => 0x60 + i);
    final cipher0 = _ctrBytes(key, iv1, plain0);
    final cipher1 = _ctrBytes(key, iv2, plain1);
    final filler = base - built.data.length;
    final file = _cat([
      built.data,
      Uint8List(filler)..fillRange(0, filler, 0xAA),
      cipher0,
      cipher1,
      Uint8List(32)..fillRange(0, 32, 0xBB),
    ]);
    if (!encrypted) return (file: file, plain: file);
    final prepared = HongguoMediaCrypto.prepare(built.data, key);
    final plain = Uint8List.fromList(file)
      ..setRange(0, prepared.header.length, prepared.header)
      ..setRange(base, base + 100, Uint8List.fromList(plain0))
      ..setRange(base + 100, base + 160, Uint8List.fromList(plain1));
    return (file: file, plain: plain);
  }

  Future<String> serve(_CdnStub cdn, {bool encrypted = true}) async {
    final server = HongguoStreamProxy(http: cdn);
    proxy = server;
    return await server.register(
      HongguoRendition(quality: 1080, codec: 'h264', url: 'https://cdn.example/x.mp4', key: encrypted ? key : null),
    );
  }

  Future<({int status, String? contentRange, Uint8List bytes})> read(String url, {String? range}) async {
    final request = await client!.getUrl(Uri.parse(url));
    if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);
    final response = await request.close();
    final builder = BytesBuilder(copy: false);
    await response.forEach(builder.add);
    return (
      status: response.statusCode,
      contentRange: response.headers.value(HttpHeaders.contentRangeHeader),
      bytes: builder.takeBytes(),
    );
  }

  group('the plain walk', () {
    test('the first read serves the whole plain file', () async {
      final built = station();
      final url = await serve(_CdnStub(built.file));

      final answer = await read(url);
      expect(answer.status, 200); // no range, the whole file
      expect(answer.contentRange, isNull);
      expect(answer.bytes, built.plain);
    });

    test('a middle range answers with exactly the plain bytes it names', () async {
      final built = station();
      final url = await serve(_CdnStub(built.file));

      final answer = await read(url, range: 'bytes=2050-2119'); // straddles both samples
      expect(answer.status, 206);
      expect(answer.contentRange, 'bytes 2050-2119/${built.file.length}');
      expect(answer.bytes, built.plain.sublist(2050, 2120));
    });

    test('a suffix and an open end read from where they say', () async {
      final built = station();
      final url = await serve(_CdnStub(built.file));

      final suffix = await read(url, range: 'bytes=-100');
      expect(suffix.status, 206);
      expect(suffix.contentRange, 'bytes ${built.file.length - 100}-${built.file.length - 1}/${built.file.length}');
      expect(suffix.bytes, built.plain.sublist(built.file.length - 100));

      final openEnd = await read(url, range: 'bytes=2000-');
      expect(openEnd.status, 206);
      expect(openEnd.bytes, built.plain.sublist(2000));
    });

    test('a suffix wider than the file is the whole file, not a failure', () async {
      final built = station();
      final url = await serve(_CdnStub(built.file));

      final answer = await read(url, range: 'bytes=-99999');
      expect(answer.status, 206);
      expect(answer.contentRange, 'bytes 0-${built.file.length - 1}/${built.file.length}');
      expect(answer.bytes, built.plain);
    });

    test('a range past the end answers 416 honestly', () async {
      final built = station();
      final url = await serve(_CdnStub(built.file));

      final answer = await read(url, range: 'bytes=999999-');
      expect(answer.status, 416);
      expect(answer.contentRange, 'bytes */${built.file.length}');
      expect(answer.bytes, isEmpty);
    });

    test('a stream without a key rides through undecrypted', () async {
      final built = station(encrypted: false);
      final url = await serve(_CdnStub(built.file), encrypted: false);

      final answer = await read(url);
      expect(answer.status, 200);
      expect(answer.bytes, built.plain); // the cipher file, byte for byte
    });
  });

  group('the failures', () {
    test('an unknown token is a plain 404', () async {
      final built = station();
      final cdn = _CdnStub(built.file);
      final url = await serve(cdn);

      final answer = await read(url.replaceFirst(Uri.parse(url).pathSegments.first, 'deadbeefdeadbeef'));
      expect(answer.status, 404);
      expect(cdn.calls, isEmpty); // the cdn never heard of it
    });

    test('a cdn that refuses segments lands as 502', () async {
      final built = station();
      final url = await serve(_CdnStub(built.file, status: 200)); // a plain answer is not a segment

      final answer = await read(url);
      expect(answer.status, 502);
    });

    test('a cdn that names no size on a long probe refuses', () async {
      final built = station(skip: 300000, base: 300400); // the probe comes back full width
      final url = await serve(_CdnStub(built.file, reportedTotal: 0));

      final answer = await read(url);
      expect(answer.status, 502);
    });

    test('a cdn that names no size still serves a short file whole', () async {
      final built = station(); // well under the probe's width
      final url = await serve(_CdnStub(built.file, reportedTotal: 0));

      final answer = await read(url);
      expect(answer.status, 200);
      expect(answer.bytes, built.plain); // the file's own length is the truth
    });
  });

  group('the header walk', () {
    test('a moov beyond the probe asks for the rest, and the answer serves', () async {
      final built = station(skip: 300000, base: 300400); // the moov hides behind the probe's edge
      final cdn = _CdnStub(built.file);
      final url = await serve(cdn);

      final headerEnd = HongguoMediaCrypto.headerEnd(built.file, built.file.length);
      expect(headerEnd, greaterThan(256 * 1024)); // the skip box pushed it out

      final answer = await read(url);
      expect(answer.status, 200);
      expect(answer.bytes, built.plain);
      expect(cdn.calls.map((request) => request.headers['Range']), [
        'bytes=0-262143',
        'bytes=262144-${headerEnd - 1}',
        'bytes=0-${built.file.length - 1}',
      ]); // probe, the header's rest, then the ask itself
    });

    test('parallel first reads share the one probe', () async {
      final built = station();
      final cdn = _CdnStub(built.file);
      final url = await serve(cdn);

      final first = read(url);
      final second = read(url); // racing the first
      final (a: one, b: two) = (a: await first, b: await second);
      expect(one.status, 200);
      expect(two.status, 200);
      expect(one.bytes, built.plain);
      expect(two.bytes, built.plain);
      expect(cdn.calls.where((request) => request.headers['Range'] == 'bytes=0-262143'), hasLength(1));
    });
  });

  group('the registry', () {
    test('forget drops the one stream, clear drops them all', () async {
      final built = station();
      final cdn = _CdnStub(built.file);
      final server = HongguoStreamProxy(http: cdn);
      proxy = server;
      final first = await server.register(
        HongguoRendition(quality: 1080, codec: 'h264', url: 'https://cdn.example/a.mp4', key: key),
      );
      final second = await server.register(
        HongguoRendition(quality: 720, codec: 'h264', url: 'https://cdn.example/b.mp4', key: key),
      );
      expect(first, startsWith('http://127.0.0.1:'));
      expect(first, endsWith('/e.mp4'));
      expect(first, isNot(equals(second))); // each stream its own token

      final served = await read(second);
      expect(served.status, 200); // the second stream lives

      server.forget(first);
      final forgotten = await read(first);
      expect(forgotten.status, 404);

      final still = await read(second);
      expect(still.status, 200);
      expect(still.bytes, built.plain);

      server.clear();
      final cleared = await read(second);
      expect(cleared.status, 404);
    });
  });
}

Uint8List _hexBytes(String value) =>
    Uint8List.fromList([for (var i = 0; i < value.length; i += 2) int.parse(value.substring(i, i + 2), radix: 16)]);

Uint8List _chars(String value) => Uint8List.fromList(utf8.encode(value));

Uint8List _u32(int value) {
  final out = Uint8List(4);
  ByteData.sublistView(out).setUint32(0, value);
  return out;
}

Uint8List _cat(List<Uint8List> parts) {
  final total = parts.fold<int>(0, (sum, part) => sum + part.length);
  final out = Uint8List(total);
  var at = 0;
  for (final part in parts) {
    out.setRange(at, at + part.length, part);
    at += part.length;
  }
  return out;
}

Uint8List _box(String type, List<int> payload) =>
    _cat([_u32(8 + payload.length), _chars(type), Uint8List.fromList(payload)]);

/// Builds an encrypted header: ftyp, a moov — optionally with a skip box
/// shoving the stbl past the probe's edge — then the aux blob the saio
/// points at.
({Uint8List header, Uint8List data}) _mp4({
  required List<int> sizes,
  required List<int> perChunk,
  required List<int> offsets,
  required List<int> auxSizes,
  required List<int> aux,
  int skip = 0,
}) {
  Uint8List build(int auxAt) => _cat([
    _box('ftyp', _chars('isom2024')),
    _box('moov', [
      if (skip > 0) ..._box('skip', List<int>.filled(skip, 0xAA)),
      ..._box(
        'trak',
        _box('stbl', [
          ..._box('stsz', [
            0, 0, 0, 0, // flags
            ..._u32(0), // no default size: the sizes follow
            ..._u32(sizes.length),
            for (final size in sizes) ..._u32(size),
          ]),
          ..._box('stsc', [
            0,
            0,
            0,
            0,
            ..._u32(perChunk.length),
            for (var i = 0; i < perChunk.length; i++) ...[..._u32(i + 1), ..._u32(perChunk[i]), ..._u32(1)],
          ]),
          ..._box('stco', [0, 0, 0, 0, ..._u32(offsets.length), for (final offset in offsets) ..._u32(offset)]),
          ..._box('saiz', [0, 0, 0, 0, 0, ..._u32(auxSizes.length), ...auxSizes]),
          ..._box('saio', [0, 0, 0, 0, ..._u32(1), ..._u32(auxAt)]),
          ..._box('encv', _box('sinf', _box('frma', _chars('avc1')))),
        ]),
      ),
      ..._box('free', aux), // the aux-info rides as moov's last box, inside the header
    ]),
  ]);

  final auxAt = build(0).length - aux.length; // the free box's payload the saio names
  return (header: build(auxAt), data: build(auxAt));
}

Uint8List _ctrBytes(Uint8List key, Uint8List iv8, List<int> plain) {
  final iv = Uint8List(16)..setRange(0, 8, iv8);
  final cipher = CTRStreamCipher(AESEngine())..init(false, ParametersWithIV(KeyParameter(key), iv));
  return cipher.process(Uint8List.fromList(plain));
}

/// The CDN the proxy's tests code against: slices the file by the ask's
/// Range and reports the segment in `Content-Range`, the total it is told
/// to report (or none), with whatever status it was given.
final class _CdnStub implements LiveHttp {
  _CdnStub(this.file, {this.reportedTotal, this.status = 206});

  final Uint8List file;
  final int? reportedTotal;
  final int status;
  final calls = <LiveRequest>[];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    calls.add(request);
    final range = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(request.headers['Range'] ?? '')!;
    final start = int.parse(range.group(1)!);
    final end = math.min(int.parse(range.group(2)!), file.length - 1);
    return LiveResponse(
      statusCode: status,
      headers: {'content-range': 'bytes $start-$end/${reportedTotal ?? file.length}'},
      bodyBytes: Uint8List.fromList(file.sublist(start, end + 1)),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnsupportedError('the proxy buffers');

  @override
  void close() {}
}
