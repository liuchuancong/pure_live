import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/multiview/widgets/focus_rail_visibility.dart';

void main() {
  const cells = [1, 2, 3, 4, 5, 6, 7, 8];

  test('first three small cells are visible without scrolling', () {
    expect(visibleFocusRailCells(cellIndices: cells, scrollOffset: 0, viewportExtent: 300, itemExtent: 100), [1, 2, 3]);
  });

  test('scrolling tracks partially visible cells and excludes offscreen cells', () {
    expect(visibleFocusRailCells(cellIndices: cells, scrollOffset: 150, viewportExtent: 300, itemExtent: 100), [
      2,
      3,
      4,
      5,
    ]);
    expect(visibleFocusRailCells(cellIndices: cells, scrollOffset: 600, viewportExtent: 300, itemExtent: 100), [7, 8]);
  });

  test('invalid or empty viewport does not mark a hidden player visible', () {
    expect(visibleFocusRailCells(cellIndices: cells, scrollOffset: 0, viewportExtent: 0, itemExtent: 100), isEmpty);
    expect(
      visibleFocusRailCells(cellIndices: cells, scrollOffset: double.nan, viewportExtent: 300, itemExtent: 100),
      isEmpty,
    );
  });
}
