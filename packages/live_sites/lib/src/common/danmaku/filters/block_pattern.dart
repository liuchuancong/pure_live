/// Why a block word written as a pattern (`/…/`) is not taken (D02.2 c1).
enum DanmakuBlockPatternProblem {
  /// Longer than [DanmakuBlockPattern.maxLength], slashes included.
  tooLong,

  /// It does not compile.
  invalid,

  /// A group repeated as a whole that itself repeats something or has
  /// alternatives (`(a+)+`, `(a|ab)*`, `(.*x){5}`): such a pattern can take
  /// exponential time on a text that almost matches.
  nestedRepeat,

  /// It took too long on the test texts ([DanmakuBlockPattern.check]).
  tooSlow,
}

/// Block words written as regular expressions (D02.2 c1, V03.6 §5.6 A): a
/// stored block word that starts and ends with `/` is the pattern between
/// the slashes, matched without regard to case; every other word still
/// blocks the messages that contain it (3.x). The block list keeps its one
/// table and its format: a pattern is a word like any other there, and 3.x
/// reads it back as a plain word.
///
/// Dart's [RegExp] cannot be stopped once it runs, and the filter runs on
/// the UI isolate for every chat message, so a slow pattern would freeze
/// the room. The guards, cheapest first:
///
/// 1. a pattern is at most [maxLength] characters, and only the first
///    [matchedLength] characters of a message are matched with it;
/// 2. a repeated group may not hold a repeat or alternatives
///    ([DanmakuBlockPatternProblem.nestedRepeat]): the patterns whose time
///    grows exponentially with the text;
/// 3. a pattern is compiled once, when the list is built, never per
///    message;
/// 4. when a word is added by hand, [check] also times the pattern on texts
///    of growing length made of its own characters and refuses it when one
///    run takes over [probeBudget] (the polynomial cases such as
///    `.*.*.*.*x`); the growth in steps keeps the add itself short.
///
/// Rules 1–3 also hold for words that arrive from a backup, an import or
/// another device; rule 4 runs only where a person adds the word.
abstract final class DanmakuBlockPattern {
  /// The longest pattern, slashes included (a plain word stays at 40, 3.x).
  static const int maxLength = 200;

  /// How much of a message a pattern looks at.
  static const int matchedLength = 200;

  /// The longest a single test run of [check] may take.
  static const Duration probeBudget = Duration(milliseconds: 2);

  /// Whether [keyword] is a pattern: `/…/` with something between.
  static bool isPattern(String keyword) {
    final text = keyword.trim();
    return text.length > 2 && text.startsWith('/') && text.endsWith('/');
  }

  /// The pattern of [keyword] compiled, or null when it is not a pattern or
  /// breaks rule 1 or 2 or does not compile (never throws).
  static RegExp? compile(String keyword) {
    final text = keyword.trim();
    if (!isPattern(text) || text.length > maxLength) return null;
    final source = text.substring(1, text.length - 1);
    if (_nestedRepeat(source)) return null;
    try {
      return RegExp(source, caseSensitive: false);
    } on FormatException {
      return null;
    }
  }

  /// What is wrong with [keyword] as a pattern; null for a plain word or a
  /// pattern the list takes. Runs the timed test of rule 4 (well under a
  /// second even for a pattern it refuses).
  static DanmakuBlockPatternProblem? check(String keyword) {
    final text = keyword.trim();
    if (!isPattern(text)) return null;
    if (text.length > maxLength) return DanmakuBlockPatternProblem.tooLong;
    final source = text.substring(1, text.length - 1);
    final RegExp pattern;
    try {
      pattern = RegExp(source, caseSensitive: false);
    } on FormatException {
      return DanmakuBlockPatternProblem.invalid;
    }
    if (_nestedRepeat(source)) return DanmakuBlockPatternProblem.nestedRepeat;
    return _slow(pattern, source) ? DanmakuBlockPatternProblem.tooSlow : null;
  }

  /// The part of [text] a pattern looks at.
  static String matchedPart(String text) => text.length <= matchedLength ? text : text.substring(0, matchedLength);

  static const String _special = r'\^$.|?*+()[]{}/';

  /// The quantifier at [start] of [source]: its length and whether it
  /// repeats (more than once); null when there is none (`{` that does not
  /// start a count is a plain character, as in JavaScript).
  static (int, bool)? _quantifier(String source, int start) {
    switch (source[start]) {
      case '*' || '+':
        return (1, true);
      case '?':
        return (1, false);
      case '{':
        final match = _count.matchAsPrefix(source, start);
        if (match == null) return null;
        final low = int.parse(match[1]!);
        final repeats = match[2] == null ? low > 1 : (match[3]!.isEmpty || int.parse(match[3]!) > 1);
        return (match[0]!.length, repeats);
    }
    return null;
  }

  static final RegExp _count = RegExp(r'\{(\d+)(,(\d*))?\}');

  /// Rule 2: a group repeated as a whole holds a repeat or a `|`.
  static bool _nestedRepeat(String source) {
    // Per open group (the whole pattern first): it holds a repeat; it holds
    // alternatives.
    final repeats = <bool>[false];
    final alternatives = <bool>[false];
    // The group that closed just before, when the last atom was one.
    (bool, bool)? closed;
    var i = 0;
    while (i < source.length) {
      final char = source[i];
      if (_quantifier(source, i) case (final length, final repeated)) {
        if (repeated) {
          if (closed case (final innerRepeats, final innerAlternatives) when innerRepeats || innerAlternatives) {
            return true;
          }
          repeats.last = true;
        }
        i += length;
        // A lazy quantifier (`+?`).
        if (i < source.length && source[i] == '?') i++;
        closed = null;
        continue;
      }
      closed = null;
      switch (char) {
        case r'\':
          i += 2;
        case '[':
          i++;
          if (i < source.length && source[i] == '^') i++;
          while (i < source.length && source[i] != ']') {
            if (source[i] == r'\') i++;
            i++;
          }
          i++;
        case '(':
          repeats.add(false);
          alternatives.add(false);
          i++;
          // `(?:`, `(?=`, `(?!`, `(?<=`, `(?<!`, `(?<name>`.
          if (i < source.length && source[i] == '?') {
            i++;
            if (i < source.length && source[i] == '<') {
              i++;
              if (i < source.length && (source[i] == '=' || source[i] == '!')) {
                i++;
              } else {
                while (i < source.length && source[i] != '>') {
                  i++;
                }
                i++;
              }
            } else {
              i++;
            }
          }
        case ')':
          i++;
          if (repeats.length == 1) continue;
          final inner = (repeats.removeLast(), alternatives.removeLast());
          // What a group holds, the group around it holds too.
          if (inner.$1) repeats.last = true;
          if (inner.$2) alternatives.last = true;
          closed = inner;
        case '|':
          alternatives.last = true;
          i++;
        default:
          i++;
      }
    }
    return false;
  }

  /// Rule 4: one run on a text made of the pattern's own characters (or a
  /// few common ones), ending in one that hardly matches anything, takes
  /// over [probeBudget]; texts grow by half each step up to
  /// [matchedLength], and the first slow run ends the test.
  static bool _slow(RegExp pattern, String source) {
    final fills = <String>{'a', '1', '哈', ' '};
    for (var i = 0; i < source.length && fills.length < 10; i++) {
      final char = source[i];
      if (char == r'\') {
        i++;
        continue;
      }
      if (!_special.contains(char)) fills.add(char);
    }
    // The first run compiles the pattern.
    pattern.hasMatch('a');
    final watch = Stopwatch();
    Duration run(String text) {
      watch
        ..reset()
        ..start();
      pattern.hasMatch(text);
      watch.stop();
      return watch.elapsed;
    }

    for (final fill in fills) {
      for (final length in const [8, 12, 18, 27, 40, 60, 90, 135, matchedLength]) {
        final text = '${fill * (length - 1)}\u0001';
        final first = run(text);
        if (first <= probeBudget) continue;
        // Once more before refusing a run just over the budget: a pause of
        // the collector is not the pattern's.
        if (first > probeBudget * 10 || run(text) > probeBudget) return true;
      }
    }
    return false;
  }
}
