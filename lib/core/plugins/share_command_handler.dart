import 'dart:convert';
import 'package:pro_mpack/pro_mpack.dart';

class ShareCommandCodec {
  static const String _magic = 'pure_live';

  static String encodeShort(Map<String, dynamic> data) {
    try {
      final mpack = MessagePack();
      final d = data['d'] ?? data;
      final map = {
        'm': _magic,
        'p': d['platform'] ?? '',
        'r': d['roomId'] ?? '',
        'ti': d['title'] ?? '',
        'n': d['nick'] ?? '',
        'l': d['link'] ?? '',
        'c': d['cover'] ?? '',
        'a': d['avatar'] ?? '',
      };
      final bytes = mpack.pack(map);
      return base64.encode(bytes).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
    } catch (_) {
      return '';
    }
  }

  static Map<String, dynamic>? decodeShort(String code) {
    try {
      final mpack = MessagePack();
      code = code.replaceAll('-', '+').replaceAll('_', '/');
      code = code.padRight(code.length + (4 - code.length % 4) % 4, '=');
      final bytes = base64.decode(code);
      final unpacked = mpack.unpack<Map>(bytes);
      if (unpacked['m'] != _magic) return null;
      return {
        'platform': unpacked['p'] ?? '',
        'roomId': unpacked['r'] ?? '',
        'title': unpacked['ti'] ?? '',
        'nick': unpacked['n'] ?? '',
        'link': unpacked['l'] ?? '',
        'cover': unpacked['c'] ?? '',
        'avatar': unpacked['a'] ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  static bool isMyCommand(String text) {
    return decodeShort(text) != null;
  }
}
