/// The number in an audience text: `5.6万` → 56000, `1.2亿`, `18.3k`, `1.5M`,
/// `2.4千`, `534，739`; 0 when there is none.
int parseAudienceNumber(String? value) {
  final text = value?.trim().toLowerCase() ?? '';
  if (text.isEmpty) return 0;
  final normalized = text.replaceAll(',', '').replaceAll('，', '');
  final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*(亿|万|千|[kwm])?').firstMatch(normalized);
  final number = double.tryParse(match?.group(1) ?? '') ?? 0;
  final multiplier = switch (match?.group(2)) {
    '亿' => 100000000,
    '万' || 'w' => 10000,
    '千' || 'k' => 1000,
    'm' => 1000000,
    _ => 1,
  };
  return (number * multiplier).round();
}

/// Whether [value] is a measured, positive audience number.
bool hasAudienceValue(String? value) {
  final text = value?.trim() ?? '';
  return text.isNotEmpty && text != 'null' && parseAudienceNumber(text) > 0;
}

/// Whether [value] carries any digit, zero included (an explicit count).
bool hasExplicitAudienceValue(String? value) {
  final text = value?.trim() ?? '';
  return text.isNotEmpty && text != 'null' && RegExp('[0-9]').hasMatch(text);
}
