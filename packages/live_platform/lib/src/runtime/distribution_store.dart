import 'dart:io';

import 'package:live_platform/src/runtime/desktop_distribution.dart';
import 'package:live_platform/src/runtime/distribution_claim.dart';
import 'package:path/path.dart' as p;

/// Reads and writes `distribution.json` claims in one directory.
///
/// Two locations, two roles, deliberately separated: the claim bundled next
/// to the executable belongs to the packaging flow and is never written
/// here; the writable metadata directory holds the runtime's inferred cache.
/// Every write is atomic (unique temp file, then rename), never overwrites a
/// `build` claim, skips when the value is unchanged, and fails silently —
/// the cache is an optimisation, and losing it must never cost a startup.
abstract final class DistributionStore {
  /// Per-process counter giving each temp file its own name, so concurrent
  /// writers in the desktop shell's second isolate cannot claim the same
  /// temp path.
  static int _sequence = 0;

  /// Reads the claim in [directory]; null when absent, unreadable, or
  /// invalid — the three are indistinguishable by design.
  static DistributionClaim? read(Directory directory) =>
      DistributionClaim.readFile(File(p.join(directory.path, DistributionClaim.fileName)));

  /// Persists [distribution] as an inferred claim in [directory].
  ///
  /// A `build` claim already present is left byte-for-byte alone, an
  /// identical inferred claim is not rewritten, and any filesystem failure
  /// is swallowed: callers must not order startup around this write.
  static void writeInferred(Directory directory, DesktopDistribution distribution) {
    final File target;
    try {
      final existing = read(directory);
      if (existing != null && existing.source == DistributionClaimSource.build) {
        return;
      }
      if (existing != null &&
          existing.source == DistributionClaimSource.inferred &&
          existing.distribution == distribution) {
        return;
      }
      directory.createSync(recursive: true);
      target = File(p.join(directory.path, DistributionClaim.fileName));
      // Windows cannot rename over an existing file, so the old cache goes
      // first. For a cache JSON the widened window (target gone, temp not
      // yet renamed) costs one re-detection at worst.
      if (target.existsSync()) {
        target.deleteSync();
      }
      // The claim's own name survives in the temp name so a crash orphan
      // identifies the file it was writing.
      File(p.join(directory.path, '.distribution_${pid}_${++_sequence}.tmp'))
        ..writeAsStringSync(
          DistributionClaim(
            schemaVersion: DistributionClaim.currentSchemaVersion,
            distribution: distribution,
            source: DistributionClaimSource.inferred,
          ).toJson(),
        )
        ..renameSync(target.path);
    } on FileSystemException {
      // The inferred cache is best-effort; detection simply reruns next launch.
    }
  }
}
