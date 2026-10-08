// Module: test/version_test.dart
// Purpose: Verify version parsing, ordering, the ABI build offset and the update decision.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_release/pure_live_release.dart';
import 'package:test/test.dart';

void main() {
  group('AppVersion.parse', () {
    test('test_parse_fullVersion_readsEveryPart', () {
      final version = AppVersion.parse('4.0.0+5000');

      expect(version.major, 4);
      expect(version.minor, 0);
      expect(version.patch, 0);
      expect(version.build, 5000);
      expect(version.display, '4.0.0');
      expect(version.full, '4.0.0+5000');
      expect(version.toString(), '4.0.0+5000');
    });

    test('test_parse_withoutBuild_treatsItAsZero', () {
      expect(AppVersion.parse('3.1.18').build, 0);
    });

    test('test_parse_surroundingWhitespace_isIgnored', () {
      expect(AppVersion.parse('  3.1.18+4107  '), AppVersion.parse('3.1.18+4107'));
    });

    test('test_parse_notATriple_throwsWithTheOffendingText', () {
      expect(
        () => AppVersion.parse('4.0'),
        throwsA(isA<FormatException>().having((error) => error.source, 'source', '4.0')),
      );
      expect(() => AppVersion.parse('a.b.c+1'), throwsA(isA<FormatException>()));
    });

    test('test_parse_nonNumericBuild_throws', () {
      expect(() => AppVersion.parse('4.0.0+beta'), throwsA(isA<FormatException>()));
    });

    test('test_tryParse_returnsNullInsteadOfThrowing', () {
      expect(AppVersion.tryParse('nope'), isNull);
      expect(AppVersion.tryParse(null), isNull);
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('4.0.0+1'), const AppVersion(major: 4, minor: 0, patch: 0, build: 1));
    });
  });

  group('ordering', () {
    test('test_compare_semanticPartsWinBeforeBuild', () {
      final older = AppVersion.parse('3.9.9+99999');
      final newer = AppVersion.parse('4.0.0+1');

      expect(older < newer, isTrue);
      expect(newer > older, isTrue);
    });

    test('test_compare_sameSemanticVersion_usesBuildAsTieBreaker', () {
      expect(AppVersion.parse('4.0.0+5000') < AppVersion.parse('4.0.0+5001'), isTrue);
      expect(AppVersion.parse('4.0.0+5001') > AppVersion.parse('4.0.0+5000'), isTrue);
      expect(AppVersion.parse('4.0.0+5000') >= AppVersion.parse('4.0.0+5000'), isTrue);
    });

    test('test_compare_isStableAcrossOperators', () {
      final a = AppVersion.parse('4.0.0+5000');
      final b = AppVersion.parse('4.0.1+1');

      expect(a <= b && b >= a, isTrue);
      expect(a == AppVersion.parse('4.0.0+5000'), isTrue);
    });
  });

  group('Android manifest build', () {
    test('test_manifestBuildForArm64_splitPerAbiAddsTwoThousand', () {
      // Comparing the pubspec build against the manifest value would reject a good artifact.
      expect(AppVersion.manifestBuildForArm64(5000), 7000);
      expect(AppVersion.manifestBuildForArm64(5000, splitPerAbi: false), 5000);
    });
  });

  group('decideUpdate', () {
    test('test_decideUpdate_newerBuildExists_isAvailable', () {
      final decision = decideUpdate(current: AppVersion.parse('4.0.0+5000'), latest: AppVersion.parse('4.0.0+5010'));

      expect(decision.action, UpdateAction.available);
      expect(decision.shouldUpdate, isTrue);
      expect(decision.latest!.build, 5010);
    });

    test('test_decideUpdate_upToDate_isNone', () {
      final decision = decideUpdate(current: AppVersion.parse('4.0.0+5010'), latest: AppVersion.parse('4.0.0+5000'));

      expect(decision.action, UpdateAction.none);
      expect(decision.shouldUpdate, isFalse);
    });

    test('test_decideUpdate_noFeedAtAll_isNone', () {
      final decision = decideUpdate(current: AppVersion.parse('4.0.0+5000'));

      expect(decision.action, UpdateAction.none);
      expect(decision.latest, isNull);
    });

    test('test_decideUpdate_belowMinimum_isForcedEvenWithoutANewerBuild', () {
      final decision = decideUpdate(
        current: AppVersion.parse('3.0.0+1'),
        latest: AppVersion.parse('3.0.0+1'),
        minimumSupported: AppVersion.parse('4.0.0+5000'),
      );

      expect(decision.action, UpdateAction.forced);
      expect(decision.reason, contains('minimum supported'));
    });

    test('test_decideUpdate_forcedWithoutLatest_fallsBackToTheMinimum', () {
      final decision = decideUpdate(
        current: AppVersion.parse('3.0.0+1'),
        minimumSupported: AppVersion.parse('4.0.0+5000'),
      );

      expect(decision.latest, AppVersion.parse('4.0.0+5000'));
    });
  });
}
