// Module: lib/src/data/stored_search_history.dart
// Purpose: The kv-backed history: bounded, deduplicated by the folded term, and versioned on disk.
// Author: liuchuancong
// Created: 2026-10-10
//
// Two rules the older version of this file did not hold, both of which show up only on a user's device
// weeks later:
//
// 1. The stored blob carried no format version. Adding a timestamp to an entry is a shape change, and
//    without the marker a new build reads an old list as if it were new and finds no `at` field.
// 2. A corrupt row was healed silently. The list came back empty and nobody could tell corruption from
//    "this user has never searched", which is the difference between a bug report and a shrug.
//
// A history is a preference of the user's, not a cache: it is never re-derivable from a server, so an
// unreadable row means losing what they typed, and the loss has to be reported.

import 'dart:convert';

import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

import '../domain/search_history.dart';
import '../domain/search_term.dart';

/// The envelope version this writer produces.
const int kSearchHistoryEnvelopeVersion = 1;

/// Thrown for a construction the caller cannot recover from, such as a zero-size history.
final class SearchHistoryConfigurationFailure extends DomainFailure {
  const SearchHistoryConfigurationFailure(super.reason);
}

/// A read that did not produce a usable list, reported rather than swallowed.
final class SearchHistoryReadFailure extends DomainFailure {
  const SearchHistoryReadFailure(super.reason, {super.cause});
}

/// A [SearchHistoryRepository] over one namespaced [KeyValueStore].
final class StoredSearchHistory implements SearchHistoryRepository {
  StoredSearchHistory({
    required KeyValueStore store,
    this.namespace = 'search',
    this.maxLength = 20,
    Clock? clock,
    this.onReadFailure,
  }) : _store = store,
       _clock = clock ?? systemClock {
    if (maxLength < 1) {
      throw SearchHistoryConfigurationFailure('maxLength must be at least 1, got $maxLength');
    }
  }

  static const String _suffix = '.history';

  final KeyValueStore _store;
  final Clock _clock;

  /// Which app's history this is. Two apps sharing one store must not share one list: a user's live-stream
  /// keywords are not their music keywords, and merging them makes every list worse.
  final String namespace;

  /// Entries kept; the least recently used is dropped first.
  final int maxLength;

  /// Notified whenever a stored row was unreadable and the list had to start empty.
  final void Function(SearchHistoryReadFailure failure)? onReadFailure;

  String get _key => '$namespace$_suffix';

  List<SearchHistoryEntry>? _cache;

  @override
  Future<List<SearchHistoryEntry>> recent({int? limit}) async {
    final entries = await _load();
    final ordered = _order(entries);
    if (limit == null || limit >= ordered.length) {
      return ordered;
    }
    // A negative limit is a caller bug, not an empty request: the UI cannot mean "give me minus three".
    return ordered.take(requireInRange(limit, lower: 0, upper: ordered.length, name: 'limit')).toList();
  }

  @override
  Future<List<SearchHistoryEntry>> record(SearchTerm term) async {
    final entries = await _load();
    // Dedup by the folded key, keep the newest display spelling: a user who typed "ABCD" then "abcd" gets
    // one row, and it shows the way they most recently chose to write it.
    final kept = <SearchHistoryEntry>[
      for (final entry in entries)
        if (!entry.term.sameQuery(term)) entry,
    ];
    kept.add(SearchHistoryEntry(term: term, usedAt: _clock()));
    _cache = kept;
    await _save();
    return _order(kept);
  }

  @override
  Future<void> remove(SearchTerm term) async {
    final entries = await _load();
    _cache = <SearchHistoryEntry>[
      for (final entry in entries)
        if (!entry.term.sameQuery(term)) entry,
    ];
    await _save();
  }

  @override
  Future<void> clear() async {
    _cache = <SearchHistoryEntry>[];
    await _store.remove(_key);
  }

  Future<List<SearchHistoryEntry>> _load() async {
    final cached = _cache;
    if (cached != null) {
      return cached;
    }
    final loaded = <SearchHistoryEntry>[];
    final raw = await _store.read(_key);
    if (raw != null) {
      final decoded = _decode(raw);
      if (decoded != null) {
        loaded.addAll(decoded);
      }
    }
    _cache = loaded;
    return loaded;
  }

  /// The stored row turned into entries, or null when it could not be read.
  ///
  /// A null result is accompanied by the report the caller asked for and a next write that stores the new
  /// envelope, so one bad row does not outlive itself.
  List<SearchHistoryEntry>? _decode(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      _reportReadFailure('stored value is not text', cause: raw.runtimeType);
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      _reportReadFailure('stored row is not json', cause: error);
      return null;
    }

    // Version 0 was a bare list of keyword strings, written before an entry carried a timestamp.
    if (decoded is List) {
      return <SearchHistoryEntry>[
        for (final item in decoded)
          if (SearchTerm.tryParse('$item') case final term?)
            // An unknown age sorts last, and "unknown" is spelled here as the epoch rather than as null so
            // the ordering rule stays one comparator instead of a special case per reader.
            SearchHistoryEntry(term: term, usedAt: DateTime.utc(1970)),
      ];
    }

    final envelope = jsonMapFrom(decoded);
    if (envelope == null) {
      _reportReadFailure('stored row is not an object');
      return null;
    }
    final version = intFrom(envelope['v']) ?? 0;
    if (version > kSearchHistoryEnvelopeVersion) {
      // Written by a newer build (a downgraded apk, two apps on one database). Reading it anyway would
      // rewrite fields this build does not understand, so the list comes back empty and the row stays.
      _reportReadFailure('stored envelope version $version is newer than $kSearchHistoryEnvelopeVersion');
      return null;
    }
    final items = listFrom(envelope['items']);
    if (items == null) {
      _reportReadFailure('envelope has no item list');
      return null;
    }
    final entries = <SearchHistoryEntry>[];
    for (final item in items) {
      final row = jsonMapFrom(item);
      if (row == null) {
        continue;
      }
      final term = SearchTerm.tryParse(stringFrom(row['q']));
      if (term == null) {
        continue;
      }
      entries.add(SearchHistoryEntry(term: term, usedAt: Timestamps.fromMilliseconds(intFrom(row['at']) ?? 0)));
    }
    return entries;
  }

  Future<void> _save() async {
    final entries = _cache ?? const <SearchHistoryEntry>[];
    final kept = _order(entries).take(maxLength).toList(growable: false);
    _cache = kept;
    await _store.write(
      _key,
      jsonEncode(<String, Object?>{
        'v': kSearchHistoryEnvelopeVersion,
        'items': <Object?>[
          for (final entry in kept)
            <String, Object?>{'q': entry.term.display, 'at': Timestamps.toMilliseconds(entry.usedAt)},
        ],
      }),
    );
  }

  /// Newest first, and an equal timestamp broken by the folded term so two readers agree.
  List<SearchHistoryEntry> _order(List<SearchHistoryEntry> entries) {
    final sorted = List<SearchHistoryEntry>.of(entries);
    sorted.sort((left, right) {
      final byTime = right.usedAt.compareTo(left.usedAt);
      return byTime != 0 ? byTime : left.term.matchKey.compareTo(right.term.matchKey);
    });
    return sorted;
  }

  void _reportReadFailure(String reason, {Object? cause}) {
    onReadFailure?.call(SearchHistoryReadFailure('history under "$namespace" was unreadable: $reason', cause: cause));
  }
}
