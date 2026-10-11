/// Number and boolean coercion shared by every adapter.
///
/// Platform JSON is loosely typed in a way that bites silently: the same
/// field arrives as a number in one endpoint and as a string in another
/// (Huya's viewer counts), a flag arrives as `0`/`1`, `"0"`/`"1"` or a real
/// boolean, and a count arrives as `"1.2万"`. Casting with `as num?` throws
/// and takes the whole page down with it, so the coercions live here — one
/// implementation, one set of tolerances.
abstract final class SiteCounts {
  /// [value] as an integer, accepting numbers, numeric strings and strings
  /// with a decimal part; null when it is none of those.
  static int? integer(Object? value) {
    if (value is num) {
      return value.isFinite ? value.toInt() : null;
    }
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) {
        return null;
      }
      return int.tryParse(text) ?? double.tryParse(text)?.toInt();
    }
    return null;
  }

  /// [value] as a double, accepting numbers and numeric strings.
  static double? decimal(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  /// [value] as a flag: booleans, `0`/`1` in either type, and `"true"`/
  /// `"false"` all resolve; null is "the field was absent or unreadable".
  static bool? flag(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    return switch (value?.toString().trim().toLowerCase()) {
      'true' || '1' || 'yes' => true,
      'false' || '0' || 'no' || '' => false,
      _ => null,
    };
  }

  /// A Chinese-scaled count (`"1.2万"`, `"3.4亿"`, `"12"`) as an integer;
  /// null when the text carries no number at all.
  ///
  /// Several platforms display counts this way and, where the number is
  /// inside a text field, it is the only reading available — so it is
  /// parsed here rather than approximated by a regex at each call site.
  static int? scaled(Object? value) {
    final direct = integer(value);
    if (direct != null) {
      return direct;
    }
    final text = value?.toString().trim() ?? '';
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*([万亿]?)').firstMatch(text);
    if (match == null) {
      return null;
    }
    final base = double.tryParse(match.group(1)!);
    if (base == null) {
      return null;
    }
    final scale = switch (match.group(2)) {
      '万' => 10000,
      '亿' => 100000000,
      _ => 1,
    };
    return (base * scale).round();
  }
}
