// Module: test/domain/epg_window_test.dart
// Purpose: Pins the countdown rounding and the reporting of guide data that disagrees with itself.
// Author: liuchuancong
// Created: 2026-10-10

import 'package:pure_live_iptv_feature/pure_live_iptv_feature.dart';
import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

DateTime _at(int hour, int minute) => DateTime.utc(2026, 10, 10, hour, minute);

final List<EpgProgramme> _schedule = <EpgProgramme>[
  EpgProgramme(title: '新闻', startsAt: _at(19, 0), endsAt: _at(19, 30)),
  EpgProgramme(title: '剧场', startsAt: _at(19, 30), endsAt: _at(21, 0)),
  EpgProgramme(title: '深夜档', startsAt: _at(21, 30), endsAt: _at(23, 0)),
];

void main() {
  test('test_epgWindow_reportsWhatIsOnAndWhatComesNext', () {
    final window = windowFrom(_schedule, at: _at(20, 0));

    expect(window.nowTitle, '剧场');
    expect(window.nextTitle, '深夜档');
    expect(window.hasNow, isTrue);
    expect(window.hasNext, isTrue);
  });

  test('test_epgWindow_remainingMinutesRoundUpSoACountdownNeverPrematurelyHitsZero', () {
    final window = EpgWindow(nowTitle: 'x', nowEndsAt: _at(20, 0).add(const Duration(seconds: 10)));

    expect(window.minutesRemaining(_at(20, 0)), 1, reason: 'ten seconds left is not "0 min"');
    expect(window.minutesRemaining(_at(19, 59)), 2, reason: '70 seconds rounds up, never down');
    expect(window.secondsRemaining(_at(20, 0)), 10);
  });

  test('test_epgWindow_pastTheEndIsZeroNotNegative', () {
    final window = EpgWindow(nowTitle: 'x', nowEndsAt: _at(19, 0));

    expect(window.minutesRemaining(_at(20, 0)), 0);
    expect(window.secondsRemaining(_at(20, 0)), 0);
  });

  test('test_epgWindow_noEndMeansNoCountdown', () {
    final window = const EpgWindow(nowTitle: 'x');

    expect(window.minutesRemaining(_at(20, 0)), isNull);
    expect(window.secondsRemaining(_at(20, 0)), isNull);
    expect(window.hasNow, isTrue);
  });

  test('test_epgWindow_nextProgrammeStartingEarlyIsExposedNotClipped', () {
    final window = EpgWindow(nowTitle: 'a', nowEndsAt: _at(20, 0), nextTitle: 'b', nextStartsAt: _at(19, 45));

    expect(window.isOverlappingGuide, isTrue);
    expect(window.hasGapBeforeNext, isFalse);
  });

  test('test_epgWindow_gapBetweenEntriesIsNamed', () {
    final window = EpgWindow(nowTitle: 'a', nowEndsAt: _at(20, 0), nextTitle: 'b', nextStartsAt: _at(20, 30));

    expect(window.hasGapBeforeNext, isTrue);
    expect(window.isOverlappingGuide, isFalse);
  });

  test('test_windowFrom_afterTheLastEntrySaysTheGuideIsStale', () {
    final failures = <DomainFailure>[];
    final window = windowFrom(_schedule, at: _at(23, 30), onInconsistentData: failures.add);

    expect(window.hasNow, isFalse);
    expect(failures.single.reason, contains('already ended'));
  });

  test('test_windowFrom_theLastEntryHasNoNext', () {
    final window = windowFrom(_schedule, at: _at(22, 0));

    expect(window.nowTitle, '深夜档');
    expect(window.hasNext, isFalse);
    expect(window.nextTitle, isNull);
  });

  test('test_windowFrom_emptyGuideIsUnknown', () {
    expect(windowFrom(const <EpgProgramme>[], at: _at(20, 0)), EpgWindow.unknown);
  });

  test('test_epgWindow_equalityIsByContent', () {
    final a = EpgWindow(nowTitle: 'x', nowEndsAt: _at(20, 0));

    expect(a, EpgWindow(nowTitle: 'x', nowEndsAt: _at(20, 0)));
    expect(a == EpgWindow(nowTitle: 'y', nowEndsAt: _at(20, 0)), isFalse);
  });
}
