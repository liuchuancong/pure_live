import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_json.dart';

/// Bilibili's WBI request signature (`w_rid`), used by `getInfoByRoom`,
/// `getDanmuInfo` and the signed `second/getList`.
///
/// The keys come from `x/web-interface/nav`'s `data.wbi_img` file names; the
/// mixin key permutes their concatenation through the table below and keeps
/// the first 32 characters. The signed query is the parameters plus `wts`
/// (Unix seconds), sorted by key, each value stripped of `!'()*` and
/// percent-encoded like `encodeURIComponent`; `w_rid` is the MD5 of that
/// query and the mixin key.
abstract final class BilibiliWbi {
  /// The fixed permutation of the 64 key characters (bilibili's web client
  /// constant, transcribed verbatim from the reference implementation).
  static const List<int> mixinTable = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, //
    38, 41, 13, 37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62,
    11, 36, 20, 34, 44, 52,
  ];

  static final RegExp _unsafe = RegExp("[!'()*]");

  /// The mixin key: [imgKey] + [subKey] permuted by [mixinTable], the first 32
  /// characters. A key pair shorter than 64 characters means the nav answer
  /// changed shape.
  static String mixinKey(String imgKey, String subKey) {
    final origin = '$imgKey$subKey';
    if (origin.length < 64) {
      throw BilibiliFailure(BilibiliFailureKind.apiChanged, 'WBI keys too short (${origin.length} characters)');
    }
    return [for (final index in mixinTable) origin[index]].join().substring(0, 32);
  }

  /// The query WBI signs: [params] plus `wts`, sorted by key, values without
  /// `!'()*`, percent-encoded the JavaScript way.
  static String query(Map<String, String> params, {required int wts}) {
    final all = {...params, 'wts': '$wts'};
    final keys = all.keys.toList()..sort();
    return [
      for (final key in keys) '${Uri.encodeComponent(key)}=${Uri.encodeComponent(all[key]!.replaceAll(_unsafe, ''))}',
    ].join('&');
  }

  /// The whole signed query of [params]: [query] plus `&w_rid=` and the MD5 of
  /// that query with the mixin key.
  static String sign(Map<String, String> params, {required String imgKey, required String subKey, required int wts}) {
    final unsigned = query(params, wts: wts);
    return '$unsigned&w_rid=${md5.convert(utf8.encode('$unsigned${mixinKey(imgKey, subKey)}'))}';
  }

  /// The WBI keys of a `x/web-interface/nav` answer, as the file names of
  /// `data.wbi_img.img_url` and `sub_url`; null when the answer carries
  /// neither. A guest gets code `-101` **with** the keys present, so the
  /// caller reads them before it reads the envelope, and only reports the
  /// envelope's failure when the keys are missing.
  static ({String imgKey, String subKey})? tryNavKeys(String body) {
    String? key(Object? url) {
      final text = jsonString(url);
      if (text == null) return null;
      final name = text.substring(text.lastIndexOf('/') + 1).split('.').first;
      return name.isEmpty ? null : name;
    }

    final image = jsonObject(jsonObject(jsonObject(decodeJson(body))?['data'])?['wbi_img']);
    final imgKey = key(image?['img_url']);
    final subKey = key(image?['sub_url']);
    return imgKey == null || subKey == null ? null : (imgKey: imgKey, subKey: subKey);
  }

  /// `w_webid`: `"access_id":"…"` in the `live.bilibili.com/lol` page,
  /// backslashes removed; needed only by the signed `second/getList`.
  static String accessId(String html) {
    final id = RegExp('"access_id":"(.*?)"').firstMatch(html)?.group(1)?.replaceAll(r'\', '');
    if (id == null || id.isEmpty) {
      throw const BilibiliFailure(BilibiliFailureKind.apiChanged, 'lol page: no access_id');
    }
    return id;
  }
}
