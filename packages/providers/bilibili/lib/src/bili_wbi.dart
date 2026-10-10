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
//
// The recipe's exactness is the whole value of this file, so the two steps are pure functions
// ([wbiMixinKey] and [wbiSignedQuery]) that a test can hold against a fixed vector - the signer around them
// only owns the network and the cache.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

/// The permutation web api uses to derive the mixin key from img+sub key.
const List<int> wbiMixinKeyEncTab = <int>[
  46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49, //
  33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40, 61,
  26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36,
  20, 34, 44, 52,
];

/// The mixin key is always this long; a shorter source key means nav answered something unexpected.
const int kWbiMixinKeyLength = 32;

/// The characters the web api removes from query values before hashing.
const String kWbiStrippedCharacters = "'()*";

/// The img_key + sub_key permutation, as the web client computes it.
///
/// Throws when [origin] is shorter than the 32 characters the table promises: taking a substring of whatever
/// arrived would sign with a truncated key, and every request would then fail with a risk-control code that
/// names neither the key nor this function.
String wbiMixinKey(String origin) {
  final buffer = StringBuffer();
  for (final index in wbiMixinKeyEncTab) {
    if (index < origin.length) {
      buffer.write(origin[index]);
    }
  }
  final permuted = buffer.toString();
  if (permuted.length < kWbiMixinKeyLength) {
    throw FormatException(
      'the wbi source key is too short to permute into a $kWbiMixinKeyLength-character mixin key',
      origin,
      permuted.length,
    );
  }
  return permuted.substring(0, kWbiMixinKeyLength);
}

/// The query string a wbi endpoint expects, signature included.
///
/// Built as a string on purpose. Handing back a map leaves the caller to encode the values a second time, and
/// then the bytes on the wire are not the bytes that were hashed - which is exactly how the earlier version of
/// this file failed: it signed with `Uri.encodeQueryComponent` (space to `+`, `!~*'()` escaped) while dio put
/// `%20` in the url, so any keyword containing a space was rejected as a bad signature. `Uri.encodeComponent`
/// is the Dart spelling of the JavaScript `encodeURIComponent` the server's own client uses.
String wbiSignedQuery(Map<String, String> parameters, {required String mixinKey, required DateTime at}) {
  final wts = at.millisecondsSinceEpoch ~/ 1000;
  final all = <String, String>{...parameters, 'wts': '$wts'};
  final parts = <String>[];
  for (final key in all.keys.toList()..sort()) {
    final value = all[key]!.split('').where((character) => !kWbiStrippedCharacters.contains(character)).join();
    parts.add('${Uri.encodeComponent(key)}=${Uri.encodeComponent(value)}');
  }
  final signed = parts.join('&');
  final wRid = md5.convert(utf8.encode('$signed$mixinKey')).toString();
  return '$signed&w_rid=$wRid';
}

/// Fetches, caches and applies WBI signatures.
final class BiliWbiSigner {
  BiliWbiSigner({
    NetworkClient? client,
    Clock? clock,
    this.keyLifetime = const Duration(hours: 6),
    this.failureBackoff = const Duration(minutes: 2),
  }) : _client = client ?? NetworkClient(),
       _clock = clock ?? systemClock;

  final NetworkClient _client;
  final Clock _clock;

  /// How long one nav answer is reused. The web client re-reads the keys per session; the site rotates the
  /// images on deploys, so a cache that never expires pins every request to a key the server stopped using.
  final Duration keyLifetime;

  /// How long to sit on a failed fetch before trying again.
  ///
  /// Without it a nav outage turned every single signed request into a fresh nav request plus its own timeout,
  /// which is how an outage becomes a retry storm against the endpoint that is already down.
  final Duration failureBackoff;

  String _mixinKey = '';
  DateTime _usableAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _refusedUntil = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _pending;

  /// The signed query string for [parameters], fetching the keys on first use.
  Future<String> signedQuery(Map<String, String> parameters) async {
    await _ensureKeys();
    return wbiSignedQuery(parameters, mixinKey: _mixinKey, at: _clock());
  }

  Future<void> _ensureKeys() async {
    final now = _clock();
    if (_mixinKey.isNotEmpty && now.isBefore(_usableAt)) {
      return;
    }
    if (now.isBefore(_refusedUntil)) {
      throw StateError(
        'the wbi keys could not be fetched before $now; retrying after ${_refusedUntil.toIso8601String()}',
      );
    }
    final pending = _pending;
    if (pending != null) {
      return pending;
    }
    late final Future<void> operation;
    operation = _fetchKeys()
        .catchError((Object error) {
          _refusedUntil = _clock().add(failureBackoff);
          throw error;
        })
        .whenComplete(() {
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
      headers: <String, String>{'user-agent': biliUserAgent, 'referer': 'https://www.bilibili.com/'},
    );
    final data = response['data'];
    final wbi = data is Map ? data['wbi_img'] : null;
    if (wbi is! Map) {
      throw const FormatException('Bilibili nav answered without wbi_img keys');
    }
    final imgKey = _keyFromUrl('${wbi['img_url'] ?? ''}');
    final subKey = _keyFromUrl('${wbi['sub_url'] ?? ''}');
    if (imgKey.isEmpty || subKey.isEmpty) {
      throw const FormatException('Bilibili nav answered wbi_img urls with no key in them');
    }
    // Permute eagerly: a nav answer that cannot produce a 32-character key must fail here, with the reason,
    // rather than at the substring inside a later signature.
    _mixinKey = wbiMixinKey('$imgKey$subKey');
    _usableAt = _clock().add(keyLifetime);
  }

  /// The file stem of a key url: `.../1e6c1...png` is the key, the extension is not part of it.
  static String _keyFromUrl(String url) {
    final last = url.substring(url.lastIndexOf('/') + 1);
    final dot = last.indexOf('.');
    return dot < 0 ? last : last.substring(0, dot);
  }
}

/// The desktop UA the web api answers to.
const String biliUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/// A fresh buvid3 cookie value; the web api refuses search without one.
///
/// Shaped like the real one (`8-4-4-4-12` hex plus the `infoc` suffix) and drawn from a **cryptographic**
/// random source. The first version derived every segment from `microsecondsSinceEpoch`, which produced a
/// sixteen-character first field (so not a buvid3 the site would have issued) and one value per microsecond -
/// reproducible by anyone who knows roughly when the app started.
String randomBuvid3([Random? random]) {
  final source = random ?? Random.secure();
  String hex(int length) => List<String>.generate(length, (_) => source.nextInt(16).toRadixString(16)).join();
  return '${hex(8)}-${hex(4)}-${hex(4)}-${hex(4)}-${hex(12)}infoc';
}
