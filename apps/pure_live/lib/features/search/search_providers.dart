import 'dart:async' show Future, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/search/search_history_store.dart';

/// The user's recent searches, most recent first; empty until the store's
/// first read lands (the box opens lazily, unlike the appearance store the
/// composition root boots).
final searchHistoryProvider = NotifierProvider<SearchHistoryNotifier, List<String>>(SearchHistoryNotifier.new);

/// Keeps the [SearchHistoryStore] under the provider the page watches — the
/// same store-under-a-notifier shape as the appearance preferences.
final class SearchHistoryNotifier extends Notifier<List<String>> {
  SearchHistoryStore? _store;
  Future<void>? _hydrating;
  bool _disposed = false;

  @override
  List<String> build() {
    ref.onDispose(() => _disposed = true);
    unawaited(_hydrating = _hydrate());
    return const [];
  }

  Future<void> _hydrate() async {
    final store = await SearchHistoryStore.load();
    _store = store;
    if (!_disposed) {
      state = store.entries;
    }
  }

  /// The loaded store, waiting for a hydration still in flight so a search
  /// committed before the first read never records against a half-open box.
  Future<SearchHistoryStore> _ready() async {
    await _hydrating;
    return _store ??= await SearchHistoryStore.load();
  }

  /// Records [query]; a known one moves to the front, a blank one is ignored.
  Future<void> add(String query) async {
    final query_ = query.trim();
    if (query_.isEmpty || _disposed) {
      return;
    }
    final store = await _ready();
    await store.add(query_);
    if (!_disposed) {
      state = store.entries;
    }
  }

  /// Removes [query] from the list.
  Future<void> remove(String query) async {
    if (_disposed) {
      return;
    }
    final store = await _ready();
    await store.remove(query);
    if (!_disposed) {
      state = store.entries;
    }
  }

  /// Removes every entry.
  Future<void> clear() async {
    if (_disposed) {
      return;
    }
    final store = await _ready();
    await store.clear();
    if (!_disposed) {
      state = store.entries;
    }
  }
}
