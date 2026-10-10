// Module: lib/src/integrity.dart
// Purpose: Verify an artifact is what the feed said it was before the device is asked to install it.
// Author: liuchuancong
// Created: 2026-10-11
//
// An update prompt that hands the user a truncated or substituted APK and says "install it anyway" is worse
// than no prompt at all: on Android a partial download cannot even be installed, and on Windows a replaced
// installer runs as whatever it is. The feed carries a digest next to each asset in the releases this repo
// publishes, so the check belongs here rather than in each app's update screen.

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// An artifact refused by the integrity check.
final class IntegrityFailure implements Exception {
  const IntegrityFailure({required this.reason, this.expected, this.found});

  final String reason;
  final String? expected;
  final String? found;

  @override
  String toString() {
    final detail = expected == null ? '' : ' (expected=$expected, found=$found)';
    return 'IntegrityFailure($reason$detail)';
  }
}

/// The declared size of an artifact, as the feed spells it.
final class ArtifactSize {
  const ArtifactSize({required this.bytes, this.maxBytes});

  final int bytes;

  /// The ceiling a caller is willing to fetch. Null means the caller set none, which is a decision the report
  /// should show rather than a default this package invents.
  final int? maxBytes;

  bool get exceedsCeiling {
    final ceiling = maxBytes;
    return ceiling != null && bytes > ceiling;
  }

  /// The declared size, checked against the ceiling *before* the bytes are fetched: a 40 MB APK on a metered
  /// connection and a 4 GB mislabelled asset are the same bug seen from two sides.
  factory ArtifactSize.declared(int bytes, {int? maxBytes, bool verify = true}) {
    if (verify && bytes < 0) {
      throw IntegrityFailure(reason: 'a declared size cannot be negative', found: '$bytes');
    }
    return ArtifactSize(bytes: bytes, maxBytes: maxBytes);
  }

  @override
  String toString() => maxBytes == null ? 'ArtifactSize($bytes bytes)' : 'ArtifactSize($bytes/$maxBytes bytes)';
}

/// The hex SHA-256 of [bytes], lower case, no separators.
String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

/// Compares a computed digest with the one the feed declared.
///
/// Both are normalised before the test: uppercase hex, surrounding whitespace and a `sha256:` prefix are all
/// things real feeds do, and a mismatch caused by formatting sends a user hunting for a bug that is not there.
void requireDigest({required List<int> bytes, required String expected, String label = 'the artifact'}) {
  final clean = _normalise(expected);
  if (clean.isEmpty) {
    throw IntegrityFailure(reason: '$label carries no digest to check against');
  }
  final actual = sha256Hex(bytes);
  if (actual != clean) {
    throw IntegrityFailure(reason: '$label does not match its declared digest', expected: clean, found: actual);
  }
}

/// Whether the bytes match, without throwing - for a caller that would rather show a warning than interrupt.
bool digestMatches(List<int> bytes, String expected) {
  try {
    requireDigest(bytes: bytes, expected: expected);
    return true;
  } on IntegrityFailure {
    return false;
  }
}

/// Parses the JSON an app's release script writes, returning the asset digests by name.
///
/// Kept small and strict: an unknown shape is an error, not an empty map, because "no digests to check" looks
/// identical to "everything matches" at the call site.
Map<String, String> parseDigestManifest(String jsonText) {
  final decoded = jsonDecode(jsonText);
  if (decoded is! Map) {
    throw IntegrityFailure(
      reason: 'the digest manifest is not a JSON object',
      found: decoded == null ? 'null' : decoded.runtimeType.toString(),
    );
  }
  final out = <String, String>{};
  decoded.forEach((name, value) {
    if (value is! String) {
      throw IntegrityFailure(reason: 'digest for "$name" is not a string', found: '$value');
    }
    out['$name'] = _normalise(value);
  });
  return out;
}

String _normalise(String digest) {
  var text = digest.trim().toLowerCase();
  if (text.startsWith('sha256:')) {
    text = text.substring('sha256:'.length);
  }
  return text.replaceAll(' ', '');
}
