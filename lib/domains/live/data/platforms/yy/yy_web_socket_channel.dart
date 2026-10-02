import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const int _maxHandshakeBytes = 32 * 1024;
const int _maxMessageBytes = 16 * 1024 * 1024;

/// Connects to case-sensitive WebSocket edges while retaining the RFC header
/// spelling used by browsers.
///
/// YY and SOOP currently accept correctly cased RFC 6455 fields but silently
/// leave a lowercase Dart `HttpClient` upgrade pending. Other adapters retain
/// the SDK implementation; only verified incompatible edges opt into this
/// small transport.
WebSocketChannel connectCaseSensitiveWebSocket(
  String endpoint, {
  Duration? connectTimeout,
  Iterable<String>? protocols,
  Map<String, dynamic>? headers,
  HttpClient? customClient,
}) {
  // dart:io's HttpClient always lowercases the two controlled handshake
  // fields, so it cannot be used even when the generic app-proxy path created
  // one for this attempt. Release that unused client; YY stays on its domestic
  // direct route while the other site adapters retain normal proxy routing.
  customClient?.close(force: false);
  return YyWebSocketChannel.connect(
    Uri.parse(endpoint),
    connectTimeout: connectTimeout,
    protocols: protocols,
    headers: headers,
  );
}

WebSocketChannel connectYyWebSocket(
  String endpoint, {
  Duration? connectTimeout,
  Iterable<String>? protocols,
  Map<String, dynamic>? headers,
  HttpClient? customClient,
}) {
  return connectCaseSensitiveWebSocket(
    endpoint,
    connectTimeout: connectTimeout,
    protocols: protocols,
    headers: headers,
    customClient: customClient,
  );
}

class YyWebSocketChannel extends StreamChannelMixin<dynamic> implements WebSocketChannel {
  final Uri _endpoint;
  final Duration _connectTimeout;
  final List<String> _protocols;
  final Map<String, dynamic> _headers;
  final _readyCompleter = Completer<void>();
  final _doneCompleter = Completer<void>();
  final _incoming = StreamController<dynamic>(sync: true);
  late final _YyWebSocketSink _sink = _YyWebSocketSink(this);

  Socket? _socket;
  StreamSubscription<List<int>>? _subscription;
  Timer? _handshakeTimer;
  Timer? _closeTimer;
  Uint8List _buffer = Uint8List(0);
  BytesBuilder? _fragment;
  int? _fragmentOpcode;
  String? _nonce;
  bool _ready = false;
  bool _closed = false;
  bool _closeSent = false;

  @override
  String? protocol;

  @override
  int? closeCode;

  @override
  String? closeReason;

  YyWebSocketChannel._(this._endpoint, this._connectTimeout, this._protocols, this._headers) {
    unawaited(_open());
  }

  factory YyWebSocketChannel.connect(
    Uri endpoint, {
    Duration? connectTimeout,
    Iterable<String>? protocols,
    Map<String, dynamic>? headers,
  }) {
    if (endpoint.scheme != 'ws' && endpoint.scheme != 'wss') {
      throw WebSocketChannelException('Unsupported YY WebSocket scheme: ${endpoint.scheme}');
    }
    return YyWebSocketChannel._(
      endpoint,
      connectTimeout ?? const Duration(seconds: 10),
      List<String>.unmodifiable(protocols ?? const <String>[]),
      Map<String, dynamic>.unmodifiable(headers ?? const <String, dynamic>{}),
    );
  }

  @override
  Future<void> get ready => _readyCompleter.future;

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  Future<void> _open() async {
    try {
      final port = _endpoint.hasPort ? _endpoint.port : (_endpoint.scheme == 'wss' ? 443 : 80);
      final socket = _endpoint.scheme == 'wss'
          ? await SecureSocket.connect(
              _endpoint.host,
              port,
              timeout: _connectTimeout,
              supportedProtocols: const <String>['http/1.1'],
            )
          : await Socket.connect(_endpoint.host, port, timeout: _connectTimeout);
      if (_closed) {
        socket.destroy();
        return;
      }
      _socket = socket;
      _subscription = socket.listen(
        _receive,
        onError: (Object error, StackTrace stackTrace) => _fail(error, stackTrace),
        onDone: _remoteDone,
        cancelOnError: true,
      );
      _nonce = base64Encode(List<int>.generate(16, (_) => Random.secure().nextInt(256)));
      socket.add(
        utf8.encode(buildYyWebSocketHandshake(_endpoint, nonce: _nonce!, protocols: _protocols, headers: _headers)),
      );
      await socket.flush();
      _handshakeTimer = Timer(
        _connectTimeout,
        () => _fail(TimeoutException('YY WebSocket handshake timed out', _connectTimeout)),
      );
    } catch (error, stackTrace) {
      _fail(error, stackTrace);
    }
  }

  void _receive(List<int> data) {
    if (_closed || data.isEmpty) return;
    _buffer = Uint8List.fromList(<int>[..._buffer, ...data]);
    if (!_ready) {
      if (_buffer.length > _maxHandshakeBytes) {
        _fail(WebSocketChannelException('YY WebSocket response headers are too large'));
        return;
      }
      final headerEnd = _indexOfHeaderEnd(_buffer);
      if (headerEnd < 0) return;
      final response = latin1.decode(_buffer.sublist(0, headerEnd));
      final remainder = _buffer.sublist(headerEnd + 4);
      _buffer = Uint8List.fromList(remainder);
      try {
        protocol = validateYyWebSocketHandshake(response, nonce: _nonce!, requestedProtocols: _protocols);
      } catch (error, stackTrace) {
        _fail(error, stackTrace);
        return;
      }
      _handshakeTimer?.cancel();
      _handshakeTimer = null;
      _ready = true;
      _readyCompleter.complete();
    }
    _consumeFrames();
  }

  void _consumeFrames() {
    while (!_closed) {
      if (_buffer.length < 2) return;
      final first = _buffer[0];
      final second = _buffer[1];
      final fin = first & 0x80 != 0;
      final opcode = first & 0x0f;
      if (first & 0x70 != 0) {
        _protocolError('YY WebSocket returned unsupported RSV bits');
        return;
      }
      var offset = 2;
      var length = second & 0x7f;
      if (length == 126) {
        if (_buffer.length < 4) return;
        length = (_buffer[2] << 8) | _buffer[3];
        offset = 4;
      } else if (length == 127) {
        if (_buffer.length < 10) return;
        var value = 0;
        for (var index = 2; index < 10; index++) {
          value = value * 256 + _buffer[index];
          if (value > _maxMessageBytes) {
            _protocolError('YY WebSocket frame exceeds $_maxMessageBytes bytes');
            return;
          }
        }
        length = value;
        offset = 10;
      }
      final masked = second & 0x80 != 0;
      final maskOffset = offset;
      if (masked) offset += 4;
      if (length > _maxMessageBytes) {
        _protocolError('YY WebSocket frame exceeds $_maxMessageBytes bytes');
        return;
      }
      if (_buffer.length < offset + length) return;
      final payload = Uint8List.fromList(_buffer.sublist(offset, offset + length));
      if (masked) {
        for (var index = 0; index < payload.length; index++) {
          payload[index] ^= _buffer[maskOffset + (index & 3)];
        }
      }
      _buffer = Uint8List.fromList(_buffer.sublist(offset + length));
      if (opcode >= 8 && (!fin || length > 125)) {
        _protocolError('YY WebSocket returned an invalid control frame');
        return;
      }
      switch (opcode) {
        case 0:
          if (_fragment == null || _fragmentOpcode == null) {
            _protocolError('YY WebSocket returned an unexpected continuation frame');
            return;
          }
          _fragment!.add(payload);
          if (_fragment!.length > _maxMessageBytes) {
            _protocolError('YY WebSocket fragmented message is too large');
            return;
          }
          if (fin) {
            final completePayload = _fragment!.takeBytes();
            final completeOpcode = _fragmentOpcode!;
            _fragment = null;
            _fragmentOpcode = null;
            _emitData(completeOpcode, completePayload);
          }
          break;
        case 1:
        case 2:
          if (_fragment != null) {
            _protocolError('YY WebSocket started a new message before finishing the previous one');
            return;
          }
          if (fin) {
            _emitData(opcode, payload);
          } else {
            _fragmentOpcode = opcode;
            _fragment = BytesBuilder(copy: false)..add(payload);
          }
          break;
        case 8:
          _handleClose(payload);
          return;
        case 9:
          _sendFrame(10, payload);
          break;
        case 10:
          break;
        default:
          _protocolError('YY WebSocket returned unknown opcode $opcode');
          return;
      }
    }
  }

  void _emitData(int opcode, Uint8List payload) {
    try {
      _incoming.add(opcode == 1 ? utf8.decode(payload) : payload);
    } on FormatException catch (error, stackTrace) {
      _sendClose(1007, 'Invalid UTF-8');
      _fail(error, stackTrace);
    }
  }

  void _handleClose(Uint8List payload) {
    if (payload.length == 1) {
      _protocolError('YY WebSocket returned a one-byte close payload');
      return;
    }
    if (payload.length >= 2) {
      closeCode = (payload[0] << 8) | payload[1];
      try {
        closeReason = utf8.decode(payload.sublist(2));
      } on FormatException {
        closeReason = '';
      }
    }
    if (!_closeSent) _sendFrame(8, payload);
    _finish();
  }

  void _protocolError(String message) {
    _sendClose(1002, message);
    _fail(WebSocketChannelException(message));
  }

  void _sendData(dynamic value) {
    if (!_ready || _closed) throw StateError('YY WebSocket is not open');
    if (value is String) {
      _sendFrame(1, Uint8List.fromList(utf8.encode(value)));
    } else if (value is List<int>) {
      _sendFrame(2, Uint8List.fromList(value));
    } else {
      throw ArgumentError.value(value, 'value', 'WebSocket data must be String or List<int>');
    }
  }

  void _sendFrame(int opcode, Uint8List payload) {
    final socket = _socket;
    if (socket == null || _closed) return;
    final mask = List<int>.generate(4, (_) => Random.secure().nextInt(256));
    final header = BytesBuilder(copy: false)..addByte(0x80 | opcode);
    if (payload.length <= 125) {
      header.addByte(0x80 | payload.length);
    } else if (payload.length <= 0xffff) {
      header
        ..addByte(0x80 | 126)
        ..add(<int>[(payload.length >> 8) & 0xff, payload.length & 0xff]);
    } else {
      header.addByte(0x80 | 127);
      for (var shift = 56; shift >= 0; shift -= 8) {
        header.addByte((payload.length >> shift) & 0xff);
      }
    }
    header.add(mask);
    final masked = Uint8List(payload.length);
    for (var index = 0; index < payload.length; index++) {
      masked[index] = payload[index] ^ mask[index & 3];
    }
    socket
      ..add(header.takeBytes())
      ..add(masked);
  }

  void _sendClose([int? code, String? reason]) {
    if (_closeSent || _closed) return;
    _closeSent = true;
    final payload = BytesBuilder(copy: false);
    if (code != null) {
      payload.add(<int>[(code >> 8) & 0xff, code & 0xff]);
      if (reason != null && reason.isNotEmpty) payload.add(utf8.encode(reason));
    }
    _sendFrame(8, payload.takeBytes());
  }

  Future<void> _close([int? code, String? reason]) async {
    if (_closed) return _doneCompleter.future;
    if (!_ready) {
      _fail(WebSocketChannelException('YY WebSocket closed before handshake completed'));
      return _doneCompleter.future;
    }
    _sendClose(code, reason);
    _closeTimer ??= Timer(const Duration(seconds: 1), _finish);
    return _doneCompleter.future;
  }

  void _remoteDone() {
    if (!_readyCompleter.isCompleted) {
      _fail(WebSocketChannelException('YY WebSocket closed during handshake'));
    } else {
      _finish();
    }
  }

  void _fail(Object error, [StackTrace? stackTrace]) {
    if (_closed) return;
    if (!_readyCompleter.isCompleted) _readyCompleter.completeError(error, stackTrace);
    if (!_incoming.isClosed) _incoming.addError(error, stackTrace);
    _finish();
  }

  void _finish() {
    if (_closed) return;
    _closed = true;
    _handshakeTimer?.cancel();
    _closeTimer?.cancel();
    final subscription = _subscription;
    if (subscription != null) unawaited(subscription.cancel());
    _socket?.destroy();
    if (!_incoming.isClosed) unawaited(_incoming.close());
    if (!_doneCompleter.isCompleted) _doneCompleter.complete();
  }
}

class _YyWebSocketSink implements WebSocketSink {
  final YyWebSocketChannel _channel;

  _YyWebSocketSink(this._channel);

  @override
  Future<void> get done => _channel._doneCompleter.future;

  @override
  void add(dynamic data) => _channel._sendData(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _channel._fail(error, stackTrace);

  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) => _channel._close(closeCode, closeReason);
}

String buildYyWebSocketHandshake(
  Uri endpoint, {
  required String nonce,
  Iterable<String> protocols = const <String>[],
  Map<String, dynamic> headers = const <String, dynamic>{},
}) {
  final port = endpoint.hasPort ? endpoint.port : (endpoint.scheme == 'wss' ? 443 : 80);
  final defaultPort = endpoint.scheme == 'wss' ? 443 : 80;
  final host = port == defaultPort ? endpoint.host : '${endpoint.host}:$port';
  final path = endpoint.hasQuery ? '${endpoint.path}?${endpoint.query}' : endpoint.path;
  final requestPath = path.isEmpty ? '/' : path;
  final controlled = <String>{
    'host',
    'connection',
    'upgrade',
    'cache-control',
    'sec-websocket-key',
    'sec-websocket-version',
    'sec-websocket-protocol',
  };
  final lines = <String>['GET $requestPath HTTP/1.1', 'Host: $host'];
  headers.forEach((name, value) {
    if (controlled.contains(name.toLowerCase())) return;
    final values = value is Iterable && value is! String ? value : <dynamic>[value];
    for (final item in values) {
      lines.add('$name: $item');
    }
  });
  lines.addAll(<String>[
    'Connection: Upgrade',
    'Upgrade: websocket',
    'Cache-Control: no-cache',
    'Sec-WebSocket-Key: $nonce',
    'Sec-WebSocket-Version: 13',
    if (protocols.isNotEmpty) 'Sec-WebSocket-Protocol: ${protocols.join(', ')}',
    '',
    '',
  ]);
  return lines.join('\r\n');
}

String? validateYyWebSocketHandshake(
  String response, {
  required String nonce,
  Iterable<String> requestedProtocols = const <String>[],
}) {
  final lines = response.split('\r\n');
  if (lines.isEmpty || !RegExp(r'^HTTP/1\.[01] 101(?:\s|$)').hasMatch(lines.first)) {
    throw WebSocketChannelException('YY WebSocket was not upgraded: ${lines.isEmpty ? '' : lines.first}');
  }
  final headers = <String, List<String>>{};
  for (final line in lines.skip(1)) {
    final separator = line.indexOf(':');
    if (separator <= 0) continue;
    headers
        .putIfAbsent(line.substring(0, separator).trim().toLowerCase(), () => <String>[])
        .add(line.substring(separator + 1).trim());
  }
  final connectionTokens =
      headers['connection']?.expand((value) => value.split(',')).map((value) => value.trim().toLowerCase()).toSet() ??
      const <String>{};
  if (!connectionTokens.contains('upgrade') || _singleHeader(headers, 'upgrade')?.toLowerCase() != 'websocket') {
    throw WebSocketChannelException('YY WebSocket response omitted Upgrade headers');
  }
  final accept = _singleHeader(headers, 'sec-websocket-accept');
  if (accept != WebSocketChannel.signKey(nonce)) {
    throw WebSocketChannelException('YY WebSocket returned an invalid Sec-WebSocket-Accept');
  }
  final selectedProtocol = _singleHeader(headers, 'sec-websocket-protocol');
  if (selectedProtocol != null && !requestedProtocols.contains(selectedProtocol)) {
    throw WebSocketChannelException('YY WebSocket selected unexpected protocol $selectedProtocol');
  }
  return selectedProtocol;
}

String? _singleHeader(Map<String, List<String>> headers, String name) {
  final values = headers[name];
  if (values == null || values.isEmpty) return null;
  if (values.length != 1) throw WebSocketChannelException('YY WebSocket repeated $name');
  return values.single;
}

int _indexOfHeaderEnd(Uint8List bytes) {
  for (var index = 0; index + 3 < bytes.length; index++) {
    if (bytes[index] == 13 && bytes[index + 1] == 10 && bytes[index + 2] == 13 && bytes[index + 3] == 10) {
      return index;
    }
  }
  return -1;
}
