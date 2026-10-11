import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:live_sites/src/contracts/site_error.dart';

/// WBI request signing for the Bilibili web APIs that demand `w_rid`.
abstract final class BilibiliWbi {
  /// The fixed permutation applied to `imgKey + subKey`.
  static const List<int> _mixinTable = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, //
    38, 41, 13, 37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62,
    11, 36, 20, 34, 44, 52,
  ];

  static final RegExp _unsafe = RegExp("[!'()*]");

  /// The 32-char mixin key derived from the two nav keys.
  static String mixinKey(String imgKey, String subKey) {
    final origin = '$imgKey$subKey';
    if (origin.length < 64) {
      throw SiteApiChangedError('WBI keys too short (${origin.length} characters)');
    }
    return [for (final index in _mixinTable) origin[index]].join().substring(0, 32);
  }

  /// Signs [params]: `wts` added, keys sorted, unsafe characters
  /// stripped, then `w_rid` = md5(query + mixinKey).
  static String sign(Map<String, String> params, {required String mixinKey, required int wts}) {
    final all = {...params, 'wts': '$wts'};
    final keys = all.keys.toList()..sort();
    final query = [
      for (final key in keys) '${Uri.encodeComponent(key)}=${Uri.encodeComponent(all[key]!.replaceAll(_unsafe, ''))}',
    ].join('&');
    final digest = md5.convert(utf8.encode('$query$mixinKey')).toString();
    return '$query&w_rid=$digest';
  }

  /// Extracts `(imgKey, subKey)` from the nav payload: the file names of
  /// `data.wbi_img.img_url` / `sub_url`.
  static ({String imgKey, String subKey}) keys(Object? navData) {
    String? key(Object? url) {
      final text = url?.toString() ?? '';
      if (text.isEmpty) {
        return null;
      }
      final name = text.substring(text.lastIndexOf('/') + 1).split('.').first;
      return name.isEmpty ? null : name;
    }

    final wbi = navData is Map<String, Object?> ? navData['wbi_img'] : null;
    final imgKey = wbi is Map<String, Object?> ? key(wbi['img_url']) : null;
    final subKey = wbi is Map<String, Object?> ? key(wbi['sub_url']) : null;
    if (imgKey == null || subKey == null) {
      throw const SiteApiChangedError('nav: no wbi_img keys');
    }
    return (imgKey: imgKey, subKey: subKey);
  }
}
