import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/features/areas/areas.dart';
import 'package:pure_live/features/backup/document/backup_document.dart';
import 'package:pure_live/features/backup/document/backup_settings.dart';
import 'package:pure_live/features/favorites/favorites.dart';
import 'package:pure_live/features/history/history.dart';

/// The backup feature's own view of the user data: it reads the three
/// user-data namespaces into a [BackupDocument] and writes a document
/// back, section by section.
///
/// The repositories stay the single writers of their stores — capture and
/// restore go through the same handles the favorites, history and areas
/// pages use, so every watch stream fires and the pages refresh at once.
final class BackupRepository {
  /// Serves the three user-data repositories.
  BackupRepository({required this.follows, required this.history, required this.areaFollows});

  /// The followed rooms.
  final FollowRepository follows;

  /// The watch history.
  final HistoryRepository history;

  /// The followed areas.
  final AreaFollowRepository areaFollows;

  /// What the pane's summary shows: the entries per store plus how many
  /// backed-up settings currently carry a value.
  ({int follows, int history, int areas, int settings}) summary() => (
    follows: follows.store.keys.length,
    history: history.store.keys.length,
    areas: areaFollows.store.keys.length,
    settings: captureSettingsSnapshot().length,
  );

  /// Bundles the stores and the settings subset into one document. A
  /// follows-only capture leaves the history and settings sections empty;
  /// its [BackupDocument.scope] is what tells a restore to keep them.
  BackupDocument capture({BackupScope scope = BackupScope.all}) => BackupDocument(
    exportedAt: DateTime.now().toUtc(),
    scope: scope,
    follows: _entriesOf(follows.store),
    history: scope == BackupScope.follows ? const {} : _entriesOf(history.store),
    areaFollows: _entriesOf(areaFollows.store),
    settings: scope == BackupScope.follows ? const {} : captureSettingsSnapshot(),
  );

  /// Restores [document]: every present section clears its store and takes
  /// the document's entries; the settings keys it carries are written
  /// back. A follows-only document touches only the two follows stores, so
  /// the history and settings of this device stay as they are.
  Future<void> apply(BackupDocument document) async {
    // A section the document does not carry is left alone: an old export
    // that predates a store must not empty it. A section it does carry,
    // even empty, is the document's word on that data and replaces it.
    if (document.hasFollows) await _restore(follows.store, document.follows);
    if (document.hasAreas) await _restore(areaFollows.store, document.areaFollows);
    if (document.scope == BackupScope.follows) return;
    if (document.hasHistory) await _restore(history.store, document.history);
    if (document.hasSettings) await applySettingsSnapshot(document.settings);
  }

  /// Clears [store] and writes [entries] back, key for key, then flushes —
  /// a restore is whole or nothing per section.
  Future<void> _restore(JsonStore store, Map<String, Map<String, Object?>> entries) async {
    await store.clear();
    await store.putAll(<String, Object?>{for (final entry in entries.entries) entry.key: entry.value});
    await store.flush();
  }

  /// The store's entries as the JSON maps the document stores.
  static Map<String, Map<String, Object?>> _entriesOf(JsonStore store) => {
    for (final entry in store.entries.entries) entry.key: _jsonOf(entry.value),
  };

  static Map<String, Object?> _jsonOf(Object? value) =>
      value is Map<String, Object?> ? value : Map<String, Object?>.from(value! as Map);
}

/// The backup repository (the three user-data namespaces, one process).
final backupRepositoryProvider = FutureProvider<BackupRepository>((ref) async {
  final follows = await ref.watch(followRepositoryProvider.future);
  final history = await ref.watch(historyRepositoryProvider.future);
  final areaFollows = await ref.watch(areaFollowRepositoryProvider.future);
  return BackupRepository(follows: follows, history: history, areaFollows: areaFollows);
});

/// What the stores and the settings subset hold right now, for the pane's
/// summary row and its empty guard.
final backupSummaryProvider = FutureProvider<({int follows, int history, int areas, int settings})>((ref) async {
  final repository = await ref.watch(backupRepositoryProvider.future);
  return repository.summary();
});
