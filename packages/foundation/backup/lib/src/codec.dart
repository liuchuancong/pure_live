// Module: lib/src/codec.dart
// Purpose: Turn a bundle into the bytes an archive is, and refuse bytes that are not one.
// Author: liuchuancong
// Created: 2026-10-11
//
// The engine produced an in-memory bundle, which is not a backup: nothing was written, nothing was read back,
// and a restore accepted whatever shape a caller handed it. Two things matter here. A digest is checked
// before anything is applied, because a truncated upload restored domain by domain looks identical to a
// successful restore right up until the settings are wrong. And the byte ceiling is applied *before parsing*,
// because the alternative is trusting a remote to send a small file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'engine.dart';
import 'manifest.dart';

/// The largest archive this build will parse.
const int kBackupMaxBytes = 32 * 1024 * 1024;

/// The format marker carried in every archive, so a wrong file is refused by name rather than by a parse
/// failure that might accidentally succeed.
const String kBackupFormatMarker = 'pure-live-backup';

/// The envelope version of the *container*, distinct from the manifest's data schema version.
const int kBackupContainerVersion = 1;

/// Why an archive was refused.
final class BackupCodecFailure implements Exception {
  const BackupCodecFailure(this.reason, {this.expected, this.found});

  final String reason;

  /// What the archive should have carried, when the comparison is meaningful.
  final Object? expected;
  final Object? found;

  @override
  String toString() {
    final detail = expected == null ? '' : ' (expected=$expected, found=$found)';
    return 'BackupCodecFailure($reason$detail)';
  }
}

/// A decoded archive, with the integrity facts attached so a UI can show them without recomputing.
final class DecodedBackup {
  const DecodedBackup({required this.bundle, required this.bytes, required this.digest});

  final BackupBundle bundle;
  final int bytes;

  /// The hex SHA-256 of the canonical payload, verified on the way in.
  final String digest;

  BackupManifest get manifest => bundle.manifest;
}

/// The canonical JSON of a payload: keys sorted, so the same content always hashes to the same digest.
///
/// Dart map order is insertion order, and an archive round-tripped through a different device would otherwise
/// produce a different digest for identical content, which turns a integrity check into a coin flip.
String canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => '$key').toList()..sort();
    final parts = <String>[];
    for (final key in keys) {
      parts.add('${jsonEncode(key)}:${canonicalJson(value[key])}');
    }
    return '{${parts.join(',')}}';
  }
  if (value is List) {
    return '[${value.map(canonicalJson).join(',')}]';
  }
  return jsonEncode(value);
}

/// The digest of a bundle's payload, hex encoded.
String payloadDigest(Map<String, Map<String, Object?>> payload) =>
    sha256.convert(utf8.encode(canonicalJson(payload))).toString();

/// Writes an archive: manifest, payload, and a digest over both.
///
/// The digest covers the manifest as well as the payload, so an edit that renames a domain or flips
/// `includesCredentials` invalidates the archive rather than being honoured.
Uint8List encodeBundle(BackupBundle bundle, {bool pretty = false}) {
  final payload = <String, Map<String, Object?>>{};
  for (final domain in bundle.manifest.domains) {
    payload[domain.name] = Map<String, Object?>.of(bundle.payload[domain.name] ?? const <String, Object?>{});
  }
  final body = <String, Object?>{
    'format': kBackupFormatMarker,
    'container': kBackupContainerVersion,
    'manifest': bundle.manifest.toJson(),
    'payload': payload,
  };
  final signed = <String, Object?>{...body, 'digest': payloadDigest(payload), 'manifestDigest': _manifestDigest(body)};
  final encoded = pretty ? const JsonEncoder.withIndent('  ').convert(signed) : jsonEncode(signed);
  return Uint8List.fromList(utf8.encode(encoded));
}

String _manifestDigest(Map<String, Object?> body) =>
    sha256.convert(utf8.encode(canonicalJson(body['manifest']))).toString();

/// Parses and verifies an archive, refusing it whole rather than partially.
///
/// Every refusal is a [BackupCodecFailure], never a silent empty bundle: an archive that fails to parse is
/// data the user still has, and the reason is the only thing they can act on.
DecodedBackup decodeBundle(
  List<int> bytes, {
  Set<int> supportedSchemaVersions = const <int>{1},
  int maxBytes = kBackupMaxBytes,
}) {
  if (bytes.isEmpty) {
    throw const BackupCodecFailure('the archive is empty');
  }
  if (bytes.length > maxBytes) {
    throw BackupCodecFailure(
      'the archive exceeds the read ceiling',
      expected: '<=$maxBytes bytes',
      found: '${bytes.length} bytes',
    );
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on FormatException catch (error) {
    throw BackupCodecFailure('the archive is not valid JSON: ${error.message}');
  } on Object catch (error) {
    throw BackupCodecFailure('the archive is not UTF-8: $error');
  }
  if (decoded is! Map) {
    throw BackupCodecFailure('the archive top level is not an object', expected: 'object', found: decoded.runtimeType);
  }
  final format = decoded['format'];
  if (format != kBackupFormatMarker) {
    throw BackupCodecFailure('not a Pure Live backup archive', expected: kBackupFormatMarker, found: format);
  }
  final container = decoded['container'];
  if (container is! int || container > kBackupContainerVersion) {
    throw BackupCodecFailure(
      'the archive container is newer than this build can read',
      expected: '<=$kBackupContainerVersion',
      found: container,
    );
  }
  final manifestJson = decoded['manifest'];
  if (manifestJson is! Map) {
    throw BackupCodecFailure('the archive has no manifest object', expected: 'object', found: manifestJson.runtimeType);
  }
  final manifest = BackupManifest.fromJson(Map<String, Object?>.from(manifestJson));
  final problem = manifest.validate(supportedSchemaVersions: supportedSchemaVersions);
  if (problem != null) {
    throw BackupCodecFailure(problem);
  }
  final payloadJson = decoded['payload'];
  if (payloadJson is! Map) {
    throw BackupCodecFailure('the archive has no payload object', expected: 'object', found: payloadJson.runtimeType);
  }
  final payload = <String, Map<String, Object?>>{};
  for (final domain in manifest.domains) {
    final rows = payloadJson[domain.name];
    if (rows == null) {
      // A manifest that lists a domain the payload does not carry is half an archive; the digest will not
      // match either, but naming the domain is the diagnosis worth reporting.
      throw BackupCodecFailure('the payload is missing the domain "${domain.name}"');
    }
    if (rows is! Map) {
      throw BackupCodecFailure('domain "${domain.name}" is not an object', expected: 'object', found: rows.runtimeType);
    }
    payload[domain.name] = Map<String, Object?>.from(rows);
  }
  final expectedDigest = decoded['digest'];
  final actualDigest = payloadDigest(payload);
  if (expectedDigest != actualDigest) {
    throw BackupCodecFailure(
      'the payload digest does not match the archive',
      expected: expectedDigest,
      found: actualDigest,
    );
  }
  final expectedManifestDigest = decoded['manifestDigest'];
  final actualManifestDigest = sha256.convert(utf8.encode(canonicalJson(manifestJson))).toString();
  if (expectedManifestDigest != actualManifestDigest) {
    throw BackupCodecFailure(
      'the manifest was altered after the archive was written',
      expected: expectedManifestDigest,
      found: actualManifestDigest,
    );
  }
  for (final entry in payload.entries) {
    final declared = manifest.domains.firstWhere((domain) => domain.name == entry.key);
    if (declared.keyCount != entry.value.length) {
      throw BackupCodecFailure(
        'domain "${entry.key}" holds a different key count than its manifest entry',
        expected: declared.keyCount,
        found: entry.value.length,
      );
    }
  }
  return DecodedBackup(
    bundle: BackupBundle(manifest: manifest, payload: payload),
    bytes: bytes.length,
    digest: actualDigest,
  );
}
