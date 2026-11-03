/// The letters an avatar shows when it has no picture.
///
/// `DsAvatar.initials` is documented as "up to two letters" and does not
/// truncate, so a caller that hands it a whole streamer name gets a clipped
/// word inside a 40-pixel circle. The two forms a room's people come in —
/// a latin name and an ideographic one — want two different readings, which is
/// what this decides in one place. Code points, not UTF-16 units, so a name
/// that opens on an astral character still hands over one whole glyph.
String avatarInitials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '';
  final runes = trimmed.runes.toList();
  final first = runes.first;
  final latin = (first >= 0x41 && first <= 0x5a) || (first >= 0x61 && first <= 0x7a);
  // An ideograph carries a whole word in one glyph: one of them is the disc.
  if (!latin) return _codePoint(runes, 0);
  // Two latin words give their two heads (「John Smith」 reads JS); one word
  // gives its first two letters, which is the only thing left to show.
  final words = trimmed.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
  if (words.length >= 2) {
    return '${_codePoint(words.first.runes.toList(), 0)}${_codePoint(words[1].runes.toList(), 0)}'.toUpperCase();
  }
  return '${_codePoint(runes, 0)}${_codePoint(runes, 1)}'.toUpperCase();
}

/// The code point at [index], or nothing past the end.
String _codePoint(List<int> runes, int index) => index >= runes.length ? '' : String.fromCharCode(runes[index]);
