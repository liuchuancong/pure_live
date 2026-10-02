import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class LiveMeSignedForm {
  const LiveMeSignedForm({required this.fields, required this.signature});

  final Map<String, String> fields;
  final String signature;
}

/// Reproduces the request signature emitted by LiveMe's current official web
/// client. The monotonic suffix keeps two requests in the same millisecond
/// distinct without depending on process-global mutable state.
class LiveMeSigner {
  LiveMeSigner({Random? random}) : _random = random ?? Random.secure();

  static const clientId = 'LM6000101139961122666757';
  static const _secret = 'dd46dbb442b6e4ba817d6347d2ddf493';
  static const _valiAlphabet = 'ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678';

  final Random _random;
  int _counter = 0;

  LiveMeSignedForm sign({required Map<String, String> query, required Map<String, String> body, DateTime? now}) {
    final timestamp = '${(now ?? DateTime.now()).millisecondsSinceEpoch}${_counter++ % 10000}';
    final fields = <String, String>{
      ...body,
      'lm_s_id': clientId,
      'lm_s_ts': timestamp,
      'lm_s_str': md5.convert(utf8.encode(timestamp)).toString(),
      'lm_s_ver': '1',
      'h5': '1',
    };
    final all = <String, String>{...query, ...fields};
    final keys = all.keys.toList(growable: false)..sort();
    final input = StringBuffer();
    for (final key in keys) {
      input
        ..write(key)
        ..write(all[key]);
    }
    input
      ..write(clientId)
      ..write(timestamp)
      ..write(_secret);
    return LiveMeSignedForm(
      fields: Map.unmodifiable(fields),
      signature: md5.convert(utf8.encode(input.toString())).toString(),
    );
  }

  String vali() => '${_randomText(4)}l${_randomText(4)}m${_randomText(5)}';

  String _randomText(int length) =>
      List.generate(length, (_) => _valiAlphabet[_random.nextInt(_valiAlphabet.length)], growable: false).join();
}
