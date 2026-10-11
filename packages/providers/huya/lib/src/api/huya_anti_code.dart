// Module: lib/src/huya_signing.dart
// Purpose: Rebuilds a Huya AntiCode into a playable, per-open signed query.
// Author: liuchuancong
// Created: 2026-10-09
//
// Provenance: the algorithm is the v1-maintained line's buildAntiCode
// (origin/master lib/shared/platforms/huya/huya_site.dart), itself synced from
// dart_simple_live. This is a from-scratch implementation against the
// capability contracts, not a file merge (UPSTREAM_REVIEW_POLICY.md): no
// upstream commit enters this repository through this file.
//
// How it works: when the server-issued antiCode carries an `fm` field, that
// field is a base64 template whose `$0..$3` placeholders take the viewer uid,
// stream name, a seqid hash and wsTime; md5 of the filled template is the
// wsSecret the CDN accepts. An antiCode without `fm` is already signed and
// passes through untouched.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'huya_viewer_uid.dart';

/// Rebuilds [antiCode] for one open of [stream] as viewer [viewerUid].
///
/// [now] is injectable for deterministic callers; production calls pass
/// nothing and get the current wall clock. Throws [FormatException] when the
/// template is unreadable and [StateError] when the wsTime lease has already
/// lapsed - both mean "do not open this URL", not "open it and see".
String buildAntiCode(String stream, int viewerUid, String antiCode, {DateTime? now}) {
  final original = Uri(query: antiCode).queryParameters;
  final encodedFm = original['fm']?.trim() ?? '';
  if (encodedFm.isEmpty) {
    return antiCode;
  }

  final ctype = original['ctype']?.trim().isNotEmpty == true ? original['ctype']!.trim() : 'huya_webh5';
  final platformId = original['t']?.trim().isNotEmpty == true ? original['t']!.trim() : '100';
  final isWap = platformId == '103';
  final timestamp = now ?? DateTime.now();
  final currentMillis = timestamp.millisecondsSinceEpoch;
  final currentSeconds = currentMillis ~/ 1000;
  final uid = viewerUid > 0 ? viewerUid : createFallbackViewerUid();

  final wsTimeRaw = original['wsTime']?.trim() ?? '';
  final wsTimeSeconds = int.tryParse(wsTimeRaw, radix: 16);
  if (wsTimeSeconds == null) {
    throw const FormatException('Huya AntiCode has no valid wsTime');
  }
  if (currentSeconds > wsTimeSeconds + const Duration(minutes: 5).inSeconds) {
    throw StateError('Huya AntiCode lease expired');
  }
  final wsTime = wsTimeRaw.toLowerCase();
  final seqId = uid + currentMillis;
  final secretHash = md5.convert(utf8.encode('$seqId|$ctype|$platformId')).toString();

  final convertedUid = rotateViewerUid32(uid);
  final calcUid = isWap ? uid : convertedUid;
  // The official player treats `fm` as a server-owned template and replaces its four placeholders in place.
  // Splitting on `_` and rebuilding a presumed layout would silently sign the wrong string as soon as Huya
  // adds a field; the complete decoded template is preserved instead.
  final secretTemplate = utf8.decode(base64.decode(base64.normalize(encodedFm)));
  final secretStr = fillAntiCodeTemplate(
    secretTemplate,
    calcUid: calcUid,
    stream: stream,
    secretHash: secretHash,
    wsTime: wsTime,
  );
  final wsSecret = md5.convert(utf8.encode(secretStr)).toString();

  final random = Random.secure();
  final ct = ((wsTimeSeconds + random.nextDouble()) * 1000).toInt();
  final uuid = (((ct % 1e10) + random.nextDouble()) * 1e3 % 0xffffffff).toInt().toString();
  final result = <String, String>{...original}
    ..remove('wsSecret')
    ..remove('seqid')
    ..remove('u')
    ..remove('uid')
    ..remove('uuid')
    // `fm` is signing material, not a media query field: the official web player consumes it locally and
    // omits it from the emitted CDN URL.
    ..remove('fm')
    ..addAll(<String, String>{
      'wsSecret': wsSecret,
      'wsTime': wsTime,
      'seqid': seqId.toString(),
      'ctype': ctype,
      'ver': '1',
      'fs': original['fs'] ?? 'bgct',
      't': platformId,
    });
  if (isWap) {
    result.addAll(<String, String>{'uid': uid.toString(), 'uuid': uuid});
  } else {
    result['u'] = convertedUid.toString();
  }

  return Uri(queryParameters: result).query;
}

/// Fills the four `fm` placeholders in one left-to-right pass.
///
/// Sequential `replaceFirst`s would let an earlier substitution feed a later one: a room whose name contains
/// `$2` (rooms do have such names) would have its own text replaced by the hash, and the signature would be
/// computed over a string the server never templated. Each placeholder is also required to exist, because a
/// template missing one is a shape change, not a shorter lease.
String fillAntiCodeTemplate(
  String template, {
  required int calcUid,
  required String stream,
  required String secretHash,
  required String wsTime,
}) {
  final replacements = <String, String>{r'$0': calcUid.toString(), r'$1': stream, r'$2': secretHash, r'$3': wsTime};
  final missing = <String>[...replacements.keys].where((placeholder) => !template.contains(placeholder)).toList();
  if (missing.isNotEmpty) {
    throw FormatException('Huya AntiCode fm template is incomplete: ${missing.join(', ')}');
  }
  // One left-to-right pass. Each placeholder is filled at its first occurrence - which is what the site's own
  // client does with a string pattern in JavaScript's replace - and the text written in is never re-scanned,
  // so a room name that itself reads `$2` cannot be signed over.
  final buffer = StringBuffer();
  final filled = <String>{};
  for (var index = 0; index < template.length; index++) {
    if (template[index] != r'$' || index + 1 >= template.length) {
      buffer.write(template[index]);
      continue;
    }
    final placeholder = template.substring(index, index + 2);
    final replacement = replacements[placeholder];
    if (replacement == null || filled.contains(placeholder)) {
      buffer.write(template[index]);
      continue;
    }
    buffer.write(replacement);
    filled.add(placeholder);
    index++;
  }
  return buffer.toString();
}
