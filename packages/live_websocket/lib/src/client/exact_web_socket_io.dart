import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:live_websocket/src/socket_channel.dart';

/// A [SocketConnector] for chat edges that only answer an opening handshake
/// spelled the way a browser spells it.
///
/// `dart:io` lower-cases `Connection`, `Upgrade` and the `Sec-WebSocket-*`
/// fields of its handshake; YY's and SOOP's edges then leave the upgrade
/// pending until the connect timeout. [ExactWebSocket] writes the request
/// itself, in the caller's own spelling and order.
///
/// The connection is always direct, like the reference's connector; the
/// socket path carries no proxy, and [pingInterval] is not used here (YY and
/// SOOP drive their own application-level keep-alive).
Future<SocketChannel> exactWebSocketConnect(
  Uri endpoint, {
  required Map<String, String> headers,
  required Iterable<String>? protocols,
  required Duration connectTimeout,
  Duration? pingInterval,
}) => ExactWebSocket.connect(endpoint, headers: headers, protocols: protocols, connectTimeout: connectTimeout);

/// A WebSocket client (RFC 6455) whose opening handshake is sent exactly as
/// [handshake] writes it: the caller's headers in order and as spelled, then
/// `Connection: Upgrade`, `Upgrade: websocket`, `Cache-Control: no-cache`,
/// `Sec-WebSocket-Key`, `Sec-WebSocket-Version` and the subprotocols.
///
/// Text frames arrive as `String`, binary frames as `List<int>`;
/// fragmented messages are joined, pings answered, and a protocol violation
/// by the server closes the socket with an error on [stream]. Messages are
/// limited to 16 MiB and the response head to 32 KiB.
final class ExactWebSocket implements SocketChannel {
  new _(this._endpoint, this._connectTimeout, this._protocols, this._headers, this._random);

  /// Opens [endpoint] (`ws` or `wss`) and completes once the server accepted
  /// the upgrade. The TCP (and TLS) connection and then the upgrade answer
  /// each have [connectTimeout]. Throws [WebSocketException] when the server
  /// does not upgrade, [TimeoutException] or [SocketException] otherwise;
  /// [random] makes the key and the masks (tests).
  static Future<ExactWebSocket> connect(
    Uri endpoint, {
    Map<String, String> headers = const {},
    Iterable<String>? protocols,
    Duration connectTimeout = const Duration(seconds: 10),
    Random? random,
  }) async {
    if (endpoint.scheme != 'ws' && endpoint.scheme != 'wss') {
      throw WebSocketException('Unsupported WebSocket scheme: ${endpoint.scheme}');
    }
    final socket = ExactWebSocket._(
      endpoint,
      connectTimeout,
      List.unmodifiable(protocols ?? const <String>[]),
      Map.unmodifiable(headers),
      random ?? Random.secure(),
    );
    unawaited(socket._open());
    await socket._ready.future;
    return socket;
  }

  /// The opening handshake for [endpoint] with the key [nonce]: `GET`,
  /// `Host`, the caller's [headers] except the ones this client controls,
  /// then the upgrade fields.
  static String handshake(
    Uri endpoint, {
    required String nonce,
    Iterable<String> protocols = const [],
    Map<String, String> headers = const {},
  }) {
    for (final MapEntry(key: name, :value) in headers.entries) {
      // A line break would let a caller's value inject header lines.
      if ('$name$value'.contains(RegExp('[\r\n]'))) {
        throw ArgumentError.value(name, 'headers', 'Holds a line break');
      }
    }
    final defaultPort = endpoint.scheme == 'wss' ? 443 : 80;
    final port = endpoint.hasPort ? endpoint.port : defaultPort;
    final host = port == defaultPort ? endpoint.host : '${endpoint.host}:$port';
    final path = endpoint.hasQuery ? '${endpoint.path}?${endpoint.query}' : endpoint.path;
    return [
      'GET ${path.isEmpty ? '/' : path} HTTP/1.1',
      'Host: $host',
      for (final MapEntry(key: name, :value) in headers.entries)
        if (!_controlled.contains(name.toLowerCase())) '$name: $value',
      'Connection: Upgrade',
      'Upgrade: websocket',
      'Cache-Control: no-cache',
      'Sec-WebSocket-Key: $nonce',
      'Sec-WebSocket-Version: 13',
      if (protocols.isNotEmpty) 'Sec-WebSocket-Protocol: ${protocols.join(', ')}',
      '',
      '',
    ].join('\r\n');
  }

  /// Checks the response [head] (without its blank line) to [handshake]
  /// with [nonce]: status 101, `Connection` with `upgrade`, `Upgrade:
  /// websocket`, the accept value of [nonce], and a subprotocol only among
  /// [requestedProtocols]. Returns the selected subprotocol; throws
  /// [WebSocketException] otherwise, also for a repeated `Upgrade`,
  /// `Sec-WebSocket-Accept` or `Sec-WebSocket-Protocol`.
  static String? verifyHandshake(String head, {required String nonce, Iterable<String> requestedProtocols = const []}) {
    final lines = head.split('\r\n');
    if (!RegExp(r'^HTTP/1\.[01] 101(?:\s|$)').hasMatch(lines.first)) {
      throw WebSocketException('WebSocket was not upgraded: ${lines.first}');
    }
    final fields = <String, List<String>>{};
    for (final line in lines.skip(1)) {
      final separator = line.indexOf(':');
      if (separator <= 0) continue;
      fields
          .putIfAbsent(line.substring(0, separator).trim().toLowerCase(), () => [])
          .add(line.substring(separator + 1).trim());
    }
    final connection = {
      for (final value in fields['connection'] ?? const <String>[])
        for (final token in value.split(',')) token.trim().toLowerCase(),
    };
    if (!connection.contains('upgrade') || _single(fields, 'upgrade')?.toLowerCase() != 'websocket') {
      throw const WebSocketException('WebSocket response omitted the Upgrade headers');
    }
    if (_single(fields, 'sec-websocket-accept') != acceptKey(nonce)) {
      throw const WebSocketException('WebSocket returned an invalid Sec-WebSocket-Accept');
    }
    final selected = _single(fields, 'sec-websocket-protocol');
    if (selected != null && !requestedProtocols.contains(selected)) {
      throw WebSocketException('WebSocket selected unexpected protocol $selected');
    }
    return selected;
  }

  /// The `Sec-WebSocket-Accept` value for the key [nonce] (RFC 6455 §4.2.2).
  static String acceptKey(String nonce) => base64.encode(_sha1(ascii.encode('$nonce$_acceptGuid')));

  static const String _acceptGuid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';
  static const int _maxHandshakeBytes = 32 * 1024;
  static const int _maxMessageBytes = 16 * 1024 * 1024;

  /// Fields [handshake] writes itself; the caller's spellings are dropped.
  static const Set<String> _controlled = {
    'host',
    'connection',
    'upgrade',
    'cache-control',
    'sec-websocket-key',
    'sec-websocket-version',
    'sec-websocket-protocol',
  };

  static String? _single(Map<String, List<String>> fields, String name) {
    final values = fields[name];
    if (values == null || values.isEmpty) return null;
    if (values.length != 1) throw WebSocketException('WebSocket repeated $name');
    return values.single;
  }

  final Uri _endpoint;
  final Duration _connectTimeout;
  final List<String> _protocols;
  final Map<String, String> _headers;
  final Random _random;
  final Completer<void> _ready = Completer();
  final Completer<void> _done = Completer();
  final StreamController<Object?> _incoming = StreamController();

  Socket? _socket;
  StreamSubscription<Uint8List>? _subscription;
  Timer? _handshakeTimer;
  Timer? _closeTimer;
  Uint8List _buffer = Uint8List(0);
  BytesBuilder? _fragment;
  int _fragmentOpcode = 0;
  String _nonce = '';
  bool _upgraded = false;
  bool _closed = false;
  bool _closeSent = false;

  /// The subprotocol the server selected, if any.
  String? get protocol => _protocol;
  String? _protocol;

  @override
  Stream<Object?> get stream => _incoming.stream;

  @override
  int? get closeCode => _closeCode;
  int? _closeCode;

  @override
  String? get closeReason => _closeReason;
  String? _closeReason;

  /// Sends a text (`String`) or binary (`List<int>`) message; throws
  /// [StateError] once the socket is closed.
  @override
  void add(Object data) {
    if (!_upgraded || _closed) throw StateError('WebSocket is not open');
    switch (data) {
      case String():
        _sendFrame(1, utf8.encode(data));
      case List<int>():
        _sendFrame(2, data);
      default:
        throw ArgumentError.value(data, 'data', 'WebSocket data must be String or List<int>');
    }
  }

  /// Starts the closing handshake with [code] and [reason]; the socket is
  /// released when the server answers, or after a second.
  @override
  Future<void> close([int? code, String? reason]) {
    if (_closed) return _done.future;
    _sendClose(code, reason);
    _closeTimer ??= Timer(const Duration(seconds: 1), _finish);
    return _done.future;
  }

  Future<void> _open() async {
    try {
      final secure = _endpoint.scheme == 'wss';
      final port = _endpoint.hasPort ? _endpoint.port : (secure ? 443 : 80);
      final socket = secure
          ? await SecureSocket.connect(
              _endpoint.host,
              port,
              timeout: _connectTimeout,
              supportedProtocols: const ['http/1.1'],
            )
          : await Socket.connect(_endpoint.host, port, timeout: _connectTimeout);
      if (_closed) {
        socket.destroy();
        return;
      }
      _attach(socket);
      await _sendUpgrade();
    } on Object catch (error, stackTrace) {
      _fail(error, stackTrace);
    }
  }

  void _attach(Socket socket) {
    _socket = socket;
    // Write failures surface as a closed stream; the sink's own future
    // must not raise them again.
    socket.done.ignore();
    _subscription = socket.listen(_receive, onError: _fail, onDone: _remoteDone, cancelOnError: true);
  }

  /// Sends the opening handshake; the answer is due within [_connectTimeout].
  Future<void> _sendUpgrade() async {
    try {
      final socket = _socket!;
      _nonce = base64.encode([for (var i = 0; i < 16; i++) _random.nextInt(256)]);
      socket.add(utf8.encode(handshake(_endpoint, nonce: _nonce, protocols: _protocols, headers: _headers)));
      await socket.flush();
      if (_closed || _upgraded) return;
      _startHandshakeTimer();
    } on Object catch (error, stackTrace) {
      _fail(error, stackTrace);
    }
  }

  void _startHandshakeTimer() => _handshakeTimer ??= Timer(
    _connectTimeout,
    () => _fail(TimeoutException('WebSocket handshake timed out', _connectTimeout)),
  );

  void _receive(Uint8List data) {
    if (_closed || data.isEmpty) return;
    _buffer = _buffer.isEmpty
        ? data
        : (BytesBuilder(copy: false)
                ..add(_buffer)
                ..add(data))
              .takeBytes();
    if (!_upgraded) {
      if (_buffer.length > _maxHandshakeBytes) {
        _fail(const WebSocketException('WebSocket response head is too large'));
        return;
      }
      final end = _headEnd(_buffer);
      if (end < 0) return;
      final head = latin1.decode(Uint8List.sublistView(_buffer, 0, end));
      _buffer = Uint8List.sublistView(_buffer, end + 4);
      try {
        _protocol = verifyHandshake(head, nonce: _nonce, requestedProtocols: _protocols);
      } on Object catch (error, stackTrace) {
        _fail(error, stackTrace);
        return;
      }
      _handshakeTimer?.cancel();
      _handshakeTimer = null;
      _upgraded = true;
      _ready.complete();
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
        _protocolError('WebSocket returned unsupported RSV bits');
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
            _protocolError('WebSocket frame exceeds $_maxMessageBytes bytes');
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
        _protocolError('WebSocket frame exceeds $_maxMessageBytes bytes');
        return;
      }
      if (_buffer.length < offset + length) return;
      final payload = Uint8List.fromList(Uint8List.sublistView(_buffer, offset, offset + length));
      if (masked) {
        for (var index = 0; index < payload.length; index++) {
          payload[index] ^= _buffer[maskOffset + (index & 3)];
        }
      }
      _buffer = Uint8List.sublistView(_buffer, offset + length);
      if (opcode >= 8 && (!fin || length > 125)) {
        _protocolError('WebSocket returned an invalid control frame');
        return;
      }
      switch (opcode) {
        case 0:
          final fragment = _fragment;
          if (fragment == null) {
            _protocolError('WebSocket returned an unexpected continuation frame');
            return;
          }
          fragment.add(payload);
          if (fragment.length > _maxMessageBytes) {
            _protocolError('WebSocket fragmented message is too large');
            return;
          }
          if (fin) {
            _fragment = null;
            _emit(_fragmentOpcode, fragment.takeBytes());
          }
        case 1 || 2:
          if (_fragment != null) {
            _protocolError('WebSocket started a new message before finishing the previous one');
            return;
          }
          if (fin) {
            _emit(opcode, payload);
          } else {
            _fragmentOpcode = opcode;
            _fragment = BytesBuilder(copy: false)..add(payload);
          }
        case 8:
          _handleClose(payload);
          return;
        case 9:
          _sendFrame(10, payload);
        case 10:
          break;
        default:
          _protocolError('WebSocket returned unknown opcode $opcode');
          return;
      }
    }
  }

  void _emit(int opcode, Uint8List payload) {
    if (opcode == 2) {
      _incoming.add(payload);
      return;
    }
    final String text;
    try {
      text = utf8.decode(payload);
    } on FormatException catch (error, stackTrace) {
      _sendClose(1007, 'Invalid UTF-8');
      _fail(error, stackTrace);
      return;
    }
    _incoming.add(text);
  }

  void _handleClose(Uint8List payload) {
    if (payload.length == 1) {
      _protocolError('WebSocket returned a one-byte close payload');
      return;
    }
    if (payload.length >= 2) {
      _closeCode = (payload[0] << 8) | payload[1];
      try {
        _closeReason = utf8.decode(payload.sublist(2));
      } on FormatException {
        _closeReason = '';
      }
    }
    if (!_closeSent) _sendFrame(8, payload);
    _finish();
  }

  void _protocolError(String message) {
    _sendClose(1002, message);
    _fail(WebSocketException(message));
  }

  void _sendFrame(int opcode, List<int> payload) {
    final socket = _socket;
    if (socket == null || _closed) return;
    final length = payload.length;
    final header = BytesBuilder(copy: false)..addByte(0x80 | opcode);
    if (length <= 125) {
      header.addByte(0x80 | length);
    } else if (length <= 0xffff) {
      header.add([0x80 | 126, (length >> 8) & 0xff, length & 0xff]);
    } else {
      header.addByte(0x80 | 127);
      for (var shift = 56; shift >= 0; shift -= 8) {
        header.addByte((length >> shift) & 0xff);
      }
    }
    final mask = [for (var i = 0; i < 4; i++) _random.nextInt(256)];
    header.add(mask);
    final masked = Uint8List(length);
    for (var index = 0; index < length; index++) {
      masked[index] = payload[index] ^ mask[index & 3];
    }
    socket
      ..add(header.takeBytes())
      ..add(masked);
  }

  void _sendClose([int? code, String? reason]) {
    if (_closeSent || _closed) return;
    _closeSent = true;
    _sendFrame(8, [
      if (code != null) ...[(code >> 8) & 0xff, code & 0xff],
      if (code != null && reason != null && reason.isNotEmpty) ...utf8.encode(reason),
    ]);
  }

  void _remoteDone() {
    if (!_upgraded) {
      _fail(const WebSocketException('WebSocket closed during the handshake'));
    } else {
      _finish();
    }
  }

  void _fail(Object error, [StackTrace? stackTrace]) {
    if (_closed) return;
    if (!_ready.isCompleted) {
      _ready.completeError(error, stackTrace);
    } else {
      _incoming.addError(error, stackTrace);
    }
    _finish();
  }

  void _finish() {
    if (_closed) return;
    _closed = true;
    _handshakeTimer?.cancel();
    _closeTimer?.cancel();
    unawaited(_subscription?.cancel());
    _socket?.destroy();
    if (!_incoming.isClosed) unawaited(_incoming.close());
    if (!_done.isCompleted) _done.complete();
  }

  static int _headEnd(Uint8List bytes) {
    for (var index = 0; index + 3 < bytes.length; index++) {
      if (bytes[index] == 13 && bytes[index + 1] == 10 && bytes[index + 2] == 13 && bytes[index + 3] == 10) {
        return index;
      }
    }
    return -1;
  }
}

/// SHA-1 of [message] (FIPS 180-4), for [ExactWebSocket.acceptKey] only:
/// the handshake check does not warrant a dependency.
Uint8List _sha1(List<int> message) {
  final length = message.length;
  final padded = Uint8List((length + 8) ~/ 64 * 64 + 64)
    ..setRange(0, length, message)
    ..[length] = 0x80;
  final view = ByteData.sublistView(padded)
    ..setUint32(padded.length - 8, (length * 8) ~/ 0x100000000)
    ..setUint32(padded.length - 4, (length * 8) & 0xffffffff);
  int rotate(int value, int bits) => ((value << bits) | (value >> (32 - bits))) & 0xffffffff;
  final state = [0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0];
  final words = Uint32List(80);
  for (var chunk = 0; chunk < padded.length; chunk += 64) {
    for (var i = 0; i < 16; i++) {
      words[i] = view.getUint32(chunk + i * 4);
    }
    for (var i = 16; i < 80; i++) {
      words[i] = rotate(words[i - 3] ^ words[i - 8] ^ words[i - 14] ^ words[i - 16], 1);
    }
    var [a, b, c, d, e] = state;
    for (var i = 0; i < 80; i++) {
      final (f, k) = switch (i ~/ 20) {
        0 => ((b & c) | (~b & d), 0x5A827999),
        1 => (b ^ c ^ d, 0x6ED9EBA1),
        2 => ((b & c) | (b & d) | (c & d), 0x8F1BBCDC),
        _ => (b ^ c ^ d, 0xCA62C1D6),
      };
      final next = (rotate(a, 5) + (f & 0xffffffff) + e + k + words[i]) & 0xffffffff;
      e = d;
      d = c;
      c = rotate(b, 30);
      b = a;
      a = next;
    }
    for (final (index, value) in [a, b, c, d, e].indexed) {
      state[index] = (state[index] + value) & 0xffffffff;
    }
  }
  final digest = ByteData(20);
  for (final (index, value) in state.indexed) {
    digest.setUint32(index * 4, value);
  }
  return digest.buffer.asUint8List();
}
