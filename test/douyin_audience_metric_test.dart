import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/douyin/douyin_audience.dart';

void main() {
  group('Douyin concurrent audience fields', () {
    test('uses explicit room online fields', () {
      expect(
        douyinOnlineViewers({
          'user_count': 1757,
          'stats': {'total_user': 0},
        }),
        '1757',
      );
      expect(
        douyinOnlineViewers({
          'room_view_stats': {'online_user_for_anchor': 3210, 'display_value': '56万'},
        }),
        '3210',
      );
      expect(
        douyinOnlineViewers({
          'stats': {'user_count': 0, 'total_user_str': '80万+'},
        }),
        '0',
      );
    });

    test('never relabels cumulative total_user fields as concurrent viewers', () {
      expect(
        douyinOnlineViewers({
          'room_view_stats': {'display_value': '56万'},
          'stats': {'total_user': 560000, 'total_user_str': '56万+'},
        }),
        isEmpty,
      );
    });

    test('keeps cumulative and concurrent fields separate', () {
      expect(
        douyinTotalViewers({
          'room_view_stats': {'display_value': '56万', 'user_count': 3210},
        }),
        '56万',
      );
      expect(
        douyinTotalViewers({
          'user_count': 1757,
          'stats': {'total_user': 0},
        }),
        isEmpty,
      );
    });
  });
}
