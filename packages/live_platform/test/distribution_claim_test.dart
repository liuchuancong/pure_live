import 'dart:io';

import 'package:live_platform/live_platform.dart';
import 'package:test/test.dart';

/// A claim file is trusted exactly as far as it parses: a corrupt, partial,
/// or future-format file must be indistinguishable from a missing one, so
/// every bad shape below parses to null and never to a default
/// distribution.
void main() {
  group('parsing (§3)', () {
    test('a build claim round-trips', () {
      final claim = DistributionClaim.tryParse('{"schemaVersion":1,"distribution":"portable","source":"build"}');

      expect(claim, isNotNull);
      expect(claim!.schemaVersion, 1);
      expect(claim.distribution, DesktopDistribution.portable);
      expect(claim.source, DistributionClaimSource.build);
      expect(claim.toJson(), '{"schemaVersion":1,"distribution":"portable","source":"build"}');
    });

    test('an inferred claim round-trips', () {
      final claim = DistributionClaim.tryParse('{"schemaVersion":1,"distribution":"msix","source":"inferred"}');

      expect(claim!.distribution, DesktopDistribution.msix);
      expect(claim.source, DistributionClaimSource.inferred);
    });

    test('a future schema version is not interpreted as a default', () {
      expect(DistributionClaim.tryParse('{"schemaVersion":2,"distribution":"msix","source":"build"}'), isNull);
      expect(
        DistributionClaim.tryParse('{"distribution":"msix","source":"build"}'),
        isNull,
        reason: 'a missing version is an unknown format too',
      );
    });

    test('unknown enum values, wrong types and junk are all null', () {
      expect(DistributionClaim.tryParse('{"schemaVersion":1,"distribution":"exe","source":"build"}'), isNull);
      expect(DistributionClaim.tryParse('{"schemaVersion":1,"distribution":"unknown","source":"build"}'), isNull);
      expect(DistributionClaim.tryParse('{"schemaVersion":1,"distribution":"msix","source":"guessed"}'), isNull);
      expect(DistributionClaim.tryParse('{"schemaVersion":"1","distribution":"msix","source":"build"}'), isNull);
      expect(DistributionClaim.tryParse('{"schemaVersion":1,"source":"build"}'), isNull);
      expect(DistributionClaim.tryParse('not json at all'), isNull);
      expect(DistributionClaim.tryParse('[]'), isNull);
    });

    test('a missing or unreadable file reads as null', () {
      expect(DistributionClaim.readFile(File('Z:/nowhere/distribution.json')), isNull);
    });
  });
}
