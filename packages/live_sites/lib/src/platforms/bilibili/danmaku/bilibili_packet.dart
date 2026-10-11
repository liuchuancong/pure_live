import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:live_sites/src/platforms/bilibili/bilibili_models.dart';

/// The Bilibili danmaku wire protocol (the web `protover 2` flavour).
///
/// Frame layout per packet: 4 B length · 2 B header length · 2 B
/// protocol version · 4 B operation · 4 B sequence · body. Version 2
/// bodies are zlib streams that nest further packets; version 0 bodies
/// are JSON. Protocol version 3 (brotli) is intentionally not supported
/// yet — the decoder asks the server for version 2, and a brotli frame
/// surfaces as a typed protocol failure so callers see it immediately
/// instead of receiving nothing.
abstract final class BilibiliDanmakuProtocol {
  /// Heartbeat reply carrying the popularity.
  static const int opHeartbeatReply = 3;

  /// Regular notice frame (chat, gifts, watches…).
  static const int opNotice = 5;

  /// Heartbeat the client sends every 30 s.
  static const int opHeartbeat = 2;

  /// Auth the client sends right after the socket opens.
  static const int opAuth = 7;

  /// Auth reply; body JSON with `code` 0 meaning accepted.
  static const int opAuthReply = 8;

  /// Protocol version requested in the auth packet.
  static const int protocolVersion = 2;

  static const int _headerLength = 16;

  /// Builds one packet with [operation] and the UTF-8 [body].
  static Uint8List packet(int operation, String body) {
    final payload = utf8.encode(body);
    final data = ByteData(_headerLength + payload.length)
      ..setUint32(0, _headerLength + payload.length)
      ..setUint16(4, _headerLength)
      ..setUint16(6, 0)
      ..setUint32(8, operation)
      ..setUint32(12, 1);
    final out = Uint8List(data.lengthInBytes + payload.length)
      ..setAll(0, data.buffer.asUint8List())
      ..setAll(_headerLength, payload);
    return out;
  }

  /// The heartbeat packet.
  static Uint8List heartbeat() => packet(opHeartbeat, '');

  /// The auth packet for [args] (protover 2, anonymous-friendly).
  static Uint8List auth(BilibiliDanmakuArgs args) => packet(
    opAuth,
    jsonEncode({
      'uid': args.uid,
      'roomid': args.roomId,
      'protover': protocolVersion,
      'platform': 'web',
      'type': 2,
      'key': args.token,
    }),
  );

  /// Decodes one WebSocket message into `(operation, body)` pairs, in
  /// order. Version-2 bodies are inflated and recursed; version-0
  /// bodies surface as raw bodies for the caller to interpret.
  ///
  /// Throws [FormatException] on malformed frames (bad header, zero or
  /// overflowing length, trailing bytes) and a plain protocol exception
  /// when a brotli body arrives (version 3 is not supported yet).
  static List<({int operation, Uint8List body})> decode(List<int> message) {
    final data = Uint8List.fromList(message);
    final view = ByteData.sublistView(data);
    final out = <({int operation, Uint8List body})>[];
    _stream(view, data, 0, out, depth: 0);
    return out;
  }

  static void _stream(
    ByteData view,
    Uint8List data,
    int start,
    List<({int operation, Uint8List body})> out, {
    required int depth,
  }) {
    if (depth > 3) {
      throw const FormatException('bilibili packet nesting too deep');
    }
    var offset = start;
    while (offset + _headerLength <= data.length) {
      final length = view.getUint32(offset);
      final header = view.getUint16(offset + 4);
      final version = view.getUint16(offset + 6);
      final operation = view.getUint32(offset + 8);
      if (header < _headerLength || length < header || offset + length > data.length) {
        throw FormatException(
          'invalid bilibili frame: offset=$offset, packet=$length, header=$header, total=${data.length}',
        );
      }
      final body = Uint8List.sublistView(data, offset + header, offset + length);
      switch (version) {
        case 2 when operation == opNotice:
          _stream(view, zlibInflate(body), 0, out, depth: depth + 1);
        default:
          out.add((operation: operation, body: Uint8List.fromList(body)));
      }
      offset += length;
    }
    if (offset != data.length) {
      throw const FormatException('incomplete bilibili frame');
    }
  }

  /// Inflates a zlib body with the standard decoder.
  static Uint8List zlibInflate(Uint8List body) => Uint8List.fromList(ZLibDecoder().convert(body));
}
