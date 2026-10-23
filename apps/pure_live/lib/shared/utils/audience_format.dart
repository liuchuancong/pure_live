/// Audience figures as the Chinese web reads them: `1.2万`, `3.4亿`,
/// bare under ten thousand, and nothing at all for an unknown count.
extension AudienceFormat on int {
  /// The display text of this figure; an empty string when null.
  static String format(int? value) {
    final figure = value;
    if (figure == null || figure < 0) return '';
    if (figure >= 100000000) {
      final yi = figure / 100000000;
      return '${_trim(yi)}亿';
    }
    if (figure >= 10000) {
      final wan = figure / 10000;
      return '${_trim(wan)}万';
    }
    return '$figure';
  }

  static String _trim(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
}
