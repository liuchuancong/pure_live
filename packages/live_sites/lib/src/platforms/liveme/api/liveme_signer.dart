import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart' as crypto;

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The request signature of LiveMe's official web client (3.x's
/// `LiveMeSigner`): the form gets the `lm_s_*` fields, and md5 over the
/// query and form pairs sorted by name (`name` + `value` each), the client
/// id, the timestamp and the web secret is the `lm-s-sign` header. The
/// constants ship in the web bundle; they identify the web client, not an
/// account.
final class LivemeSigner {
  /// Creates a signer; [random] (the `vali` characters) is injectable for
  /// tests.
  LivemeSigner({math.Random? random}) : _random = random ?? math.Random.secure();

  /// `lm_s_id`.
  static const String clientId = 'LM6000101139961122666757';

  static const String _secret = 'dd46dbb442b6e4ba817d6347d2ddf493';
  static const String _valiAlphabet = 'ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678';

  final math.Random _random;
  var _counter = 0;

  /// [signAt] with the timestamp of [now]: its milliseconds and one counter
  /// digit, so two requests in one millisecond differ.
  ({Map<String, String> fields, String signature}) sign({
    required Map<String, String> query,
    required Map<String, String> form,
    required DateTime now,
  }) {
    final timestamp = '${now.millisecondsSinceEpoch}$_counter';
    _counter = (_counter + 1) % 10;
    return signAt(query: query, form: form, timestamp: timestamp);
  }

  /// [form] with `lm_s_id`, `lm_s_ts` ([timestamp]), `lm_s_str` (its md5),
  /// `lm_s_ver` and `h5` added, and the `lm-s-sign` value over [query] and
  /// those fields.
  static ({Map<String, String> fields, String signature}) signAt({
    required Map<String, String> query,
    required Map<String, String> form,
    required String timestamp,
  }) {
    final fields = <String, String>{
      ...form,
      'lm_s_id': clientId,
      'lm_s_ts': timestamp,
      'lm_s_str': _md5(timestamp),
      'lm_s_ver': '1',
      'h5': '1',
    };
    final all = {...query, ...fields};
    final input = StringBuffer();
    for (final key in all.keys.toList()..sort()) {
      input
        ..write(key)
        ..write(all[key]);
    }
    input
      ..write(clientId)
      ..write(timestamp)
      ..write(_secret);
    return (fields: Map.unmodifiable(fields), signature: _md5('$input'));
  }

  /// The `vali` form value: 4 + `l` + 4 + `m` + 5 characters of the web
  /// client's alphabet.
  String vali() => '${_part(4)}l${_part(4)}m${_part(5)}';

  String _part(int length) =>
      List.generate(length, (_) => _valiAlphabet[_random.nextInt(_valiAlphabet.length)], growable: false).join();

  static String _md5(String value) => crypto.md5.convert(utf8.encode(value)).toString();
}
