// Module: lib/src/data/stored_search_history.dart
// Purpose: The kv-backed history: bounded, deduplicated by the folded term, stored as one typed preference.
// Author: liuchuancong
// Created: 2026-10-10
//
// Two rules the older version of this file did not hold, both of which show up only on a user's device weeks
// later:
//
// 1. The stored blob carried no format version. Adding a timestamp to an entry is a shape change, and without
//    the marker a new build reads an old list as if it were new and finds no `at` field.
// 2. A corrupt row was healed silently. The list came back empty and nobody could tell corruption from "this
//    user has never searched", which is the difference between a bug report and a shrug.
//
// A history is a preference of the user's, not a cache: it is never re-derivable from a server, so an
// unreadable row means losing what they typed, and the loss has to be reported.
//
// The envelope, namespace, codec gate and rejection accounting are pure_live_storage's `PreferencesStore` - the
// same mechanism features/home now uses. This file keeps what is about histories: the bound, the folded-term
// dedup, the ordering rule, and the two older row shapes that predate the envelope.

import 'dart:convert';

import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

import '../domain/search_history.dart';
import '../domain/search_term.dart';

/// The document version this writer produces, carried inside the stored value.
///
/// Separate from the mechanism's envelope version: the envelope says "a typed preference row", this says "an
/// entry list whose rows carry timestamps". A row from a newer build is refused rather than half-read.
const int kSearchHistoryEnvelopeVersion = 1;

/// The key inside the namespace, kept as it was before the mechanism so rows on disk are rows we read.
const String kSearchHistoryPreferenceName = 'history';

/// Thrown for a construction the caller cannot recover from, such as a zero-size history.
final class SearchHistoryConfigurationFailure extends DomainFailure {
  const SearchHistoryConfigurationFailure(super.reason);
}

/// A read that did not produce a usable list, reported rather than swallowed.
final class SearchHistoryReadFailure extends DomainFailure {
  const SearchHistoryReadFailure(super.reason, {super.cause});
}

/// A [SearchHistoryRepository] over one namespaced preference key.
final class StoredSearchHistory implements SearchHistoryRepository {
  StoredSearchHistory({
    required KeyValueStore store,
    this.namespace = 'search',
    this.maxLength = 20,
    Clock? clock,
    this.onReadFailure,
  }) : _clock = clock ?? systemClock {
    if (maxLength < 1) {
      throw SearchHistoryConfigurationFailure('maxLength must be at least 1, got $maxLength');
    }
    _preferences = PreferencesStore(store: store, namespace: '$namespace.');
  }

  static final PreferenceCodec<List<SearchHistoryEntry>> _codec = PreferenceCodec.of<List<SearchHistoryEntry>>(
    'searchHistory',
    _decodeDocument,
    (List<SearchHistoryEntry> entries) => <String, Object?>{
      'v': kSearchHistoryEnvelopeVersion,
      'items': <Object?>[
        for (final entry in entries)
          <String, Object?>{'q': entry.term.display, 'at': Timestamps.toMilliseconds(entry.usedAt)},
      ],
    },
  );

  static final PreferenceKey<List<SearchHistoryEntry>> _key = PreferenceKey<List<SearchHistoryEntry>>(
    name: kSearchHistoryPreferenceName,
    codec: _codec,
    defaultValue: <SearchHistoryEntry>[],
    upgrade: _readLegacyRow,
  );

  late final PreferencesStore _preferences;
  final Clock _clock;

  /// Which app's history this is. Two apps sharing one store must not share one list: a user's live-stream
  /// keywords are not their music keywords, and merging them makes every list worse.
  final String namespace;

  /// Entries kept; the least recently used is dropped first.
  final int maxLength;

  /// Notified whenever a stored row was unreadable and the list had to start empty.
  final void Function(SearchHistoryReadFailure failure)? onReadFailure;

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
    // Dedup by the folded key, keep the newest display spelling: a user who typed "ABCD" then "abcd" gets one
    // row, and it shows the way they most recently chose to write it.
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
    await _preferences.reset(_key);
  }

  /// Closes the change stream of the store this repository creates. The history itself is durable.
  Future<void> dispose() => _preferences.dispose();

  Future<List<SearchHistoryEntry>> _load() async {
    final cached = _cache;
    if (cached != null) {
      return cached;
    }
    final rejectionsBefore = _preferences.rejections.length;
    final stored = await _preferences.readIfStored(_key);
    if (stored != null) {
      _cache = stored;
      return stored;
    }
    if (_preferences.rejections.length > rejectionsBefore) {
      final rejection = _preferences.rejections.last;
      _reportReadFailure('stored row was unusable: ${rejection.reason ?? rejection.failure.name}');
    }
    _cache = const <SearchHistoryEntry>[];
    return _cache!;
  }

  Future<void> _save() async {
    final entries = _cache ?? const <SearchHistoryEntry>[];
    final kept = _order(entries).take(maxLength).toList(growable: false);
    _cache = kept;
    await _preferences.write(_key, kept);
  }

  /// The pre-mechanism row: this file wrote its envelope as a JSON string under the same key.
  ///
  /// Handing the decoded object to the codec keeps the version and field rules in one place instead of two
  /// readers, and it is what keeps both older shapes alive: the bare keyword list of version 0, and the
  /// versioned object that came after it.
  static Object? _readLegacyRow(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  static List<SearchHistoryEntry>? _decodeDocument(Object? raw) {
    // Version 0 was a bare list of keyword strings, written before an entry carried a timestamp.
    if (raw is List) {
      return <SearchHistoryEntry>[
        for (final item in raw)
          if (SearchTerm.tryParse('$item') case final term?)
            // An unknown age sorts last, and "unknown" is spelled here as the epoch rather than as null so the
            // ordering rule stays one comparator instead of a special case per reader.
            SearchHistoryEntry(term: term, usedAt: DateTime.utc(1970)),
      ];
    }

    final document = jsonMapFrom(raw);
    if (document == null) {
      return null;
    }
    final version = intFrom(document['v']) ?? 0;
    if (version > kSearchHistoryEnvelopeVersion) {
      // Written by a newer build (a downgraded apk, two apps on one database). Reading it anyway would rewrite
      // fields this build does not understand, so the row is refused and stays as it is. The reason is thrown
      // rather than folded into "unreadable" because the two refusals have different fixes.
      throw PreferenceDecodeReject('stored envelope version $version is newer than $kSearchHistoryEnvelopeVersion');
    }
    final items = listFrom(document['items']);
    if (items == null) {
      throw const PreferenceDecodeReject('envelope has no item list');
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
