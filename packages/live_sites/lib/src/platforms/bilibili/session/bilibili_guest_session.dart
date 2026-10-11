import 'dart:async';

import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_models.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_parser.dart';
import 'package:live_sites/src/platforms/bilibili/session/bilibili_wbi.dart';

/// A guest Bilibili session: buvid cookies, cached WBI keys and signed
/// GET requests.
///
/// Login cookies arrive later (they ride in the same cookie header);
/// everything here already works anonymously — the nav endpoint hands
/// WBI keys to guests, and the finger endpoint issues the buvid pair.
final class BilibiliGuestSession {
  /// A session over [http]; [now] is injectable for key-expiry tests.
  new({required this.http, DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// The HTTP transport guest flows run over.
  final LiveHttp http;

  final DateTime Function() _now;

  static const Duration _keyLifetime = Duration(hours: 6);

  String? _buvid3;
  String? _buvid4;
  Future<void>? _buvidFetch;

  ({String imgKey, String subKey, DateTime at})? _keys;
  Future<String>? _mixinFetch;

  /// The cookie header sent with every request, growing as buvids land.
  String get cookie {
    final parts = <String>[];
    final buvid3 = _buvid3;
    if (buvid3 != null) {
      parts.add('buvid3=$buvid3');
    }
    final buvid4 = _buvid4;
    if (buvid4 != null) {
      parts.add('buvid4=$buvid4');
    }
    return parts.join(';');
  }

  /// Headers for a Bilibili request: media headers plus cookies.
  Map<String, String> headers() => {'accept': 'application/json', if (cookie.isNotEmpty) 'cookie': cookie};

  /// A GET against `api.live.bilibili.com[path]` with the session cookie.
  Future<Map<String, Object?>> get(String path, Map<String, String> query) =>
      _send(Uri.https(BilibiliConstants.apiHost, path, query));

  /// A GET against `api.bilibili.com[path]` (main-site endpoints such as
  /// nav, finger and search).
  Future<Map<String, Object?>> getMain(String path, Map<String, String> query) =>
      _send(Uri.https('api.bilibili.com', path, query));

  /// A GET whose envelope tolerates the anonymous `-101` code; see
  /// `BilibiliParser.anonymousChecked`.
  Future<Map<String, Object?>> _getMainAnonymous(String path) async {
    final response = await http.send(
      LiveRequest.get(Uri.https('api.bilibili.com', path), headers: headers(), site: SiteIds.bilibili),
    );
    return BilibiliParser.anonymousChecked(response.text, status: response.statusCode, what: path);
  }

  Future<Map<String, Object?>> _send(Uri url) async {
    final response = await http.send(LiveRequest.get(url, headers: headers(), site: SiteIds.bilibili));
    return BilibiliParser.checked(response.text, status: response.statusCode, what: url.path);
  }

  /// Ensures the buvid pair exists (finger endpoint, one in-flight fetch).
  Future<void> ensureBuvid() {
    if (_buvid3 != null && _buvid4 != null) {
      return Future.value();
    }
    return _buvidFetch ??= () async {
      try {
        final data = await getMain('/x/frontend/finger/spi', {});
        _buvid3 = data['b_3']?.toString();
        _buvid4 = data['b_4']?.toString();
      } finally {
        _buvidFetch = null;
      }
    }();
  }

  /// A valid mixin key: cached for 6 hours, refetched from nav otherwise.
  Future<String> mixinKey({bool renew = false}) {
    final cached = _keys;
    if (!renew && cached != null && _now().difference(cached.at) < _keyLifetime) {
      return Future.value(BilibiliWbi.mixinKey(cached.imgKey, cached.subKey));
    }
    return _mixinFetch ??= _fetchKeys().then((keys) => BilibiliWbi.mixinKey(keys.imgKey, keys.subKey));
  }

  Future<({String imgKey, String subKey})> _fetchKeys() async {
    try {
      await ensureBuvid();
      // The anonymous rule matters here: a guest gets `-101` with the keys,
      // and that is the normal, intended answer.
      final root = await _getMainAnonymous('/x/web-interface/nav');
      final keys = BilibiliWbi.keys(root);
      _keys = (imgKey: keys.imgKey, subKey: keys.subKey, at: _now());
      return keys;
    } finally {
      _mixinFetch = null;
    }
  }

  /// A signed GET: buvid ensured, WBI `w_rid`+`wts` appended to `query`.
  Future<Map<String, Object?>> getSigned(
    String host,
    String path,
    Map<String, String> query, {
    bool renewKeys = false,
  }) => _signed(host, path, query, renewKeys: renewKeys);

  Future<Map<String, Object?>> _signed(
    String host,
    String path,
    Map<String, String> query, {
    bool renewKeys = false,
  }) async {
    await ensureBuvid();
    final mixin = await mixinKey(renew: renewKeys);
    final signed = BilibiliWbi.sign(query, mixinKey: mixin, wts: _now().millisecondsSinceEpoch ~/ 1000);
    // The signed query must reach the server byte-for-byte; re-encoding
    // it through a query map would break the digest.
    final response = await _send(Uri.parse('https://$host$path?$signed'));
    return response;
  }
}
