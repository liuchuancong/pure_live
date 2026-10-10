// Module: lib/src/domain/search_term.dart
// Purpose: The one normalised form of what the user typed, shared by history, ranking and the aggregator.
// Author: liuchuancong
// Created: 2026-10-10
//
// Without one spelling of "the same query", the four apps in this repository disagree in four different
// ways: one keeps leading spaces, another compares case-sensitively, and a full-width keyword a user pasted
// from a Bilibili title becomes a second history row for the same search. The fold rule lives here so a
// change to it is one commit, not four.
//
// [display] is what the user wrote and what the field shows. Folding only ever produces [matchKey]; showing
// a folded string back would turn "范伟" into itself but "ABCD" into "abcd", which is not what was typed.

import 'package:pure_live_utils/pure_live_utils.dart';

/// A search keyword, kept both as typed and as the key it is compared by.
final class SearchTerm with ValueEquality {
  const SearchTerm._(this.display, this.matchKey);

  /// The term for [raw], or null when it carries nothing to search for.
  ///
  /// Blank means empty after folding, so a submit of spaces or of a stray full-width space is refused before
  /// it can become N pointless requests - the rule the aggregator also enforces, one layer earlier here.
  static SearchTerm? tryParse(String raw) {
    final key = normalizeToken(raw);
    if (key.isEmpty) {
      return null;
    }
    return SearchTerm._(raw.trim(), key);
  }

  /// The term as the user wrote it, trimmed of outer whitespace only.
  final String display;

  /// The folded form used for comparison, storage keys and ranking.
  final String matchKey;

  /// True when both terms would produce the same result set for the same sources.
  bool sameQuery(SearchTerm other) => matchKey == other.matchKey;

  @override
  List<Object?> get equalityFields => <Object?>[matchKey];

  @override
  String toString() => 'SearchTerm($display)';
}
