import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pure_live/recorder/services/ffmpeg_flv_input_relay.dart';

/// Rewrites legacy "codec id 12" HEVC FLV video tags into Enhanced FLV.
///
/// Several CDNs extended classic FLV with HEVC as codec id 12 before Enhanced
/// RTMP existed. FFmpeg only learned that id in 8.0; the FFmpeg 7.1 inside
/// media_kit's libmpv drops the stream and plays audio only. Enhanced FLV
/// (`hvc1` FourCC) is understood since FFmpeg 6.1, so only the tag header
/// changes: NAL payloads and the HEVCDecoderConfigurationRecord are copied.
class FlvLegacyHevcTagRewriter {
  static const int _legacyHevcCodecId = 12;
  static const List<int> _hvc1 = [0x68, 0x76, 0x63, 0x31];

  int _rewrittenTags = 0;
  int get rewrittenTags => _rewrittenTags;

  /// [tag] is one complete FLV tag including its trailing PreviousTagSize, as
  /// produced by [FlvInputFramer]. Anything else is returned unchanged.
  Uint8List rewrite(Uint8List tag) {
    if (tag.length < 11 + 5 + 4 || (tag[0] & 0x1f) != 9) return tag;
    final flags = tag[11];
    if ((flags & 0x80) != 0 || (flags & 0x0f) != _legacyHevcCodecId) return tag;
    final dataSize = (tag[1] << 16) | (tag[2] << 8) | tag[3];
    if (dataSize < 5 || 11 + dataSize + 4 != tag.length) return tag;
    final frameType = (flags >> 4) & 0x07;
    final packetType = tag[12];
    // Legacy: flags, AVCPacketType, CompositionTime(3), data.
    // Enhanced: flags|packetType, FourCC, [CompositionTime(3) for coded frames], data.
    final List<int> prefix;
    final int payloadStart;
    switch (packetType) {
      case 0: // Sequence header -> SequenceStart.
        prefix = [0x80 | (frameType << 4), ..._hvc1];
        payloadStart = 16;
      case 1: // NALUs -> CodedFrames (keeps the composition time).
        prefix = [0x80 | (frameType << 4) | 1, ..._hvc1, tag[13], tag[14], tag[15]];
        payloadStart = 16;
      case 2: // End of sequence -> SequenceEnd.
        prefix = [0x80 | (frameType << 4) | 2, ..._hvc1];
        payloadStart = 11 + dataSize;
      default:
        return tag;
    }
    final payloadLength = 11 + dataSize - payloadStart;
    final newDataSize = prefix.length + payloadLength;
    if (newDataSize > 0xffffff) return tag;
    final out = Uint8List(11 + newDataSize + 4);
    out.setRange(0, 11, tag);
    out[1] = (newDataSize >> 16) & 0xff;
    out[2] = (newDataSize >> 8) & 0xff;
    out[3] = newDataSize & 0xff;
    out.setRange(11, 11 + prefix.length, prefix);
    out.setRange(11 + prefix.length, 11 + newDataSize, tag, payloadStart);
    ByteData.sublistView(out).setUint32(11 + newDataSize, 11 + newDataSize);
    _rewrittenTags++;
    return out;
  }
}

/// Playback-only loopback relay that applies [FlvLegacyHevcTagRewriter].
///
/// Only hosts known to serve codec-id-12 HEVC are routed here, so ordinary FLV
/// keeps its direct native connection. Every local request opens its own
/// upstream connection, which keeps libmpv's own reconnect behaviour intact.
class FlvLegacyHevcRelay {
  FlvLegacyHevcRelay._(this._server, this._upstream, this._headers, this._findProxy, this._secret);

  static const Set<String> _hostSuffixes = {'.livetech.shopee.co.id'};

  final HttpServer _server;
  final Uri _upstream;
  final Map<String, String> _headers;
  final String Function(Uri) _findProxy;
  final String _secret;
  final Set<HttpClient> _clients = {};
  final Set<Future<void>> _serving = {};
  StreamSubscription<HttpRequest>? _requests;
  Future<void>? _closing;
  bool _closed = false;

  bool get isClosed => _closed;
  Uri get inputUri => Uri(scheme: 'http', host: '127.0.0.1', port: _server.port, path: '/$_secret/live.flv');

  static bool appliesTo(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !const {'http', 'https'}.contains(uri.scheme.toLowerCase())) return false;
    if (!uri.path.toLowerCase().endsWith('.flv')) return false;
    final host = uri.host.toLowerCase();
    return _hostSuffixes.any(host.endsWith);
  }

  static Future<FlvLegacyHevcRelay> start(
    String url,
    Map<String, String> headers, {
    required String Function(Uri) findProxy,
  }) async {
    if (!appliesTo(url)) throw const FormatException('Expected a legacy HEVC FLV input');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0, shared: false);
    final random = Random.secure();
    final secret = base64UrlEncode(List.generate(18, (_) => random.nextInt(256))).replaceAll('=', '');
    final relay = FlvLegacyHevcRelay._(server, Uri.parse(url), Map.unmodifiable(headers), findProxy, secret);
    relay._requests = server.listen((request) {
      if (request.method != 'GET' || request.uri.path != relay.inputUri.path || relay._closed) {
        unawaited(_reject(request, HttpStatus.notFound));
        return;
      }
      late final Future<void> serving;
      serving = relay._serve(request).whenComplete(() => relay._serving.remove(serving));
      relay._serving.add(serving);
    });
    return relay;
  }

  Future<void> _serve(HttpRequest downstream) async {
    final client = HttpClient()
      ..findProxy = _findProxy
      ..connectionTimeout = const Duration(seconds: 15)
      ..autoUncompress = true;
    _clients.add(client);
    var sent = false;
    try {
      final request = await client.getUrl(_upstream);
      _headers.forEach((name, value) => request.headers.set(name, value));
      final upstream = await request.close().timeout(const Duration(seconds: 20));
      if (upstream.statusCode != HttpStatus.ok) {
        downstream.response.statusCode = upstream.statusCode;
        return;
      }
      downstream.response.headers.contentType = ContentType('video', 'x-flv');
      downstream.response.headers.set('cache-control', 'no-store');
      downstream.response.bufferOutput = false;
      final framer = FlvInputFramer();
      final rewriter = FlvLegacyHevcTagRewriter();
      await for (final chunk in upstream) {
        if (_closed) break;
        for (final packet in framer.add(chunk)) {
          downstream.response.add(rewriter.rewrite(packet));
          sent = true;
        }
        await downstream.response.flush();
      }
    } catch (_) {
      if (!sent) {
        try {
          downstream.response.statusCode = HttpStatus.badGateway;
        } on StateError {
          /* Headers already sent. */
        }
      }
    } finally {
      try {
        await downstream.response.close();
      } on Object {
        /* The native reader may already have gone. */
      }
      _clients.remove(client);
      client.close(force: true);
    }
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    for (final client in _clients.toList()) {
      client.close(force: true);
    }
    await _server.close(force: true);
    await _requests?.cancel();
    await Future.wait(_serving.toList());
  }

  static Future<void> _reject(HttpRequest request, int status) async {
    try {
      request.response.statusCode = status;
      await request.response.close();
    } on Object {
      /* Peer closed its request. */
    }
  }
}
