import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// The signing descriptor `getEncryption` issues for one device id.
///
/// `auth` for room `roomId` at Unix second `tt`: `randStr` hashed with
/// the key `encTime` times, then md5 of secret + key + rid + tt (without
/// rid and tt when `isSpecial`).
@immutable
final class DouyuDescriptor {
  /// Creates a descriptor.
  const new({
    required this.key,
    required this.randStr,
    required this.encData,
    required this.encTime,
    required this.expireAt,
    required this.isSpecial,
  });

  /// Reads the `getEncryption` data object; null when a field is missing
  /// or blank, or `enc_time` is outside 1–16. Numbers may be strings.
  static DouyuDescriptor? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    String? str(Object? v) => v?.toString();
    final key = str(value['key']);
    final randStr = str(value['rand_str']);
    final encData = str(value['enc_data']);
    final encTime = int.tryParse(value['enc_time']?.toString() ?? '');
    final expireAt = int.tryParse(value['expire_at']?.toString() ?? '');
    if (key == null || key.isEmpty || randStr == null || encData == null || encTime == null || expireAt == null) {
      return null;
    }
    if (encTime < 1 || encTime > 16) {
      return null;
    }
    return DouyuDescriptor(
      key: key,
      randStr: randStr,
      encData: encData,
      encTime: encTime,
      expireAt: DateTime.fromMillisecondsSinceEpoch(expireAt * 1000, isUtc: true),
      isSpecial: value['is_special']?.toString() == '1',
    );
  }

  /// Signing key.
  final String key;

  /// Initial secret.
  final String randStr;

  /// Passed through to the play form as is.
  final String encData;

  /// Hashing rounds, 1–16.
  final int encTime;

  /// When the platform stops accepting it.
  final DateTime expireAt;

  /// Special rooms sign without rid and tt in the salt.
  final bool isSpecial;

  static const Duration _margin = Duration(minutes: 2);

  /// Usable when it expires more than two minutes after [now].
  bool usableAt(DateTime now) => expireAt.isAfter(now.add(_margin));

  /// The `auth` signature for room [roomId] at Unix second [tt].
  String auth(String roomId, int tt) {
    var secret = randStr;
    for (var round = 0; round < encTime; round++) {
      secret = md5.convert(utf8.encode('$secret$key')).toString();
    }
    final salt = isSpecial ? '' : '$roomId$tt';
    return md5.convert(utf8.encode('$secret$key$salt')).toString();
  }
}
