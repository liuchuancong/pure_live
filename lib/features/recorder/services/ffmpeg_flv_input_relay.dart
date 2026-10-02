import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'recorder_proxy_routing.dart';

/// Explicit, attempt-local evidence only. Normal recording allocates no capture.
/// Bytes are copied after submission to the native reader, before socket flush;
/// they prove relay input, not delivery, decoding or source completeness.
class FlvRelayDiagnostics {
  FlvRelayDiagnostics({required this.maxCaptureBytes}) {
    if (maxCaptureBytes < 0 || maxCaptureBytes > 64 * 1024 * 1024) {
      throw RangeError.range(maxCaptureBytes, 0, 64 * 1024 * 1024, 'maxCaptureBytes');
    }
  }

  final int maxCaptureBytes;
  final _capture = BytesBuilder();
  bool _attached = false;
  bool _truncated = false;
  int _submittedBytes = 0;
  int _submittedPackets = 0;

  int get submittedBytes => _submittedBytes;
  int get submittedPackets => _submittedPackets;
  bool get truncated => _truncated;
  Uint8List get capturedBytes => _capture.toBytes();

  void _attach() {
    if (_attached) throw StateError('FLV diagnostics already belong to an attempt');
    _attached = true;
  }

  void _observe(Uint8List packet) {
    _submittedBytes += packet.length;
    _submittedPackets++;
    // Keep only complete header/tag records; reaching the budget never changes
    // forwarding, backpressure, timestamps or the recording stop condition.
    if (_truncated) return;
    if (packet.length > maxCaptureBytes - _capture.length) {
      _truncated = true;
      return;
    }
    _capture.add(packet);
  }
}

/// Recorder-only FLV input with an explicit, packet-aligned end of input.
///
/// Cancelling FFmpegKit 0.11.1 interrupts output IO as well as input IO, so
/// buffered TS can be truncated. Closing this input normally lets FFmpeg drain
/// its muxer without setting the native cancellation flag. Media is copied,
/// never decoded/transcoded, and backpressure bounds the pending data.
class FFmpegFlvInputRelay {
  FFmpegFlvInputRelay._(this._server, this._client, this._upstream, this._headers, this._secret, this._diagnostics);

  final HttpServer _server;
  final HttpClient _client;
  final Uri _upstream;
  final Map<String, String> _headers;
  final String _secret;
  final FlvRelayDiagnostics? _diagnostics;
  StreamSubscription<HttpRequest>? _requests;
  Future<void>? _serving;
  Future<void>? _closing;
  bool _accepted = false;
  bool _finishing = false;
  bool _closed = false;
  bool _stopReady = false;
  int _forwardedBytes = 0;
  final _avcBoundary = FlvAvcAccessUnitBoundary();

  bool get finishRequested => _finishing;
  bool get hasPendingAccessUnit => _avcBoundary.hasPendingAccessUnit;
  int get forwardedBytes => _forwardedBytes;
  Uri get inputUri => Uri(scheme: 'http', host: '127.0.0.1', port: _server.port, path: '/$_secret/live.flv');

  static Future<FFmpegFlvInputRelay?> startForArguments(
    List<String> arguments, {
    FlvRelayDiagnostics? diagnostics,
  }) async {
    final index = arguments.indexOf('-i');
    if (index < 0 || index + 1 >= arguments.length) return null;
    final upstream = Uri.tryParse(arguments[index + 1]);
    if (upstream == null ||
        !const {'http', 'https'}.contains(upstream.scheme) ||
        !upstream.path.toLowerCase().endsWith('.flv')) {
      return null;
    }
    diagnostics?._attach();
    final headers = <String, String>{};
    for (var i = 0; i + 1 < index; i++) {
      if (arguments[i] == '-user_agent') headers['user-agent'] = arguments[i + 1];
      if (arguments[i] != '-headers') continue;
      for (final line in arguments[i + 1].split(RegExp(r'[\r\n]+'))) {
        final separator = line.indexOf(':');
        if (separator <= 0) continue;
        final name = line.substring(0, separator).trim().toLowerCase();
        if (const {
          'host',
          'connection',
          'content-length',
          'transfer-encoding',
          'range',
          'keep-alive',
          'proxy-authorization',
          'proxy-authenticate',
          'te',
          'trailer',
          'upgrade',
        }.contains(name)) {
          continue;
        }
        headers[name] = line.substring(separator + 1).trim();
      }
    }
    final client = HttpClient()
      ..findProxy = resolveRecorderProxyDirective
      ..connectionTimeout = const Duration(seconds: 15)
      ..autoUncompress = true;
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0, shared: false);
      final random = Random.secure();
      final secret = base64UrlEncode(List.generate(18, (_) => random.nextInt(256))).replaceAll('=', '');
      final relay = FFmpegFlvInputRelay._(server, client, upstream, headers, secret, diagnostics);
      relay._requests = server.listen((request) {
        if (request.method != 'GET' || request.uri.path != relay.inputUri.path || relay._closed) {
          unawaited(_reject(request, HttpStatus.notFound));
        } else if (relay._finishing || relay._accepted) {
          unawaited(_reject(request, HttpStatus.gone));
        } else {
          relay._accepted = true;
          relay._serving = relay._serve(request);
        }
      });
      return relay;
    } catch (_) {
      client.close(force: true);
      rethrow;
    }
  }

  List<String> replaceFirstInput(List<String> source) {
    final arguments = <String>[];
    final inputIndex = source.indexOf('-i');
    for (var i = 0; i < source.length; i++) {
      // The relay owns one upstream connection. Native HTTP retries against
      // this single-use local URL would turn its intentional EOF into a second
      // request/410. The recorder owns actual network recovery and new URLs.
      if (i < inputIndex &&
          const {
            '-reconnect',
            '-reconnect_streamed',
            '-reconnect_on_network_error',
            '-reconnect_on_http_error',
            '-reconnect_delay_max',
            '-reconnect_at_eof',
          }.contains(source[i])) {
        i++;
        continue;
      }
      arguments.add(source[i]);
    }
    arguments[arguments.indexOf('-i') + 1] = inputUri.toString();
    return List.unmodifiable(arguments);
  }

  Future<void> _serve(HttpRequest downstream) async {
    var sentHeader = false;
    try {
      final request = await _client.getUrl(_upstream);
      _headers.forEach((name, value) => request.headers.set(name, value));
      final upstream = await request.close().timeout(const Duration(seconds: 20));
      if (_finishing) return;
      if (upstream.statusCode != HttpStatus.ok) {
        downstream.response.statusCode = upstream.statusCode;
        return;
      }
      downstream.response.headers.contentType = ContentType('video', 'x-flv');
      downstream.response.headers.set('cache-control', 'no-store');
      downstream.response.bufferOutput = false;
      final framer = FlvInputFramer();
      await for (final chunk in upstream) {
        if (_stopReady || _closed) break;
        for (final packet in framer.add(chunk)) {
          if (_stopReady || _closed) break;
          _avcBoundary.observe(packet);
          downstream.response.add(packet);
          _forwardedBytes += packet.length;
          _diagnostics?._observe(packet);
          sentHeader = true;
          // Preserve every tag unchanged. If a forwarded AVC prefix already
          // starts the next access unit, finish only after its picture arrives.
          // The existing native stop deadline still bounds stalled lookahead.
          if (_finishing && !_avcBoundary.hasPendingAccessUnit) _stopReady = true;
        }
        await downstream.response.flush();
        if (_stopReady) break;
      }
      // An incomplete final upstream tag was never forwarded. Ordinary EOF is
      // handled by the recorder's existing recovery, not mistaken for offline.
    } catch (_) {
      if (!sentHeader && !_finishing) {
        try {
          downstream.response.statusCode = HttpStatus.badGateway;
        } on StateError {
          /* Already sent. */
        }
      }
    } finally {
      try {
        await downstream.response.close();
      } on Object {
        /* Native reader may already have stopped. */
      }
      _client.close(force: true);
    }
  }

  /// End at a complete tag AND a known AVC picture boundary. Prefix NALs
  /// (SEI/SPS/PPS/AUD) after a picture belong to a following access unit in the
  /// TS parser. Already-forwarded prefixes are never removed or rewritten.
  /// A pending picture drains within FFmpegService's existing three-second
  /// deadline; close/cancel still interrupts a stalled upstream immediately.
  Future<void> finish() async {
    _finishing = true;
    if (!_avcBoundary.hasPendingAccessUnit) {
      _stopReady = true;
      _client.close(force: true);
    }
    await _serving;
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    _finishing = true;
    _client.close(force: true);
    await _server.close(force: true);
    await _requests?.cancel();
    await _serving;
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

/// FLV framing only: preserve the original header and complete tag bytes.
/// A single FLV tag is at most 0xffffff payload bytes. No lifetime buffer grows.
class FlvInputFramer {
  final BytesBuilder _pending = BytesBuilder(copy: false);
  int _expected = 9;
  int _phase = 0;
  int get pendingBytes => _pending.length;

  Iterable<Uint8List> add(List<int> source) sync* {
    final bytes = source is Uint8List ? source : Uint8List.fromList(source);
    var offset = 0;
    while (offset < bytes.length) {
      final take = min(_expected - _pending.length, bytes.length - offset);
      _pending.add(Uint8List.sublistView(bytes, offset, offset + take));
      offset += take;
      if (_pending.length != _expected) continue;
      final packet = _pending.takeBytes();
      if (_phase == 0) {
        if (packet[0] != 0x46 || packet[1] != 0x4c || packet[2] != 0x56 || packet[3] != 1) {
          throw const FormatException('Invalid FLV header');
        }
        final headerSize = ByteData.sublistView(packet).getUint32(5);
        if (headerSize < 9 || headerSize > 65536) throw const FormatException('Invalid FLV header size');
        _expected = headerSize + 4;
        _pending.add(packet);
        _phase = 1;
      } else if (_phase == 1) {
        if (ByteData.sublistView(packet).getUint32(packet.length - 4) != 0) {
          throw const FormatException('Invalid FLV initial tag size');
        }
        _expected = 11;
        _phase = 2;
        yield packet;
      } else if (_phase == 2) {
        final dataSize = (packet[1] << 16) | (packet[2] << 8) | packet[3];
        _expected = 11 + dataSize + 4;
        _pending.add(packet);
        _phase = 3;
      } else {
        // PreviousTagSize is unreliable in some FLV producers accepted by
        // FFmpeg. DataSize defines the boundary; preserve the trailing field.
        _expected = 11;
        _phase = 2;
        yield packet;
      }
    }
  }
}

/// Constant-memory observation of classic AVC FLV tags, not a codec decoder.
/// The AVC length size is declared by the sequence header. Unknown codecs are
/// unchanged, and malformed AVC never clears an already uncertain boundary.
class FlvAvcAccessUnitBoundary {
  int? _lengthSize;
  bool _pending = false;
  bool get hasPendingAccessUnit => _pending;

  void observe(List<int> tag) {
    if (tag.length < 20 || tag[0] != 9 || (tag[11] & 0x80) != 0 || (tag[11] & 15) != 7) return;
    final end = tag.length - 4;
    if (tag[12] == 0) {
      // AVCDecoderConfigurationRecord: version and lengthSizeMinusOne.
      _lengthSize = end >= 23 && tag[16] == 1 && (tag[20] & 0xfc) == 0xfc ? (tag[20] & 3) + 1 : null;
      if (_lengthSize == 3) _lengthSize = null; // Reserved by AVC configuration.
      return;
    }
    if (tag[12] != 1 || _lengthSize == null) return;
    final size = _lengthSize!;
    var offset = 16;
    var pending = _pending;
    while (offset < end) {
      if (end - offset < size) {
        _pending = true;
        return;
      }
      var length = 0;
      for (var i = 0; i < size; i++) {
        length = (length << 8) | tag[offset + i];
      }
      offset += size;
      if (length == 0 || length > end - offset) {
        _pending = true;
        return;
      }
      final type = tag[offset] & 31;
      if (type == 1 || type == 2 || type == 5) {
        pending = false;
      } else if (type >= 6 && type <= 9) {
        pending = true;
      }
      offset += length;
    }
    _pending = pending;
  }
}
