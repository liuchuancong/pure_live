// Module: lib/src/data/search_history.dart
// Purpose: Bounded, deduplicated recent-keyword history over one kv store.
// Author: liuchuancong
// Created: 2026-10-10

import 'dart:convert';

import 'package:pure_live_storage/pure_live_storage.dart';

/// The recent search keywords. Newest first; re-searching a keyword moves it
/// to the front; the list caps at [maxLength] entries. Blank keywords are
/// never recorded - a submit of whitespace is not a search.
final class SearchHistory {
  SearchHistory({required KeyValueStore store, this.maxLength = 20}) : _store = store;

  static const String _key = 'search.recent';
  final KeyValueStore _store;
  final int maxLength;
  List<String> _cache = const <String>[];
  bool _loaded = false;

  Future<List<String>> _load() async {
    if (_loaded) {
      return _cache;
    }
    final raw = await _store.read(_key);
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _cache = [for (final item in decoded) '$item'];
        }
      } on FormatException {
        // corrupt row: start empty, heal on the next write
      }
    }
    _loaded = true;
    return _cache;
  }

  Future<void> _save() => _store.write(_key, jsonEncode(_cache));

  /// Records [keyword] at the front of the history.
  Future<List<String>> record(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      return _load();
    }
    final history = await _load();
    _cache = [trimmed, ...history.where((item) => item != trimmed)];
    while (_cache.length > maxLength) {
      _cache.removeLast();
    }
    await _save();
    return List.of(_cache);
  }

  Future<List<String>> all() async => List.of(await _load());

  Future<void> remove(String keyword) async {
    final history = await _load();
    _cache = history.where((item) => item != keyword).toList();
    await _save();
  }

  Future<void> clear() async {
    _cache = const <String>[];
    await _store.remove(_key);
  }
}
