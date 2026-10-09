// Module: lib/src/key_value_history_repository.dart
// Purpose: Bind the history repository to one key/value document.
// Author: liuchuancong
// Created: 2026-10-09
//
// docs/services/history.md names Drift for this domain and puts it in the sync scope. The port stays
// fine-grained (upsert / remove / removeWhere / clear) so that binding is a translation, not a rewrite of
// this layer; the document underneath is one list because that is what a key/value store can hold today.

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_storage/pure_live_storage.dart';

import 'history.dart';

/// A [HistoryRepository] held in one [KeyValueStore] key.
final class KeyValueHistoryRepository implements HistoryRepository {
  KeyValueHistoryRepository(this.store, {this.namespace = 'history'});

  final KeyValueStore store;
  final String namespace;

  String get _key => namespace;

  @override
  Future<List<HistoryEntry>> entries() async {
    final raw = await store.read(_key);
    if (raw == null) {
      return const <HistoryEntry>[];
    }
    // Reading an unreadable document as empty would delete the rest on the next progress tick, so this is
    // the same "refuse rather than lose" rule the file store and the favourites binding apply.
    if (raw is! List) {
      throw FormatException('the $namespace document is a ${raw.runtimeType}, not a list', raw);
    }
    return <HistoryEntry>[
      for (final item in raw)
        if (item is Map) HistoryEntry.fromJson(Map<String, Object?>.from(item)),
    ];
  }

  @override
  Future<void> upsert(HistoryEntry entry) async {
    final next = <HistoryEntry>[
      for (final existing in await entries())
        if (existing.identityKey != entry.identityKey) existing,
      entry,
    ];
    await _write(next);
  }

  @override
  Future<void> remove(ContentRef ref) async {
    final key = '${ref.sourceId}/${ref.contentId}/${ref.kind.name}';
    await _write((await entries()).where((entry) => entry.identityKey != key).toList());
  }

  @override
  Future<int> removeWhere(bool Function(HistoryEntry) test) async {
    final current = await entries();
    final kept = current.where((entry) => !test(entry)).toList();
    await _write(kept);
    return current.length - kept.length;
  }

  @override
  Future<void> clear() => store.remove(_key);

  Future<void> _write(List<HistoryEntry> entries) =>
      store.write(_key, entries.map((entry) => entry.toJson()).toList(growable: false));
}
