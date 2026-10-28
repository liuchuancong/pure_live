import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/l10n/translations.dart' show Translations;
import 'package:pure_live/modules/hongguo/controller/hongguo_comfort.dart';

void main() {
  group('sleep timer', () {
    late DateTime now;
    late HongguoSleepTimer timer;

    setUp(() {
      now = DateTime(2026, 10, 29, 20);
      timer = HongguoSleepTimer(clock: () => now);
    });

    test('a minute timer fires at its deadline and clears itself', () {
      timer.afterMinutes(30);
      expect(timer.active, isTrue);
      expect(timer.remaining, const Duration(minutes: 30));
      expect(timer.label(Translations()), '30 分钟后');

      now = now.add(const Duration(minutes: 10));
      expect(timer.poll(), isFalse);
      expect(timer.label(Translations()), '20 分钟后');

      now = now.add(const Duration(minutes: 20));
      expect(timer.poll(), isTrue);
      expect(timer.active, isFalse);
      expect(timer.label(Translations()), '关闭定时停止');
    });

    test('an episode count decrements and stops on the last one', () {
      timer.afterEpisodes(3);
      expect(timer.label(Translations()), '再播完 3 集');

      expect(timer.episodeEnded(), isFalse);
      expect(timer.episodeEnded(), isFalse);
      expect(timer.episodeEnded(), isTrue);
      expect(timer.active, isFalse);
      expect(timer.episodeEnded(), isFalse);
    });

    test('setting one kind replaces the other', () {
      timer
        ..afterMinutes(15)
        ..afterEpisodes(2);

      expect(timer.remaining, isNull);
      expect(timer.episodesLeft, 2);
    });

    test('an episode end also honors a passed deadline', () {
      timer.afterMinutes(1);
      now = now.add(const Duration(minutes: 1));

      expect(timer.episodeEnded(), isTrue);
      expect(timer.active, isFalse);
    });
  });

  group('recovery budget', () {
    test('spends three tries with the reference delays, then stops', () {
      final budget = HongguoRecoveryBudget();

      expect(budget.delay, const Duration(seconds: 1));
      expect(budget.consume(), isTrue);
      expect(budget.delay, const Duration(milliseconds: 2500));
      expect(budget.consume(), isTrue);
      expect(budget.delay, const Duration(seconds: 5));
      expect(budget.consume(), isTrue);

      expect(budget.remaining, isFalse);
      expect(budget.delay, isNull);
      expect(budget.consume(), isFalse);
    });

    test('an explicit retry starts over', () {
      final budget = HongguoRecoveryBudget()
        ..consume()
        ..consume()
        ..consume()
        ..reset();

      expect(budget.remaining, isTrue);
      expect(budget.attempts, 0);
      expect(budget.delay, const Duration(seconds: 1));
    });
  });
}
