// Module: lib/src/bili_wbi.dart
// Purpose: WBI request signing for the web api endpoints that require w_rid.
// Author: liuchuancong
// Created: 2026-10-09
//
// Provenance: the algorithm follows the v1-maintained bilibili line
// (origin/master lib/shared/platforms/bilibili/bilibili_site.dart), which is
// the standard public web recipe: keys from the nav endpoint's wbi_img, a
// fixed permutation table deriving the 32-char mixin key, and md5 over the
// sorted query plus wts. This is a fresh implementation against that
// knowledge, not a file merge (UPSTREAM_REVIEW_POLICY.md).

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pure_live_network/pure_live_network.dart';

/// The permutation web api uses to derive the mixin key from img+sub key.
const List<int> wbiMixinKeyEncTab = <int>[
  46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49, //
  33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40, 61,
  26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36,
  20, 34, 44, 52,
];

/// Fetches, caches and applies WBI signatures.
final class BiliWbiSigner {
  BiliWbiSigner({NetworkClient? client}) : _client = client ?? NetworkClient();

  final NetworkClient _client;
  String _imgKey = '';
  String _subKey = '';
  DateTime _fetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _pending;

  static const Duration _keyLifetime = Duration(hours: 6);

  /// Signs [parameters] for a wbi endpoint, returning the final query map
  /// including wts and w_rid. Characters web api strips are removed before
  /// signing, matching the server's own normalisation.
  Future<Map<String, String>> sign(Map<String, String> parameters) async {
    await _ensureKeys();
    final mixinKey = _mixinKey('$_imgKey$_subKey');
    final all = <String, String>{...parameters, 'wts': '${DateTime.now().millisecondsSinceEpoch ~/ 1000}'};
    final sorted = <String>[];
    for (final key in all.keys.toList()..sort()) {
      final value = all[key]!.split('').where((character) => !"'()*".contains(character)).join();
      sorted.add('$key=${Uri.encodeQueryComponent(value)}');
    }
    final wRid = md5.convert(utf8.encode('${sorted.join('&')}$mixinKey')).toString();
    return <String, String>{...all, 'w_rid': wRid};
  }

  String _mixinKey(String origin) {
    final buffer = StringBuffer();
    for (final index in wbiMixinKeyEncTab) {
      if (index < origin.length) {
        buffer.write(origin[index]);
      }
    }
    return buffer.toString().substring(0, 32);
  }

  Future<void> _ensureKeys() async {
    final age = DateTime.now().difference(_fetchedAt);
    if (_imgKey.isNotEmpty && _subKey.isNotEmpty && age < _keyLifetime) {
      return;
    }
    final pending = _pending;
    if (pending != null) {
      return pending;
    }
    late final Future<void> operation;
    operation = _fetchKeys().whenComplete(() {
      if (identical(_pending, operation)) {
        _pending = null;
      }
    });
    _pending = operation;
    return operation;
  }

  Future<void> _fetchKeys() async {
    final response = await _client.getJson(
      'https://api.bilibili.com/x/web-interface/nav',
      headers: <String, String>{'user-agent': _ua, 'referer': 'https://www.bilibili.com/'},
    );
    final wbi =
        ((response['data'] as Map<String, Object?>?)?['wbi_img'] ?? const <String, Object?>{}) as Map<String, Object?>;
    final imgUrl = '${wbi['img_url'] ?? ''}';
    final subUrl = '${wbi['sub_url'] ?? ''}';
    if (imgUrl.isEmpty || subUrl.isEmpty) {
      throw const FormatException('Bilibili nav answered without wbi_img keys');
    }
    _imgKey = imgUrl.substring(imgUrl.lastIndexOf('/') + 1).split('.').first;
    _subKey = subUrl.substring(subUrl.lastIndexOf('/') + 1).split('.').first;
    _fetchedAt = DateTime.now();
  }
}

/// The desktop UA the web api answers to.
const String biliUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/// A random buvid3 cookie value; the web api refuses search without one.
String randomBuvid3() {
  final random = DateTime.now().microsecondsSinceEpoch;
  return '${random.toRadixString(16).padLeft(8, '0')}-'
      '${(random >> 8).toRadixString(16).padLeft(4, '0')}-'
      '${(random >> 12).toRadixString(16).padLeft(4, '0')}-'
      '${(random >> 16).toRadixString(16).padLeft(4, '0')}-'
      '${(random >> 20).toRadixString(16).padLeft(12, '0')}'
      'infoc';
}

const String _ua = biliUserAgent;
