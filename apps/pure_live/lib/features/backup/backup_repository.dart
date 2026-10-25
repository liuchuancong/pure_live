import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/features/areas/area_follow_repository.dart'
    show AreaFollowRepository, areaFollowRepositoryProvider;
import 'package:pure_live/features/backup/backup_document.dart';
import 'package:pure_live/features/backup/backup_settings.dart';
import 'package:pure_live/features/favorites/follow_repository.dart' show FollowRepository, followRepositoryProvider;
import 'package:pure_live/features/history/history_repository.dart' show HistoryRepository, historyRepositoryProvider;

/// The backup feature's own view of the user data: it reads the three
/// user-data boxes into a [BackupDocument] and writes a document back,
/// section by section.
///
/// The repositories stay the single writers of their boxes — capture and
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

  /// What the pane's summary shows: the entries per box plus how many
  /// backed-up settings currently carry a value.
  ({int follows, int history, int areas, int settings}) summary() => (
    follows: follows.box.getAllKeys().length,
    history: history.box.getAllKeys().length,
    areas: areaFollows.box.getAllKeys().length,
    settings: captureSettingsSnapshot().length,
  );

  /// Bundles the boxes and the settings subset into one document. A
  /// follows-only capture leaves the history and settings sections empty;
  /// its [BackupDocument.scope] is what tells a restore to keep them.
  BackupDocument capture({BackupScope scope = BackupScope.all}) => BackupDocument(
    exportedAt: DateTime.now().toUtc(),
    scope: scope,
    follows: _entriesOf(follows.box),
    history: scope == BackupScope.follows ? const {} : _entriesOf(history.box),
    areaFollows: _entriesOf(areaFollows.box),
    settings: scope == BackupScope.follows ? const {} : captureSettingsSnapshot(),
  );

  /// Restores [document]: every present section clears its box and takes
  /// the document's entries; the settings keys it carries are written
  /// back. A follows-only document touches only the two follows boxes, so
  /// the history and settings of this device stay as they are.
  Future<void> apply(BackupDocument document) async {
    // A section the document does not carry is left alone: an old export
    // that predates a box must not empty it. A section it does carry,
    // even empty, is the document's word on that data and replaces it.
    if (document.hasFollows) await _restore(follows.box, document.follows);
    if (document.hasAreas) await _restore(areaFollows.box, document.areaFollows);
    if (document.scope == BackupScope.follows) return;
    if (document.hasHistory) await _restore(history.box, document.history);
    if (document.hasSettings) await applySettingsSnapshot(document.settings);
  }

  /// Clears [box] and writes [entries] back, key for key, then flushes —
  /// a restore is whole or nothing per section.
  Future<void> _restore(HiveStorageRepository<Object> box, Map<String, Map<String, Object?>> entries) async {
    await box.clear();
    await box.saveAll(<String, Object>{for (final entry in entries.entries) entry.key: entry.value});
    await box.flush();
  }

  /// The box's entries as the JSON maps the document stores; Hive hands
  /// back its maps with dynamic keys.
  static Map<String, Map<String, Object?>> _entriesOf(HiveStorageRepository<Object> box) => {
    for (final entry in box.getAllEntries().entries)
      entry.key: entry.value is Map<String, Object?>
          ? Map<String, Object?>.from(entry.value as Map<String, Object?>)
          : Map<String, Object?>.from(entry.value as Map),
  };
}

/// The backup repository (the three user-data boxes, one process).
final backupRepositoryProvider = FutureProvider<BackupRepository>((ref) async {
  final follows = await ref.watch(followRepositoryProvider.future);
  final history = await ref.watch(historyRepositoryProvider.future);
  final areaFollows = await ref.watch(areaFollowRepositoryProvider.future);
  return BackupRepository(follows: follows, history: history, areaFollows: areaFollows);
});

/// What the boxes and the settings subset hold right now, for the pane's
/// summary row and its empty guard.
final backupSummaryProvider = FutureProvider<({int follows, int history, int areas, int settings})>((ref) async {
  final repository = await ref.watch(backupRepositoryProvider.future);
  return repository.summary();
});
