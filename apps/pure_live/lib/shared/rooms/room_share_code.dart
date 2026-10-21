import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:live_sites/live_sites.dart' show LiveAnchor, LiveRoom, RoomContent, RoomLinks;

/// The room's share code (3.x `ShareCommandCodec.encodeShort`): a MessagePack
/// map `{m: pure_live, p, r, ti, n, l, c, a}` in URL-safe Base64 without
/// padding, which this app and the reference's link page both read.
///
/// The format is the contract, not this file's invention: the same bytes are
/// what the older client wrote, so a code copied from one app opens in the
/// other. Empty when the room has no platform or no room id — there is
/// nothing to point at.
String encodeRoomShareCode(LiveRoom room) {
  final platform = room.ref.platform;
  final roomId = room.ref.roomId;
  if (platform.trim().isEmpty || roomId.trim().isEmpty) {
    return '';
  }
  final anchor = room.anchor;
  final fields = <String, String>{
    'm': 'pure_live',
    'p': platform,
    'r': roomId,
    'ti': room.content.title,
    'n': anchor?.name ?? '',
    'l': room.links.webUrl ?? '',
    'c': room.content.coverUrl,
    'a': anchor?.avatarUrl ?? '',
  };
  final bytes = BytesBuilder(copy: false)..addByte(0x80 | fields.length);
  void string(String text) {
    final utf8Bytes = utf8.encode(text);
    final length = utf8Bytes.length;
    if (length < 32) {
      bytes.addByte(0xa0 | length);
    } else if (length < 0x100) {
      bytes
        ..addByte(0xd9)
        ..addByte(length);
    } else if (length < 0x10000) {
      bytes
        ..addByte(0xda)
        ..add([length >> 8, length & 0xff]);
    } else {
      bytes
        ..addByte(0xdb)
        ..add([length >> 24 & 0xff, length >> 16 & 0xff, length >> 8 & 0xff, length & 0xff]);
    }
    bytes.add(utf8Bytes);
  }

  for (final MapEntry(key: name, value: content) in fields.entries) {
    string(name);
    string(content);
  }
  return base64Url.encode(bytes.takeBytes()).replaceAll('=', '');
}

/// The room a share code names, or null.
///
/// Reads codes written by either app (the same format; the older decoder also
/// took standard Base64 with padding). Besides a text that is only the code, a
/// code inside other words is found too, so a message with a line of text
/// around it still works. A room needs a platform and a usable room id — `0`,
/// `null`, `undefined`, `nan` and `none` are not one.
LiveRoom? decodeRoomShareCode(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty || trimmed.length > _maxShareCodeText) {
    return null;
  }
  final whole = _decodeShareCode(trimmed);
  if (whole != null) {
    return whole;
  }
  for (final match in _shareCodeCandidates.allMatches(trimmed)) {
    final room = _decodeShareCode(match.group(0)!);
    if (room != null) {
      return room;
    }
  }
  return null;
}

const int _maxShareCodeText = 8192;
final RegExp _shareCodeCandidates = RegExp('[A-Za-z0-9_+/-]{24,}={0,2}');
const Set<String> _unusableRoomIds = {'0', 'null', 'undefined', 'nan', 'none'};

LiveRoom? _decodeShareCode(String code) {
  try {
    final bytes = base64Url.decode(base64Url.normalize(code));
    final reader = _MessagePackReader(bytes);
    final map = reader.read();
    if (map is! Map<String, Object?> || !reader.done || map['m'] != 'pure_live') {
      return null;
    }
    String field(String key) => '${map[key] ?? ''}'.trim();
    final platform = field('p');
    final roomId = field('r');
    if (platform.isEmpty || roomId.isEmpty || _unusableRoomIds.contains(roomId.toLowerCase())) {
      return null;
    }
    final link = field('l');
    final name = field('n');
    final avatar = field('a');
    return LiveRoom.normalized(
      platform: platform,
      roomId: roomId,
      content: RoomContent(title: field('ti'), coverUrl: field('c')),
      anchor: name.isEmpty && avatar.isEmpty
          ? null
          : LiveAnchor.normalized(platform: platform, name: name, avatarUrl: avatar.isEmpty ? null : avatar),
      links: RoomLinks(webUrl: link),
    );
  } on FormatException {
    return null;
  }
}

/// The part of MessagePack a share code holds: maps, strings, and (for codes
/// written by other encoders) nil, booleans, integers and floats. Anything
/// else, a truncated value, or a map nested deeper than [maxDepth] throws
/// [FormatException] — which the reader above turns into "not a code".
final class _MessagePackReader {
  new(this._bytes);

  static const int maxDepth = 4;

  final Uint8List _bytes;
  late final ByteData _data = ByteData.sublistView(_bytes);
  int _offset = 0;

  bool get done => _offset == _bytes.length;

  /// The offset of the next [length] bytes, which are then consumed.
  int _take(int length) {
    if (_offset + length > _bytes.length) {
      throw const FormatException('Truncated MessagePack value');
    }
    final start = _offset;
    _offset += length;
    return start;
  }

  int _uint(int length) {
    final start = _take(length);
    var value = 0;
    for (var i = start; i < start + length; i++) {
      value = value << 8 | _bytes[i];
    }
    return value;
  }

  String _string(int length) {
    final start = _take(length);
    return utf8.decode(Uint8List.sublistView(_bytes, start, start + length));
  }

  Map<String, Object?> _map(int length, int depth) {
    if (depth >= maxDepth) {
      throw const FormatException('MessagePack nested too deep');
    }
    return {for (var i = 0; i < length; i++) '${read(depth + 1)}': read(depth + 1)};
  }

  Object? read([int depth = 0]) {
    final type = _bytes[_take(1)];
    if (type <= 0x7f) return type;
    if (type >= 0xe0) return type - 0x100;
    if (type >= 0xa0 && type <= 0xbf) return _string(type & 0x1f);
    if (type >= 0x80 && type <= 0x8f) return _map(type & 0x0f, depth);
    return switch (type) {
      0xc0 => null,
      0xc2 => false,
      0xc3 => true,
      0xcc || 0xcd || 0xce || 0xcf => _uint(1 << (type - 0xcc)),
      0xd0 => _data.getInt8(_take(1)),
      0xd1 => _data.getInt16(_take(2)),
      0xd2 => _data.getInt32(_take(4)),
      0xd3 => _data.getInt64(_take(8)),
      0xca => _data.getFloat32(_take(4)),
      0xcb => _data.getFloat64(_take(8)),
      0xd9 || 0xda || 0xdb => _string(_uint(1 << (type - 0xd9))),
      0xde => _map(_uint(2), depth),
      0xdf => _map(_uint(4), depth),
      _ => throw FormatException('Unexpected MessagePack type $type'),
    };
  }
}

/// The texts this app put on the clipboard (share codes, room links), so the
/// clipboard check never offers them back — the reference's
/// `ShareCommandHandler._rememberText`. Kept for this run, at most [limit].
abstract final class OwnClipboardTexts {
  /// How many texts are kept.
  static const int limit = 64;

  static final LinkedHashSet<String> _texts = LinkedHashSet();

  /// Remembers [text].
  static void remember(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _texts
      ..remove(trimmed)
      ..add(trimmed);
    while (_texts.length > limit) {
      _texts.remove(_texts.first);
    }
  }

  /// Whether this app wrote [text].
  static bool contains(String text) => _texts.contains(text.trim());

  /// Forgets everything (tests).
  static void clear() => _texts.clear();
}
