import 'dart:typed_data';

/// How similar the shorter of two texts is to the best-aligned part of the
/// longer one, 0–100: the "partial ratio" 3.x's similarity filter took from
/// the `fuzzywuzzy` package (1.2.0).
///
/// That package is GPL-2.0-only and cannot ship in this AGPL-3.0 app, so this
/// is an independent implementation of the same published algorithm (the one
/// of Python's fuzzywuzzy with python-Levenshtein), written to give the same
/// scores:
///
/// 1. Texts are compared as UTF-16 code units, case-sensitively. The shorter
///    text is `s1` when it is strictly shorter, otherwise `s2`.
/// 2. The candidate alignments come from one Levenshtein edit script from the
///    shorter to the longer text: after the common prefix and suffix are set
///    aside, the unit-cost edit matrix of the rest is walked back from the
///    end, preferring an equal character on the diagonal, then another step
///    in the current insert or delete run, then a substitution, then a new
///    insert, then a new delete. Every run of equal characters on that path
///    (and the common prefix) is an alignment at offset `longer index −
///    shorter index`; the end of both texts is one more.
/// 3. Each alignment picks the window of the longer text that starts at the
///    offset (at least 0) and is as long as the shorter text (cut at the
///    end). It scores `2 × LCS / (length of both)`, the indel similarity.
/// 4. A score above 0.995 answers 100 at once; otherwise the best score
///    times 100, rounded. Two empty texts score 0.
///
/// The scores were checked against fuzzywuzzy 1.2.0 on random texts (see
/// docs/D-弹幕/D01-平台弹幕协议/D01.1-弹幕框架和过滤/record.md); the package itself is not a dependency.
int partialRatio(String s1, String s2) {
  final (shorter, longer) = s1.length < s2.length ? (s1, s2) : (s2, s1);
  final a = shorter.codeUnits;
  final b = longer.codeUnits;
  var best = -1.0;
  for (final offset in _alignments(a, b)) {
    final start = offset > 0 ? offset : 0;
    final end = start + a.length < b.length ? start + a.length : b.length;
    final total = a.length + end - start;
    if (total == 0) continue;
    final ratio = (2 * _lcs(a, b, start, end)) / total;
    if (ratio > 0.995) return 100;
    if (ratio > best) best = ratio;
  }
  return best < 0 ? 0 : (100 * best).round();
}

/// Offsets (`longer index − shorter index`) of the runs of equal characters
/// on the edit path from [a] to [b], plus the end of both texts.
Set<int> _alignments(List<int> a, List<int> b) {
  final offsets = {b.length - a.length};
  var prefix = 0;
  while (prefix < a.length && prefix < b.length && a[prefix] == b[prefix]) {
    prefix++;
  }
  if (prefix > 0) offsets.add(0);
  var suffix = 0;
  while (suffix < a.length - prefix &&
      suffix < b.length - prefix &&
      a[a.length - 1 - suffix] == b[b.length - 1 - suffix]) {
    suffix++;
  }
  final rows = a.length - prefix - suffix;
  final columns = b.length - prefix - suffix;
  if (rows == 0 && columns == 0) return offsets;

  // Unit-cost edit distances between the middle parts, row-major.
  final width = columns + 1;
  final cost = Uint32List((rows + 1) * width);
  for (var j = 0; j <= columns; j++) {
    cost[j] = j;
  }
  for (var i = 1; i <= rows; i++) {
    final row = i * width;
    final above = row - width;
    final char = a[prefix + i - 1];
    cost[row] = i;
    for (var j = 1; j <= columns; j++) {
      final diagonal = cost[above + j - 1] + (char == b[prefix + j - 1] ? 0 : 1);
      final left = cost[row + j - 1] + 1;
      final up = cost[above + j] + 1;
      var value = diagonal < left ? diagonal : left;
      if (up < value) value = up;
      cost[row + j] = value;
    }
  }

  // Walk back from the end; `run` is -1 inside an insert run, 1 inside a
  // delete run, 0 otherwise.
  var i = rows;
  var j = columns;
  var run = 0;
  while (i > 0 || j > 0) {
    final here = cost[i * width + j];
    if (i > 0 && j > 0 && here == cost[(i - 1) * width + j - 1] && a[prefix + i - 1] == b[prefix + j - 1]) {
      offsets.add(j - i);
      i--;
      j--;
      run = 0;
    } else if (run < 0 && j > 0 && here == cost[i * width + j - 1] + 1) {
      j--;
    } else if (run > 0 && i > 0 && here == cost[(i - 1) * width + j] + 1) {
      i--;
    } else if (i > 0 && j > 0 && here == cost[(i - 1) * width + j - 1] + 1) {
      i--;
      j--;
      run = 0;
    } else if (run == 0 && j > 0 && here == cost[i * width + j - 1] + 1) {
      j--;
      run = -1;
    } else if (run == 0 && i > 0 && here == cost[(i - 1) * width + j] + 1) {
      i--;
      run = 1;
    } else if (run != 0) {
      // Not reachable in an edit matrix; ending the run keeps the walk finite.
      run = 0;
    } else {
      break;
    }
  }
  return offsets;
}

/// Length of the longest common subsequence of [a] and `b[start, end)`.
int _lcs(List<int> a, List<int> b, int start, int end) {
  final length = end - start;
  if (a.isEmpty || length <= 0) return 0;
  var previous = Uint32List(length + 1);
  var current = Uint32List(length + 1);
  for (final char in a) {
    for (var k = 1; k <= length; k++) {
      if (char == b[start + k - 1]) {
        current[k] = previous[k - 1] + 1;
      } else {
        current[k] = previous[k] > current[k - 1] ? previous[k] : current[k - 1];
      }
    }
    final swap = previous;
    previous = current;
    current = swap;
  }
  return previous[length];
}
