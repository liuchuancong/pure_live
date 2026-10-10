// Module: lib/src/data/backup_document.dart
// Purpose: The archive's wire format - a bundle to a json document and back, refusing what it cannot trust.
// Author: liuchuancong
// Created: 2026-10-10
//
// This format knowledge lived in `apps/pure_live/lib/app/user_backup.dart` while the package that owns the
// backup domain took `buildDocument` / `applyDocument` closures from the host. That is backwards: the
// document layout is the backup format, not app wiring, and every additional app would have had to copy the
// same cast chain - including the part where a missing `payload` key throws a raw null cast.
//
// A document from a remote is untrusted input. It can be older, newer, hand-edited, or someone else's, so
// the decode path validates the manifest before anything is applied and refuses an archive that claims to
// carry credentials rather than stripping them quietly.

import 'dart:convert';

import 'package:pure_live_backup/pure_live_backup.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

import '../domain/backup_reports.dart';

/// The two top-level keys an archive document has.
const String kBackupManifestKey = 'manifest';
const String kBackupPayloadKey = 'payload';

/// The wire form of a built bundle.
Map<String, Object?> encodeBackupBundle(BackupBundle bundle) {
  return <String, Object?>{kBackupManifestKey: bundle.manifest.toJson(), kBackupPayloadKey: bundle.payload};
}

/// The wire form decoded back into a bundle, ready for `RestoreEngine.apply`.
///
/// [supportedSchemaVersions] defaults to the one version this build writes; widening it is a decision with a
/// migration attached, not a fallback to reach for when a read fails.
BackupBundle decodeBackupDocument(Map<String, Object?> document, {Set<int> supportedSchemaVersions = const <int>{1}}) {
  final manifestJson = jsonMapFrom(document[kBackupManifestKey]);
  if (manifestJson == null) {
    throw BackupFormatFailure(
      'an archive needs a "$kBackupManifestKey" object, got ${_shapeOf(document[kBackupManifestKey])}',
    );
  }
  final payloadJson = jsonMapFrom(document[kBackupPayloadKey]);
  if (payloadJson == null) {
    throw BackupFormatFailure(
      'an archive needs a "$kBackupPayloadKey" object, got ${_shapeOf(document[kBackupPayloadKey])}',
    );
  }

  final BackupManifest manifest;
  try {
    manifest = BackupManifest.fromJson(manifestJson);
  } on Object catch (error) {
    // The manifest's own reader throws on a missing domain name; that is a format problem and has to be
    // reported as one, not as an untyped error escaping a decode.
    throw BackupFormatFailure('the archive manifest could not be read', cause: error);
  }

  final problem = manifest.validate(supportedSchemaVersions: supportedSchemaVersions);
  if (problem != null) {
    throw BackupFormatFailure('the archive is not usable here: $problem');
  }

  // Each domain's values must be an object; a domain that decodes to anything else is refused rather than
  // restored as empty, because "empty" would overwrite what the device already has.
  final payload = <String, Map<String, Object?>>{};
  for (final domain in manifest.domains) {
    final values = jsonMapFrom(payloadJson[domain.name]);
    if (values == null) {
      throw BackupFormatFailure('the archive lists domain "${domain.name}" but carries no values for it');
    }
    payload[domain.name] = values;
  }
  return BackupBundle(manifest: manifest, payload: payload);
}

/// A local file's text decoded into a document, with the same refusal shape.
Map<String, Object?> decodeBackupText(String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (error) {
    throw BackupFormatFailure('the file is not json', cause: error);
  }
  final object = jsonMapFrom(decoded);
  if (object == null) {
    throw BackupFormatFailure('the file is not a json object');
  }
  return object;
}

/// A bundle encoded for a local export file, indented because a person may open it.
String encodeBackupText(BackupBundle bundle) => const JsonEncoder.withIndent('  ').convert(encodeBackupBundle(bundle));

String _shapeOf(Object? value) => switch (value) {
  null => 'nothing',
  final Map<Object?, Object?> _ => 'an object',
  final List<Object?> _ => 'a list',
  _ => 'a ${value.runtimeType}',
};
