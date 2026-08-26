import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/widgets/content_first_panel_layout.dart';

void main() {
  test('room history keeps two columns in a landscape phone half-panel', () {
    final widePhone = resolveContentFirstPanelLayout(const Size(844, 390), ContentFirstPanelKind.roomHistory);
    final compactPhone = resolveContentFirstPanelLayout(const Size(740, 360), ContentFirstPanelKind.roomHistory);

    expect(resolveRoomHistoryColumns(widePhone.size.width), 2);
    expect(resolveRoomHistoryColumns(compactPhone.size.width), 2);
  });

  test('room history retains one column when cards would become unreadable', () {
    expect(resolveRoomHistoryColumns(340), 1);
    expect(resolveRoomHistoryColumns(360), 2);
    expect(resolveRoomHistoryColumns(double.nan), 1);
  });

  test('two-column room cards fit two complete rows in the content viewport', () {
    const content = Size(414, 320);
    final height = resolveRoomHistoryCardHeight(contentSize: content, columns: 2);
    const availableForEachRow = (320 - 6 * 2 - 5) / 2;

    expect(height, lessThanOrEqualTo(availableForEachRow));
    expect(height, greaterThanOrEqualTo(96));
  });
}
