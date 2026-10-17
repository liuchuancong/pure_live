import 'package:live_storage/live_storage.dart';

/// Where the search history persists (`search_history_store.dart` follows the
/// appearance documents' convention: one box per feature, one versioned key
/// per document, a failed read degrading to the empty list — never a crash).
abstract final class SearchHistoryKeys {
  /// The box every search preference document lives in (`settings.search`).
  static const String box = 'settings.search';

  /// The search-history list key; versioned like the appearance document keys,
  /// so a reshaped list migrates by key instead of corrupting in place.
  static const String document = 'search.history.v1';

  /// The most recent searches kept; older ones fall off, like the watch
  /// history's capacity.
  static const int capacity = 12;
}

/// The user's recent searches, most recent first, persisted as one string
/// list through the live_storage keyed family (the shield lists' storage
/// shape — a keyword list needs no more than that).
///
/// Reading is synchronous after [load]; every mutation rewrites the list and
/// the write completes only once it is durable.
final class SearchHistoryStore {
  // The private aggregate; only [load] builds one.
  // ignore: unnecessary_type_name_in_constructor
  SearchHistoryStore._(this._repository, List<String> entries) : _entries = List.of(entries);

  /// Opens the box and reads the list. A missing or unreadable document is
  /// simply no history, the same answer a first run gives.
  static Future<SearchHistoryStore> load() async {
    final repository = HiveStorageRepository<List<String>>(
      box: await StorageBoxManager().keyed<List<String>>(SearchHistoryKeys.box),
    );
    final stored = repository.get(SearchHistoryKeys.document);
    final entries = [
      for (final entry in stored ?? const <String>[])
        if (entry.trim().isNotEmpty) entry,
    ];
    return SearchHistoryStore._(repository, entries);
  }

  final HiveStorageRepository<List<String>> _repository;
  List<String> _entries;

  /// The searches, most recent first.
  List<String> get entries => List.unmodifiable(_entries);

  /// Moves [query] to the front, deduplicated and capped at
  /// [SearchHistoryKeys.capacity].
  Future<void> add(String query) async {
    _entries
      ..remove(query)
      ..insert(0, query);
    if (_entries.length > SearchHistoryKeys.capacity) {
      _entries = _entries.sublist(0, SearchHistoryKeys.capacity);
    }
    await _repository.save(SearchHistoryKeys.document, _entries);
  }

  /// Removes one query; removing an unknown query is a no-op.
  Future<void> remove(String query) async {
    if (!_entries.remove(query)) {
      return;
    }
    await _repository.save(SearchHistoryKeys.document, _entries);
  }

  /// Removes every entry.
  Future<void> clear() async {
    if (_entries.isEmpty) {
      return;
    }
    _entries = <String>[];
    await _repository.save(SearchHistoryKeys.document, _entries);
  }
}
