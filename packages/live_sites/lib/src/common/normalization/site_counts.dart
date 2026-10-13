/// Parsing of the audience-figure texts platforms send
/// (`"1.2万"`, `"3,400"`, `"8000万"`, bare numbers).
///
/// Adapters call these at the response boundary and store `int?`; the text
/// itself is never stored (MODELS.md §1.3). UI formatting ("1.2万") lives in
/// the application layer.
library;

final RegExp _countPattern = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*(亿|万|千|[kwm])?');

/// Parses a platform count text into an absolute number; `0` when [value]
/// carries no number at all.
int parseAudienceNumber(String? value) => parseAudienceNumberOrNull(value) ?? 0;

/// Parses a platform count text into an absolute number; `null` when [value]
/// carries no number at all (null = unknown, never a fabricated zero).
int? parseAudienceNumberOrNull(String? value) {
  final text = value?.trim().toLowerCase() ?? '';
  if (text.isEmpty) return null;
  final normalized = text.replaceAll(',', '').replaceAll('，', '');
  final match = _countPattern.firstMatch(normalized);
  final number = double.tryParse(match?.group(1) ?? '');
  if (number == null) return null;
  const multipliers = {'亿': 100000000, '万': 10000, 'w': 10000, '千': 1000, 'k': 1000, 'm': 1000000};
  final multiplier = multipliers[match?.group(2)] ?? 1;
  return (number * multiplier).round();
}

/// Whether [value] holds a positive audience figure (not blank, not `null`,
/// not zero).
bool hasAudienceValue(String? value) => (parseAudienceNumberOrNull(value) ?? 0) > 0;

/// Whether [value] carries an explicit figure at all — positive or zero.
/// A room that truly has nobody online must stay distinguishable from a room
/// whose count the source did not report.
bool hasExplicitAudienceValue(String? value) => value != null && RegExp('[0-9]').hasMatch(value.trim());
