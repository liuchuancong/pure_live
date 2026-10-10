// Module: lib/src/strings/string_truncator.dart
// Purpose: Shortening text that a person wrote, where cutting at a code unit boundary is a visible defect.
// Author: liuchuancong
// Created: 2026-10-10
//
// Titles on this platform are CJK, emoji and Latin mixed. A naive substring can split a surrogate pair and
// render tofu, or cut a word in half mid-syllable. The strategies below are named so a caller states which
// compromise it is making instead of inheriting one.

/// How a shortened string reaches its limit.
enum TruncateMode {
  /// Cut at exactly the limit, splitting whatever grapheme sits there.
  hard,

  /// Cut at the last word boundary at or before the limit.
  word,

  /// Cut at the last grapheme boundary at or before the limit, so no character is torn in half.
  grapheme,
}

/// Truncation with an explicit strategy. See [TruncateMode] for what each mode gives up.
final class Truncator {
  const Truncator._();

  /// Shortens [value] to at most [limit] characters, including [ellipsis].
  ///
  /// [limit] counts UTF-16 code units, matching [String.length] and therefore every width constraint a
  /// widget expresses in characters.
  static String at(String value, int limit, {String ellipsis = '…', TruncateMode mode = TruncateMode.grapheme}) {
    if (limit <= 0 || value.length <= limit) {
      return value;
    }
    final budget = limit - ellipsis.length;
    if (budget <= 0) {
      return value.substring(0, limit);
    }
    final cut = switch (mode) {
      TruncateMode.hard => budget,
      TruncateMode.word => _wordBoundary(value, budget),
      TruncateMode.grapheme => _graphemeBoundary(value, budget),
    };
    final head = value.substring(0, cut);
    return head.trimRight() + ellipsis;
  }

  static int _wordBoundary(String value, int budget) {
    for (var index = budget; index > 0; index--) {
      if (_isBoundary(value, index)) {
        return index;
      }
    }
    return budget;
  }

  static int _graphemeBoundary(String value, int budget) {
    var index = budget;
    // A lone surrogate in the high range means the pair straddles the cut; step back to its start.
    while (index > 0 && _isLowSurrogate(value, index)) {
      index--;
    }
    return index;
  }

  static bool _isBoundary(String value, int index) {
    final previous = value.codeUnitAt(index - 1);
    final current = value.codeUnitAt(index);
    if (_isWhitespace(previous) || _isWhitespace(current)) {
      return true;
    }
    // CJK has no spaces between words, so a boundary between a Han run and a different script counts.
    return _isCjk(previous) != _isCjk(current);
  }

  static bool _isLowSurrogate(String value, int index) {
    if (index <= 0 || index >= value.length) {
      return false;
    }
    final code = value.codeUnitAt(index);
    return code >= 0xDC00 && code <= 0xDFFF;
  }

  static bool _isWhitespace(int codeUnit) =>
      codeUnit == 0x20 || codeUnit == 0x09 || codeUnit == 0x0A || codeUnit == 0x0D || codeUnit == 0x3000;

  static bool _isCjk(int codeUnit) =>
      (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) ||
      (codeUnit >= 0x3040 && codeUnit <= 0x30FF) ||
      (codeUnit >= 0xAC00 && codeUnit <= 0xD7AF);
}
