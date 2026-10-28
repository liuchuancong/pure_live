// Dart port of hongguoTV's CommentSignature + CommentTransport +
// AppCommentPages + TimedComments (kotlin-tv/core); GPL-3.0-only.
// Anonymous, read-only comment and danmaku lists: the shared transport
// signs each read with the comment protocol's own argus/gorgon/ladon, and
// never carries account credentials.
import 'dart:convert' show base64Encode, jsonDecode, jsonEncode, utf8;
import 'dart:math' as math;
import 'dart:typed_data' show ByteData, Endian, Uint8List;
import 'dart:typed_data' show BytesBuilder;

import 'package:crypto/crypto.dart' as crypto;
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest;
import 'package:pointycastle/export.dart'
    show AESEngine, CBCBlockCipher, KeyParameter, ParametersWithIV, SM3Digest;

const String _kCommentHost = 'https://api5-normal-sinfonlineb.fqnovel.com';
const String _kVideoUa =
    'com.phoenix.read/73532 (Linux; U; Android 16; zh_CN; 25053RT47C; Build/BP2A.250605.031.A3; Cronet/TTNetVersion:04657795 2026-01-23 QuicVersion:c67e9834 2025-09-08)';

Uint8List _md5(List<int> data) => Uint8List.fromList(crypto.md5.convert(data).bytes);

Uint8List _hex(String value) => Uint8List.fromList([
  for (var i = 0; i < value.length; i += 2) int.parse(value.substring(i, i + 2), radix: 16),
]);

String _hexOf(List<int> bytes) => bytes.map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0')).join();

Uint8List _le64(int n) {
  final data = ByteData(8)..setInt64(0, n, Endian.little);
  return data.buffer.asUint8List();
}

int _word(List<int> data, int at) => ByteData.sublistView(Uint8List.fromList(data)).getInt64(at, Endian.little);

Uint8List _pad16(List<int> data) {
  final padding = 16 - data.length % 16;
  return Uint8List.fromList([...data, ...List<int>.filled(padding, padding)]);
}

Uint8List _sm3(List<int> data) {
  final digest = SM3Digest()
    ..update(Uint8List.fromList(data), 0, data.length);
  final out = Uint8List(digest.digestSize);
  digest.doFinal(out, 0);
  return out;
}

int _rotl64(int v, int n) => ((v << n) | (v >>> (64 - n))) & 0xFFFFFFFFFFFFFFFF;

int _rotr64(int v, int n) => ((v >>> n) | (v << (64 - n))) & 0xFFFFFFFFFFFFFFFF;

/// The comment protocol's headers: gorgon over the query, khronos, the
/// request ticket, an empty stub, argus and ladon.
Map<String, String> _commentHeaders(String query, {int? now, Uint8List? nonce}) {
  final time = now ?? DateTime.now().millisecondsSinceEpoch;
  final ts = time ~/ 1000;
  final salt =
      nonce ??
          Uint8List.fromList([for (var i = 0; i < 11; i++) math.Random.secure().nextInt(256)]);
  final first = ((salt[0] & 0xFF) % 7 + 1) << 5;
  final second = 0xE0 | (salt[1] & 0x0F);
  final input = Uint8List.fromList([
    ..._md5(utf8.encode(query)).sublist(0, 4),
    ...List<int>.filled(8, 0),
    ..._hex('00010704'),
    ..._be32(ts),
  ]);
  final key = [0x4A, 0x00, 0x16, second, 0x47, 0x6C, 0x00, first];
  final box = List<int>.generate(256, (i) => i);
  var j = 0;
  for (var i = 0; i <= 255; i++) {
    j = (j + box[i] + key[i % 8]) & 255;
    box[i] = box[j];
  }
  j = 0;
  for (var n = 0; n < input.length; n++) {
    final i = n + 1;
    j = (j + box[i]) & 255;
    box[i] = box[j];
    input[n] = input[n] ^ box[(box[i] + box[j]) & 255];
  }
  for (var i = 0; i < input.length; i++) {
    final v = input[i] & 0xFF;
    final swapped = ((v << 4) | (v >>> 4)) & 0xFF;
    var reversed = 0;
    var bits = swapped ^ (input[(i + 1) % input.length] & 0xFF);
    for (var b = 0; b < 8; b++) {
      reversed = (reversed << 1) | (bits & 1);
      bits >>>= 1;
    }
    input[i] = ((reversed >>> 24) ^ 0xEB) & 0xFF;
  }
  return {
    'X-Gorgon': _hexOf([0x84, 0x04, first, second, 0x00, 0x00, ...input]),
    'X-Khronos': '$ts',
    'X-SS-Req-Ticket': '$time',
    'X-SS-STUB': '',
    'X-Argus': _argus(query, ts, salt),
    'X-Ladon': _ladon(ts, salt.sublist(2, 6)),
  };
}

Uint8List _be32(int n) {
  final data = ByteData(4)..setUint32(0, n & 0xFFFFFFFF);
  return data.buffer.asUint8List();
}

String _ladon(int ts, Uint8List salt) {
  final ascii = utf8.encode(_hexOf(_md5([...salt, ...utf8.encode('8662')])));
  final queue = <int>[_word(ascii, 16), _word(ascii, 24)];
  var left = _word(ascii, 0);
  var right = _word(ascii, 8);
  final keys = List<int>.filled(34, 0);
  for (var i = 0; i < 34; i++) {
    keys[i] = left;
    final next = ((_rotr64(right, 8) + left) ^ i) & 0xFFFFFFFFFFFFFFFF;
    queue.add(next);
    left = next ^ _rotl64(left, 3);
    right = queue.removeAt(0);
  }
  final data = _pad16(utf8.encode('$ts-1611921764-3019'));
  final result = BytesBuilder()..add(salt);
  for (var at = 0; at < data.length; at += 16) {
    var a = _word(data, at);
    var b = _word(data, at + 8);
    for (final k in keys) {
      b = (k ^ (a + _rotr64(b, 8))) & 0xFFFFFFFFFFFFFFFF;
      a = (b ^ _rotl64(a, 3)) & 0xFFFFFFFFFFFFFFFF;
    }
    result
      ..add(_le64(a))
      ..add(_le64(b));
  }
  return base64Encode(result.toBytes());
}

String _argus(String query, int ts, Uint8List salt) {
  final random = ByteData.sublistView(salt, 6, 10).getUint32(0, Endian.little);
  Uint8List proto(List<List<Object?>> fields) {
    final out = BytesBuilder();
    Uint8List varintOf(int value) {
      var n = value;
      final bytes = <int>[];
      while (n >>> 7 != 0) {
        bytes.add((n & 127) | 128);
        n >>>= 7;
      }
      bytes.add(n & 0xFF);
      return Uint8List.fromList(bytes);
    }

    for (final field in fields) {
      final tag = field[0]! as int;
      final value = field[1];
      if (value is num) {
        out
          ..add(varintOf(tag << 3))
          ..add(varintOf(value.toInt()));
      } else {
        final bytes = value is Uint8List ? value : Uint8List.fromList(utf8.encode(value.toString()));
        out
          ..add(varintOf((tag << 3) | 2))
          ..add(varintOf(bytes.length))
          ..add(bytes);
      }
    }
    return out.toBytes();
  }

  final nested = proto([
    [1, 2 + (salt[10] & 0xFF) % 49 * 2],
    [2, 1388734],
    [3, 1388734],
    [4, 1388734],
  ]);
  final message = proto([
    [1, 0x40401252],
    [2, 2],
    [3, random],
    [4, '3019'],
    [6, '1611921764'],
    [7, '6.8.1.32'],
    [8, 'v04.07.01-ml-android'],
    [9, 135135744],
    [10, Uint8List(8)],
    [12, (ts * 2) & 0xFFFFFFFF],
    [13, _sm3(Uint8List(16)).sublist(0, 6)],
    [14, _sm3(utf8.encode(query)).sublist(0, 6)],
    [15, nested],
    [20, 'none'],
    [21, 738],
  ]);
  final secret = _hex('ac1adaae95a7af94a5114ab3b3a97dd80050aa0a39314c40528caec95256c28c');
  final derived = _sm3([...secret, ..._hex('3ccc567b'), ...secret]);
  final keys = List<int>.filled(72, 0);
  for (var i = 0; i <= 3; i++) {
    keys[i] = _word(derived, i * 8);
  }
  for (var i = 4; i <= 71; i++) {
    final x = _rotr64(keys[i - 1], 3) ^ keys[i - 3];
    keys[i] =
        ((~keys[i - 4]) & 0xFFFFFFFFFFFFFFFF) ^
        x ^
        _rotr64(x, 1) ^
        // The key schedule's 64-bit odd constant; exactness does not
        // survive JS, but this app never compiles to it.
        // ignore: avoid_js_rounded_ints
        ((0x3DC94C3A046D678B >>> ((i - 4) % 62)) & 1) ^
        3;
    keys[i] &= 0xFFFFFFFFFFFFFFFF;
  }
  final blocks = _pad16(message);
  final encrypted = BytesBuilder();
  for (var at = 0; at < blocks.length; at += 16) {
    var a = _word(blocks, at);
    var b = _word(blocks, at + 8);
    for (final k in keys) {
      final next =
          (a ^
              ((_rotl64(b, 1) & _rotl64(b, 8)) & 0xFFFFFFFFFFFFFFFF) ^
              _rotl64(b, 2) ^
              k) &
          0xFFFFFFFFFFFFFFFF;
      a = b;
      b = next;
    }
    encrypted
      ..add(_le64(a))
      ..add(_le64(b));
  }
  const mask = 'd04ffdffd04ffdff';
  final maskBytes = _hex(mask);
  final cipherBytes = encrypted.toBytes();
  final scrambled = Uint8List.fromList([
    for (var i = 0; i < cipherBytes.length; i++) cipherBytes[i] ^ maskBytes[i % 8],
  ]);
  final container = _concat([
    _hex('a6e783ee7001100918'),
    _concat([maskBytes, scrambled]).reversed.toList(),
    _hex('567b'),
  ]);
  final cipher = CBCBlockCipher(AESEngine())
    ..init(true, ParametersWithIV(KeyParameter(_md5(secret.sublist(0, 16))), _md5(secret.sublist(16, 32))));
  // PKCS7 by hand: the container is padded to a block, then one whole
  // padding block when it already aligns.
  final padded = _padPkcs7(Uint8List.fromList(container));
  final out = Uint8List(padded.length);
  for (var at = 0; at < padded.length; at += 16) {
    cipher.processBlock(padded, at, out, at);
  }
  return base64Encode(_concat([_hex('3ccc'), out]));
}

Uint8List _padPkcs7(Uint8List data) {
  final padding = 16 - data.length % 16;
  return Uint8List.fromList([...data, ...List<int>.filled(padding, padding)]);
}

Uint8List _concat(List<List<int>> parts) {
  final out = Uint8List(parts.fold(0, (total, part) => total + part.length));
  var at = 0;
  for (final part in parts) {
    out.setRange(at, at + part.length, part);
    at += part.length;
  }
  return out;
}

/// One episode comment.
final class HongguoComment {
  /// Creates the comment.
  const HongguoComment({required this.id, required this.author, required this.avatar, required this.content, required this.created, required this.likes});

  final String id;
  final String author;
  final String avatar;
  final String content;
  final int created;
  final int likes;
}

/// One page of episode comments with the cursor the next page asks.
final class HongguoCommentPage {
  /// Creates the page.
  const HongguoCommentPage({required this.total, required this.items, required this.nextCursor, required this.hasMore});

  final int total;
  final List<HongguoComment> items;
  final String nextCursor;
  final bool hasMore;
}

/// One timed-comment (danmaku) window.
final class HongguoDanmakuWindow {
  /// Creates the window.
  const HongguoDanmakuWindow({required this.startMs, required this.nextMs, required this.items});

  /// The window's first millisecond.
  final int startMs;

  /// The next window's first millisecond.
  final int nextMs;

  /// The window's items, time-ordered: `(timeMs, text)`.
  final List<(int, String)> items;
}

/// The comment protocol's transport: one shared device fingerprint, one
/// signature per read, anonymous.
final class HongguoCommentClient {
  /// Creates the client over [_http].
  HongguoCommentClient({required this._http});

  final LiveHttp _http;

  Future<Map<String, Object?>> _read(
    String episode,
    Map<String, Object?> payload, {
    required int source,
    required int channel,
  }) async {
    final query = {
      'aid': '8662',
      'app_name': 'novelread',
      'version_code': '73532',
      'version_name': '7.3.5.32',
      'manifest_version_code': '73532',
      'update_version_code': '73532',
      'channel': 'update_64',
      'device_platform': 'android',
      'os': 'android',
      'ssmix': 'a',
      'device_type': '25053RT47C',
      'device_brand': 'Redmi',
      'language': 'zh',
      'os_api': '36',
      'os_version': '16',
      'resolution': '1280*2772',
      'dpi': '520',
      'ac': 'wifi',
      'device_id': '7397450988462912345',
      'iid': '7397450988462912346',
      '_rticket': '${DateTime.now().millisecondsSinceEpoch}',
    };
    final encoded = (query.keys.toList()..sort()).map((key) => '$key=${Uri.encodeQueryComponent(query[key]!)}').join('&');
    final response = await _http.send(
      LiveRequest.custom(
        method: 'POST',
        url: Uri.parse('$_kCommentHost/novel/commentapi/comment/list/$episode/v1/?$encoded'),
        bodyBytes: Uint8List.fromList(utf8.encode(jsonEncode(payload))),
        contentType: 'application/json; charset=utf-8',
        headers: {
          'User-Agent': _kVideoUa,
          'Accept': 'application/json',
          'X-XS-From-Web': '0',
          'Sdk-Version': '2',
          'Comment-Source': '$source',
          'Server-Channel': '$channel',
          ..._commentHeaders(encoded),
        },
        timeout: const Duration(seconds: 20),
      ),
    );
    if (!response.isOk) {
      throw HongguoCommentFailure('评论读取失败（HTTP ${response.statusCode}）');
    }
    final decoded = jsonDecode(response.text);
    if (decoded is! Map<String, Object?>) {
      throw const HongguoCommentFailure('评论响应格式异常');
    }
    return decoded;
  }

  /// One page of an episode's comments; an empty [cursor] starts the list.
  Future<HongguoCommentPage> comments(String seriesId, String episodeVid, String cursor) async {
    if (!RegExp(r'^[0-9]{6,30}$').hasMatch(seriesId) || !RegExp(r'^[0-9]{6,30}$').hasMatch(episodeVid)) {
      throw const HongguoCommentFailure('剧集编号无效');
    }
    if (cursor.length > 8192) {
      throw const HongguoCommentFailure('评论游标无效');
    }
    final result = await _read(episodeVid, {
      'comment_source': 4,
      'server_channel': 18,
      'group_id': episodeVid,
      'group_type': 30,
      'comment_type': 4,
      'sort': 1,
      'need_count': true,
      'count': 20,
      'cursor': cursor,
      'aid': 8662,
      'compliance_status': 0,
      'business_param': {'book_id': seriesId, 'req_type': 0},
    }, source: 4, channel: 18);
    final code = result['code'];
    if (code is! num || code.toInt() != 0) {
      throw const HongguoCommentFailure('评论接口未返回成功数据');
    }
    final data = result['data'];
    if (data is! Map<String, Object?>) {
      throw const HongguoCommentFailure('评论数据缺失');
    }
    final info = data['common_list_info'];
    if (info is! Map<String, Object?>) {
      throw const HongguoCommentFailure('评论列表信息缺失');
    }
    final more = info['has_more'] == true;
    final next = info['cursor'] is String ? info['cursor']! as String : '';
    final rows = data['data_list'];
    final items = <HongguoComment>[];
    final seen = <String>{};
    if (rows is List<Object?>) {
      for (final row in rows.take(100)) {
        if (row is! Map<String, Object?>) continue;
        final comment = row['comment'];
        if (comment is! Map<String, Object?>) continue;
        final common = comment['common'];
        final expand = comment['expand'];
        if (common is! Map<String, Object?> || expand is! Map<String, Object?>) continue;
        if (_str(common, 'group_id') != episodeVid || (common['status'] is num ? (common['status']! as num).toInt() : -1) != 1) {
          continue;
        }
        final id = _str(row, 'comment_id');
        final content = _text(common);
        if (id.isEmpty || id.length > 120 || content.isEmpty || !seen.add(id)) continue;
        final user = common['user_info'] is Map<String, Object?> ? (common['user_info']! as Map<String, Object?>)['base_info'] : null;
        final avatar = user is Map<String, Object?> && _str(user, 'user_avatar').startsWith('https://')
            ? _str(user, 'user_avatar')
            : '';
        final stat = row['stat'];
        items.add(HongguoComment(
          id: id,
          author: user is Map<String, Object?> ? _str(user, 'user_name') : '',
          avatar: avatar,
          content: content,
          created: (common['create_timestamp'] as num?)?.toInt() ?? 0,
          likes: stat is Map<String, Object?> ? (stat['digg_count'] as num?)?.toInt() ?? 0 : 0,
        ));
      }
    }
    return HongguoCommentPage(
      total: (info['total'] as num?)?.toInt() ?? 0,
      items: items,
      nextCursor: more ? next : '',
      hasMore: more,
    );
  }

  /// One window of the episode's timed comments after [startMs].
  Future<HongguoDanmakuWindow> danmaku(String seriesId, String episodeVid, int startMs, int durationMs) async {
    if (!RegExp(r'^[0-9]{6,30}$').hasMatch(seriesId) || !RegExp(r'^[0-9]{6,30}$').hasMatch(episodeVid)) {
      throw const HongguoCommentFailure('剧集编号无效');
    }
    if (startMs < 0 || durationMs <= startMs || durationMs > 86400000) {
      throw const HongguoCommentFailure('弹幕时间段无效');
    }
    final result = await _read(episodeVid, {
      'comment_source': 601,
      'server_channel': 1000,
      'group_id': episodeVid,
      'group_type': 30,
      'comment_type': 20,
      'sort': 1,
      'count': 90,
      'cursor': '',
      'aid': 8662,
      'compliance_status': 0,
      'business_param': {
        'book_id': seriesId,
        'start_offset_time': startMs,
        'playlet_item_duration': durationMs,
        'need_danmaku_guide_type': [1, 3, 4, 2],
      },
    }, source: 601, channel: 1000);
    final code = result['code'];
    if (code is! num || code.toInt() != 0) {
      throw const HongguoCommentFailure('弹幕接口未返回成功数据');
    }
    final data = result['data'];
    if (data is! Map<String, Object?>) {
      throw const HongguoCommentFailure('弹幕数据缺失');
    }
    final extra = data['extra'];
    final nextRaw = extra is Map<String, Object?> ? (extra['next_query_danmaku_list_time'] as num?)?.toInt() ?? 0 : 0;
    if (nextRaw <= startMs || nextRaw > 86400000) {
      throw const HongguoCommentFailure('弹幕时间段无效');
    }
    final end = nextRaw < durationMs ? nextRaw : durationMs;
    final rows = data['data_list'];
    final items = <(int, String)>[];
    final seen = <String>{};
    if (rows is List<Object?>) {
      for (final row in rows.take(300)) {
        if (row is! Map<String, Object?>) continue;
        final comment = row['comment'];
        if (comment is! Map<String, Object?>) continue;
        final common = comment['common'];
        final expand = comment['expand'];
        if (common is! Map<String, Object?> || expand is! Map<String, Object?>) continue;
        if (_str(common, 'group_id') != episodeVid || (common['status'] is num ? (common['status']! as num).toInt() : -1) != 1) {
          continue;
        }
        final time = (expand['offset_time'] as num?)?.toInt() ?? -1;
        if (time < startMs || time >= end) continue;
        final id = _str(comment, 'comment_id');
        final text = _text(common);
        if (id.isEmpty || text.isEmpty || !seen.add(id)) continue;
        items.add((time, text));
        if (items.length >= 90) break;
      }
    }
    items.sort((a, b) => a.$1.compareTo(b.$1));
    return HongguoDanmakuWindow(startMs: startMs, nextMs: end, items: items);
  }
}

/// The comment layer's failure, safe to show as sent.
final class HongguoCommentFailure implements Exception {
  /// Creates the failure.
  const HongguoCommentFailure(this.message);

  /// One line on what went wrong.
  final String message;

  @override
  String toString() => message;
}

String _str(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value.trim();
  if (value is num) return value.toInt() == value ? value.toInt().toString() : value.toString();
  return '';
}

String _text(Map<String, Object?> common) {
  final content = common['content'];
  if (content is! Map<String, Object?>) return '';
  final text = content['text'];
  if (text is! String) return '';
  return text.replaceAll(RegExp(r'[\x00-\x1F\x7F\u2028\u2029]'), ' ').trim();
}
