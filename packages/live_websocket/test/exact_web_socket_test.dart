import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// Platform-internal test code: constructor-name rules are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:live_websocket/live_websocket.dart' hide WebSocketException;
import 'package:test/test.dart';

/// A raw TCP server that plays the other end of one WebSocket connection.
final class _RawServer {
  _RawServer._(this._server) {
    _server.listen((socket) {
      _socket = socket;
      socket.listen(
        (data) {
          _buffer.addAll(data);
          _pump();
        },
        onDone: () {
          _peerDone = true;
          _pump();
        },
        onError: (Object _) {},
      );
      _connected.complete();
    });
  }

  static Future<_RawServer> start() async => _RawServer._(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));

  final ServerSocket _server;
  final Completer<void> _connected = Completer();
  final List<int> _buffer = [];
  final List<void Function()> _waiters = [];
  Socket? _socket;
  bool _peerDone = false;

  int get port => _server.port;

  /// A `ws` address on this server.
  Uri get url => Uri.parse('ws://127.0.0.1:$port/websocket?appid=yymwebh5');

  void _pump() {
    for (final waiter in List.of(_waiters)) {
      waiter();
    }
  }

  Future<T> _take<T>(T? Function() read) {
    final result = Completer<T>();
    void attempt() {
      if (result.isCompleted) return;
      final value = read();
      if (value != null) {
        result.complete(value);
      } else if (_peerDone) {
        result.completeError(StateError('the client closed the connection'));
      }
    }

    _waiters.add(attempt);
    attempt();
    return result.future.whenComplete(() => _waiters.remove(attempt)).timeout(const Duration(seconds: 10));
  }

  /// The request head, without its blank line.
  Future<String> head() => _take(() {
    final text = latin1.decode(_buffer);
    final end = text.indexOf('\r\n\r\n');
    if (end < 0) return null;
    _buffer.removeRange(0, end + 4);
    return text.substring(0, end);
  });

  /// Answers the upgrade of [head].
  void accept(String head) {
    final key = RegExp(r'^Sec-WebSocket-Key: (.+)$', multiLine: true).firstMatch(head)!.group(1)!;
    send([
      ...latin1.encode(
        [
          'HTTP/1.1 101 Switching Protocols',
          'Upgrade: websocket',
          'Connection: Upgrade',
          'Sec-WebSocket-Accept: ${ExactWebSocket.acceptKey(key)}',
          '',
          '',
        ].join('\r\n'),
      ),
    ]);
  }

  /// Sends one unmasked frame.
  void sendFrame(int opcode, List<int> payload) {
    final header = BytesBuilder()..addByte(0x80 | opcode);
    if (payload.length <= 125) {
      header.addByte(payload.length);
    } else {
      header.add([126, (payload.length >> 8) & 0xff, payload.length & 0xff]);
    }
    send([...header.takeBytes(), ...payload]);
  }

  /// Reads the next client frame, unmasked and with its mask stripped.
  Future<({bool fin, int opcode, bool masked, List<int> payload})> frame() => _take(() {
    if (_buffer.length < 2) return null;
    var length = _buffer[1] & 0x7f;
    var offset = 2;
    if (length == 126) {
      if (_buffer.length < 4) return null;
      length = (_buffer[2] << 8) | _buffer[3];
      offset = 4;
    }
    final masked = _buffer[1] & 0x80 != 0;
    final mask = masked ? _buffer.sublist(offset, offset + 4) : const [0, 0, 0, 0];
    if (masked) offset += 4;
    if (_buffer.length < offset + length) return null;
    final payload = [for (var index = 0; index < length; index++) _buffer[offset + index] ^ mask[index & 3]];
    final frame = (fin: _buffer[0] & 0x80 != 0, opcode: _buffer[0] & 0x0f, masked: masked, payload: payload);
    _buffer.removeRange(0, offset + length);
    return frame;
  });

  void send(List<int> bytes) => _socket!.add(bytes);

  Future<void> close() async {
    try {
      await _socket?.close();
    } on Object {
      // The test sent its own close already.
    }
    _socket?.destroy();
    await _server.close();
  }
}

void main() {
  group('ExactWebSocket', () {
    test('writes the browser-spelled handshake and reads a text frame', () async {
      final server = await _RawServer.start();
      addTearDown(server.close);
      final connecting = ExactWebSocket.connect(
        server.url,
        headers: const {'User-Agent': 'Mozilla/5.0', 'Origin': 'https://www.yy.com'},
      );
      final head = await server.head();
      server.accept(head);
      final client = await connecting;
      final lines = head.split('\r\n');
      expect(lines.first, 'GET /websocket?appid=yymwebh5 HTTP/1.1');
      expect(lines, contains('Connection: Upgrade'));
      expect(lines, contains('Upgrade: websocket'));
      expect(lines, contains('User-Agent: Mozilla/5.0'));
      expect(lines, contains('Origin: https://www.yy.com'));
      expect(lines.where((line) => line.startsWith('Sec-WebSocket-Key: ')), hasLength(1));

      final message = client.stream.first;
      server.sendFrame(1, utf8.encode('hello'));
      expect(await message, 'hello');
      await client.close();
    });

    test('unmasks what it sends and answers a ping', () async {
      final server = await _RawServer.start();
      addTearDown(server.close);
      final connecting = ExactWebSocket.connect(server.url);
      final head = await server.head();
      server.accept(head);
      final client = await connecting;
      final incoming = client.stream.first;

      client.add('hi');
      final text = await server.frame();
      expect(text.fin, isTrue);
      expect(text.opcode, 1);
      expect(text.masked, isTrue);
      expect(text.payload, const [104, 105]);

      server.sendFrame(9, const [1, 2, 3]);
      final pong = await server.frame();
      expect(pong.opcode, 10);
      expect(pong.payload, const [1, 2, 3]);
      server.sendFrame(1, utf8.encode('done'));
      expect(await incoming, 'done');
      await client.close();
    });

    test('joins a fragmented message and reports a server close code', () async {
      final server = await _RawServer.start();
      addTearDown(server.close);
      final connecting = ExactWebSocket.connect(server.url);
      final head = await server.head();
      server.accept(head);
      final client = await connecting;
      final incoming = client.stream.first;

      server
        ..send([0x01, 2, ...ascii.encode('he')])
        ..send([0x80, 3, ...ascii.encode('llo')]);
      expect(await incoming, 'hello');

      server.send([0x88, 4, 0x03, 0xe8, ...ascii.encode('by')]);
      await client.close();
      expect(client.closeCode, 1000);
      expect(client.closeReason, 'by');
    });

    test('rejects a handshake with the wrong accept value', () async {
      final server = await _RawServer.start();
      addTearDown(server.close);
      final opening = ExactWebSocket.connect(server.url);
      final failure = expectLater(opening, throwsA(isA<WebSocketException>()));
      await server.head();
      server.send(
        latin1.encode(
          [
            'HTTP/1.1 101 Switching Protocols',
            'Upgrade: websocket',
            'Connection: Upgrade',
            'Sec-WebSocket-Accept: nope',
            '',
            '',
          ].join('\r\n'),
        ),
      );
      await failure;
    });
  });
}
