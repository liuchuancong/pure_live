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
  if (!const <String>[r'$0', r'$1', r'$2', r'$3'].every(secretTemplate.contains)) {
    throw const FormatException('Huya AntiCode fm template is incomplete');
  }
  final secretStr = secretTemplate
      .replaceFirst(r'$0', calcUid.toString())
      .replaceFirst(r'$1', stream)
      .replaceFirst(r'$2', secretHash)
      .replaceFirst(r'$3', wsTime);
  final wsSecret = md5.convert(utf8.encode(secretStr)).toString();

  final random = Random();
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

/// Huya's web player names this operation `rotl64`: only the low 32-bit lane is
/// rotated while the upper lane of the 64-bit viewer uid is preserved.
/// Rotating only the low lane and returning it would truncate real anonymous
/// uids (> 2^32) and the CDN answers with 403.
int rotateViewerUid32(int value) {
  final low = value & 0xffffffff;
  final high = value - low;
  final rotatedLow = ((low << 8) | (low >> 24)) & 0xffffffff;
  return high | rotatedLow;
}

/// An anonymous viewer uid in the range the web player issues. Random.nextInt
/// only supports ranges up to 2^32, so the 100-billion offset is composed from
/// two supported uniform draws.
int createFallbackViewerUid() {
  final random = Random.secure();
  final offset = random.nextInt(1000000) * 100000 + random.nextInt(100000);
  return 1400000000000 + offset;
}
