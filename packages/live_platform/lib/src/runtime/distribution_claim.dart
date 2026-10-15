import 'dart:convert';
import 'dart:io';

import 'package:live_platform/src/runtime/desktop_distribution.dart';

/// Where a distribution claim came from.
///
/// `build` is the packaging flow's own statement about the artifact it
/// produced — the strongest on-disk evidence. `inferred` is the runtime's
/// cached detection result: a hint that was reliable when it was written,
/// never an immutable fact.
enum DistributionClaimSource {
  /// Written by the packaging flow next to the executable.
  build,

  /// Written by the runtime after a reliable detection.
  inferred,
}

/// One `distribution.json` claim: the format version, the distribution it
/// names, and who wrote it.
///
/// Parsing is all-or-nothing: a file that is missing fields, carries an
/// unknown distribution or source value, names a schema version this package
/// does not understand, or is not JSON at all parses to null — never to a
/// default distribution. An unreadable claim must look exactly like a
/// missing one.
final class DistributionClaim {
  /// A parsed claim.
  const new({required this.schemaVersion, required this.distribution, required this.source});

  /// The current schema version this package reads and writes.
  static const int currentSchemaVersion = 1;

  /// The file name, identical in every location a claim may live.
  static const String fileName = 'distribution.json';

  /// The claim format version; only [currentSchemaVersion] is accepted.
  final int schemaVersion;

  /// The distribution the file names. `unknown` is not a writable claim —
  /// a claim that says unknown is nonsense and parses to null.
  final DesktopDistribution distribution;

  /// Who wrote the claim.
  final DistributionClaimSource source;

  /// Parses file [contents]; null for anything this schema cannot accept.
  static DistributionClaim? tryParse(String contents) {
    final Object? decoded;
    try {
      decoded = jsonDecode(contents);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) {
      return null;
    }
    if (decoded['schemaVersion'] is! int || decoded['schemaVersion'] != currentSchemaVersion) {
      return null;
    }
    final distribution = switch (decoded['distribution']) {
      'portable' => DesktopDistribution.portable,
      'msix' => DesktopDistribution.msix,
      'installed' => DesktopDistribution.installed,
      _ => null,
    };
    final source = switch (decoded['source']) {
      'build' => DistributionClaimSource.build,
      'inferred' => DistributionClaimSource.inferred,
      _ => null,
    };
    if (distribution == null || source == null) {
      return null;
    }
    return DistributionClaim(schemaVersion: currentSchemaVersion, distribution: distribution, source: source);
  }

  /// Serialises to the canonical single-line JSON form.
  String toJson() =>
      jsonEncode({'schemaVersion': schemaVersion, 'distribution': distribution.name, 'source': source.name});

  /// Reads and parses the claim at [file]; a missing or unreadable file is
  /// null, exactly like a corrupt one.
  static DistributionClaim? readFile(File file) {
    try {
      return tryParse(file.readAsStringSync());
    } on FileSystemException {
      return null;
    }
  }
}
