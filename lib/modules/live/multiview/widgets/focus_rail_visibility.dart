import 'dart:math' as math;

/// Returns only cells with some visible area in the focus layout's small rail.
/// The add-cell slot may follow [cellIndices] but has no player to monitor.
List<int> visibleFocusRailCells({
  required List<int> cellIndices,
  required double scrollOffset,
  required double viewportExtent,
  required double itemExtent,
}) {
  if (cellIndices.isEmpty ||
      !scrollOffset.isFinite ||
      !viewportExtent.isFinite ||
      !itemExtent.isFinite ||
      viewportExtent <= 0 ||
      itemExtent <= 0) {
    return const [];
  }
  final offset = math.max(0.0, scrollOffset);
  final first = (offset / itemExtent).floor().clamp(0, cellIndices.length);
  final end = ((offset + viewportExtent) / itemExtent).ceil().clamp(first, cellIndices.length);
  return List<int>.unmodifiable(cellIndices.sublist(first, end));
}
