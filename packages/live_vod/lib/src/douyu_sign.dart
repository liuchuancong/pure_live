import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:live_vod/src/vod_models.dart' show VodFailure;

const int _mask = 0xffffffff;

/// A data-only parser of Douyu VOD's daily signing descriptor. It implements
/// bounded XTEA decoding and TEA signing in Dart, never evaluating
/// JavaScript. The wire contract was checked against the official video
/// page.
final class DouyuVodSigner {
  new _(this.version, this._key, this._operations);

  /// Parses a daily `ub98484234` script. Unknown operations fail explicitly;
  /// they cannot access the filesystem, network, globals or an eval runtime.
  factory fromScript(String script) {
    if (script.length > 131072) {
      throw const VodFailure('the signing descriptor the station sends broke its bounds');
    }
    final source = script.replaceAll(RegExp(r'\s+'), '');
    final arrays = RegExp(r'var\w+=\[([0-9a-fx,]+)\]').allMatches(source);
    final initial = arrays.map((match) => _numbers(match.group(1)!)).where((values) => values.length >= 16).firstOrNull;
    if (initial == null || initial.length.isOdd || initial.length > 4096) _invalid();
    final rounds = _array(source, 'rk');
    final key = _array(source, 'k', length: 4);
    final xor = _array(source, 'k2', length: 2);
    final look = _array(source, 'lk', length: 2);
    if (rounds.length * 2 != initial.length || rounds.any((value) => value < 1 || value > 128)) _invalid();
    final prefix = RegExp(r'for\(varO=0;O<(\d+);O\+\+\)\{v\[O\]\^=(0x[0-9a-f]+);\}').firstMatch(source);
    if (prefix == null || int.tryParse(prefix.group(1)!) != initial.length) _invalid();
    final loopAt = source.indexOf('for(varI=0;', prefix.end);
    if (loopAt < 0) _invalid();
    final mutations = _parseOperations(source.substring(prefix.end, loopAt), 'v', 'lk', initial.length, 2);
    final values = [for (final value in initial) value ^ int.parse(prefix.group(2)!)];
    _apply(values, look, mutations);
    for (var at = 0; at < values.length; at += 2) {
      var a = values[at] ^ xor[0];
      var b = values[at + 1] ^ xor[1];
      var total = (0x9e3779b9 * rounds[at ~/ 2]) & _mask;
      for (var round = 0; round < rounds[at ~/ 2]; round++) {
        b = (b - (((((a << 4) & _mask) ^ (a >>> 5)) + a) ^ (total + key[(total >>> 11) & 3]))) & _mask;
        total = (total - 0x9e3779b9) & _mask;
        a = (a - (((((b << 4) & _mask) ^ (b >>> 5)) + b) ^ (total + key[total & 3]))) & _mask;
      }
      values[at] = a ^ xor[1];
      values[at + 1] = b ^ xor[0];
    }
    for (var at = values.length - 1; at > 0; at--) {
      values[at] ^= values[at - 1];
    }
    final suffix = RegExp(r'v\[0\]\^=(0x[0-9a-f]+);varstrc=').firstMatch(source);
    if (suffix == null) _invalid();
    values[0] ^= int.parse(suffix.group(1)!);
    final decoded = latin1.decode([
      for (final value in values)
        for (var byte = 0; byte < 4; byte++) (value >>> (byte * 8)) & 255,
    ]);
    final program = decoded.replaceAll(RegExp(r'\s+'), '').replaceAll('\u0000', '');
    final version = RegExp(r'varcb=\w+\+\w+\+\w+\+"(\d{10,24})";varrb=CryptoJS\.MD5\(cb\)\.toString\(\);')
        .firstMatch(program)
        ?.group(1);
    final teaKey = _array(program, 'k2', length: 4);
    const teaEnd = 're[I*2+1]=v1;}';
    final begin = program.indexOf(teaEnd);
    final end = program.indexOf('{varhc=');
    if (version == null ||
        begin < 0 ||
        end < begin ||
        !program.contains('for(i=0;i<32;i++)') ||
        !program.contains('vardelta=0x9e3779b9;') ||
        !program.contains('"v=$version"')) {
      _invalid();
    }
    final operations = _parseOperations(program.substring(begin + teaEnd.length, end), 're', 'k2', 4, 4);
    return DouyuVodSigner._(version, List<int>.unmodifiable(teaKey), List<_Mutation>.unmodifiable(operations));
  }

  /// The platform's daily signing version.
  final String version;
  final List<int> _key;
  final List<_Mutation> _operations;

  /// Signs a video request with a fresh timestamp and this client's
  /// anonymous 32-digit device id. A login cookie is neither required nor
  /// embedded here.
  Map<String, String> form({
    required String pointId,
    required String videoId,
    required String did,
    required int seconds,
  }) {
    if (!RegExp(r'^\d{1,20}$').hasMatch(pointId) ||
        !RegExp(r'^[A-Za-z0-9]{1,64}$').hasMatch(videoId) ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(did) ||
        seconds < 1) {
      throw const VodFailure('the signing input the walk carries is not one the station accepts');
    }
    final digest = md5.convert(utf8.encode('$pointId$did$seconds$version')).bytes;
    final bytes = ByteData.sublistView(Uint8List.fromList(digest));
    final values = [for (var at = 0; at < 16; at += 4) bytes.getUint32(at, Endian.little)];
    for (var pair = 0; pair < 2; pair++) {
      var a = values[pair * 2];
      var b = values[pair * 2 + 1];
      var total = 0;
      for (var round = 0; round < 32; round++) {
        total = (total + 0x9e3779b9) & _mask;
        a = (a + (((b << 4) + _key[0]) ^ (b + total) ^ ((b >>> 5) + _key[1]))) & _mask;
        b = (b + (((a << 4) + _key[2]) ^ (a + total) ^ ((a >>> 5) + _key[3]))) & _mask;
      }
      values[pair * 2] = a;
      values[pair * 2 + 1] = b;
    }
    _apply(values, _key, _operations);
    final signature = [
      for (final value in values)
        for (var byte = 0; byte < 4; byte++) ((value >>> (byte * 8)) & 255).toRadixString(16).padLeft(2, '0'),
    ].join();
    return {'v': version, 'did': did, 'tt': '$seconds', 'sign': signature, 'vid': videoId};
  }
}

Never _invalid() => throw const VodFailure('the signing descriptor the station sends changed');

List<int> _numbers(String text) {
  final tokens = text.split(',');
  if (tokens.length > 4096) _invalid();
  final values = <int>[];
  for (final token in tokens) {
    if (!RegExp(r'^(?:0x[0-9a-f]{1,8}|\d{1,10})$').hasMatch(token)) _invalid();
    final value = int.parse(token);
    if (value > _mask) _invalid();
    values.add(value);
  }
  return values;
}

List<int> _array(String source, String name, {int? length}) {
  final match = RegExp('var${RegExp.escape(name)}=\\[([0-9a-fx,]+)\\]').firstMatch(source);
  if (match == null) _invalid();
  final values = _numbers(match.group(1)!);
  if (length != null && values.length != length) _invalid();
  return values;
}

final class _Mutation {
  const new(this.index, this.operation, this.key);
  final int index;
  final String operation;
  final int key;
}

List<_Mutation> _parseOperations(String source, String target, String key, int count, int keys) {
  final escaped = RegExp.escape(target);
  final keyName = RegExp.escape(key);
  final arithmetic = RegExp('^$escaped\\[(\\d+)\\]([+^\\-])=$keyName\\[(\\d+)\\]\$');
  final rotate = RegExp(
    '^$escaped\\[(\\d+)\\]=\\($escaped\\[\\1\\](<<|>>>)\\($keyName\\[(\\d+)\\]%16\\)\\)\\|\\($escaped\\[\\1\\](>>>|<<)\\(32-\\($keyName\\[\\3\\]%16\\)\\)\\)\$',
  );
  final result = <_Mutation>[];
  for (final statement in source.split(';').where((statement) => statement.isNotEmpty)) {
    final simple = arithmetic.firstMatch(statement);
    final rotation = simple == null ? rotate.firstMatch(statement) : null;
    final match = simple ?? rotation;
    if (match == null) _invalid();
    final index = int.parse(match.group(1)!);
    final keyIndex = int.parse(match.group(3)!);
    final operation = match.group(2)!;
    if (index >= count || keyIndex >= keys || (rotation != null && rotation.group(4) == operation)) _invalid();
    result.add(_Mutation(index, operation, keyIndex));
    if (result.length > 8192) _invalid();
  }
  return result;
}

void _apply(List<int> values, List<int> keys, List<_Mutation> operations) {
  for (final operation in operations) {
    final value = values[operation.index];
    final key = keys[operation.key];
    final shift = key % 16;
    values[operation.index] = switch (operation.operation) {
      '+' => (value + key) & _mask,
      '-' => (value - key) & _mask,
      '^' => (value ^ key) & _mask,
      '<<' => ((value << shift) | (value >>> ((32 - shift) % 32))) & _mask,
      '>>>' => ((value >>> shift) | (value << ((32 - shift) % 32))) & _mask,
      _ => _invalid(),
    };
  }
}
