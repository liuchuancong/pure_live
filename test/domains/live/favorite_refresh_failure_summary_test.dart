import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/domains/live/presentation/favorite/favorite_controller.dart';

void main() {
  group('favorite refresh failure summary', () {
    test('a pass without failures reports nothing', () {
      expect(summarizeFavoriteRefreshFailures(const <String>[]), '');
    });

    test('every failed room is named', () {
      expect(
        summarizeFavoriteRefreshFailures(const <String>['小明（douyin/1）', '小红（douyu/2）']),
        '小明（douyin/1） · 小红（douyu/2）',
      );
    });

    test('a long list is capped with a count of what was hidden', () {
      final List<String> failures = List<String>.generate(9, (int index) => 'R$index');
      final String summary = summarizeFavoriteRefreshFailures(failures);

      expect(summary, contains('R0'));
      expect(summary, contains('R5'));
      expect(summary, isNot(contains('R6')), reason: 'only the first six rooms are named');
      expect(summary, endsWith('…(+3)'));
    });
  });
}
