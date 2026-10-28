import 'dart:convert' show jsonDecode, utf8;

import 'package:crypto/crypto.dart' show md5;

/// Bilibili's WBI request signature (`w_rid`), for the endpoints that ask for
/// one: the home recommendation feed and the PGC player.
///
/// The keys come from `x/web-interface/nav`'s `data.wbi_img` file names; the
/// mixin key permutes their concatenation through the table below and keeps
/// the first 32 characters. The signed query is the parameters plus `wts`
/// (Unix seconds), sorted by key, each value stripped of `!'()*` and
/// percent-encoded like `encodeURIComponent`; `w_rid` is the MD5 of that
/// query and the mixin key.
abstract final class BilibiliWbiSign {
  /// The fixed permutation of the 64 key characters (Bilibili's web client
  /// constant).
  static const List<int> mixinTable = [
    46,
    47,
    18,
    2,
    53,
    8,
    23,
    32,
    15,
    50,
    10,
    31,
    58,
    3,
    45,
    35,
    27,
    43,
    5,
    49,
    33,
    9,
    42,
    19,
    29,
    28,
    14,
    39,
    12,
    38,
    41,
    13,
    37,
    48,
    7,
    16,
    24,
    55,
    40,
    61,
    26,
    17,
    0,
    1,
    60,
    51,
    30,
    4,
    22,
    25,
    54,
    21,
    56,
    59,
    6,
    63,
    57,
    62,
    11,
    36,
    20,
    34,
    44,
    52,
  ];

  static final RegExp _unsafe = RegExp("[!'()*]");

  /// The mixin key: [imgKey] + [subKey] permuted by [mixinTable], the first
  /// 32 characters.
  static String mixinKey(String imgKey, String subKey) {
    final origin = '$imgKey$subKey';
    if (origin.length < 64) {
      throw const FormatException('WBI keys too short');
    }
    return [for (final index in mixinTable) origin[index]].join().substring(0, 32);
  }

  /// The signed query of [params]: the parameters, `wts` and `w_rid`.
  static Map<String, String> sign(
    Map<String, String> params, {
    required String imgKey,
    required String subKey,
    required int wts,
  }) {
    final all = {...params, 'wts': '$wts'};
    final keys = all.keys.toList()..sort();
    final unsigned = [
      for (final key in keys) '${Uri.encodeComponent(key)}=${Uri.encodeComponent(all[key]!.replaceAll(_unsafe, ''))}',
    ].join('&');
    final rid = md5.convert(utf8.encode('$unsigned${mixinKey(imgKey, subKey)}')).toString();
    return {...all, 'w_rid': rid};
  }

  /// The WBI key pair of a `x/web-interface/nav` answer, read from
  /// `data.wbi_img.img_url` and `sub_url` as their file-name stems; null when
  /// the answer carries neither. A guest gets envelope code `-101` with the
  /// keys still present, so this reads the data before the envelope.
  static ({String imgKey, String subKey})? keysOf(String body) {
    String? key(Object? url) {
      if (url is! String || url.isEmpty) return null;
      final name = url.substring(url.lastIndexOf('/') + 1).split('.').first;
      return name.isEmpty ? null : name;
    }

    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    final data = json['data'];
    if (data is! Map) return null;
    final image = data['wbi_img'];
    if (image is! Map) return null;
    final imgKey = key(image['img_url']);
    final subKey = key(image['sub_url']);
    return imgKey == null || subKey == null ? null : (imgKey: imgKey, subKey: subKey);
  }
}
