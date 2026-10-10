// Module: lib/src/domain/search_history.dart
// Purpose: What a search domain owes its callers about recent queries, without saying where they are kept.
// Author: liuchuancong
// Created: 2026-10-10
//
// The interface exists so the presentation layer can be written against a rule instead of a file: an app
// that keeps history in a database, or per-account, or not at all, substitutes a different implementation
// and keeps the same ordering contract. That contract is stated here once, in the words the UI also uses.

import 'search_term.dart';

/// One recorded query and when it was last used.
final class SearchHistoryEntry {
  const SearchHistoryEntry({required this.term, required this.usedAt});

  final SearchTerm term;

  /// UTC, from the injected clock of whoever recorded it.
  final DateTime usedAt;

  @override
  String toString() => 'SearchHistoryEntry(${term.display} @ $usedAt)';
}

/// The recent-keyword list.
abstract interface class SearchHistoryRepository {
  /// Most recently used first, at most [limit] entries (all of them when null).
  ///
  /// Ordering is a contract, not a side effect of storage: newest first, and an equal timestamp broken by
  /// [SearchTerm.matchKey] so two apps reading the same data render the same list.
  Future<List<SearchHistoryEntry>> recent({int? limit});

  /// Records [term] as used now and returns the list that results.
  ///
  /// Re-recording a term moves it to the front rather than adding a second row; the fold in [SearchTerm] is
  /// what makes "the same term" mean the same thing across apps.
  Future<List<SearchHistoryEntry>> record(SearchTerm term);

  /// Drops every entry for [term].
  Future<void> remove(SearchTerm term);

  /// Empties the list.
  Future<void> clear();
}
