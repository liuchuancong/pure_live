/// Compact, human-sized number rendering for lists and cards.
///
/// The room cards and viewer counters read `audience` counts that reach
/// eight digits on busy platforms; raw digits do not fit a card.
library;

/// Renders [value] compactly: `12345` becomes `1.2万` in the CJK form and
/// `12.3K` otherwise, `120000000` becomes `1.2亿` / `120M`. Values below
/// 10000 (CJK) or 1000 pass through unchanged.
String compactCount(int value, {bool cjk = false}) {
  if (cjk) {
    if (value >= 100000000) {
      return '${_trim(value / 100000000)}亿';
    }
    if (value >= 10000) {
      return '${_trim(value / 10000)}万';
    }
    return '$value';
  }
  if (value >= 1000000) {
    return '${_trim(value / 1000000)}M';
  }
  if (value >= 1000) {
    return '${_trim(value / 1000)}K';
  }
  return '$value';
}

String _trim(double scaled) {
  final rounded = (scaled * 10).round() / 10;
  return rounded == rounded.roundToDouble() ? rounded.round().toString() : rounded.toStringAsFixed(1);
}
