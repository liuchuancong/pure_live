import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/features/backup/document/backup_document.dart';
import 'package:pure_live/features/backup/document/backup_settings.dart';
import 'package:pure_live/features/backup/webdav/webdav_settings.dart' show appSecretStoreProvider;
import 'package:pure_live/modules/live/areas/areas.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/history/history.dart';
import 'package:pure_live/modules/live/recorder/data/recording_repository.dart';
import 'package:pure_live/modules/live/recorder/data/recording_task.dart';

/// Why a restore was refused before it touched anything: this device is
/// still recording or finishing a take, and the restore would clear the
/// task entry the engine writes to.
///
/// The surfaces translate it into their own message; anything else the
/// restore throws is a genuine failure.
final class BackupRecordingsBusy implements Exception {
  /// The restore cannot run while a take is live.
  const BackupRecordingsBusy();
}

/// Why a restore found nothing to do: the document carries no entry in any
/// of its sections. Restoring it would only empty the stores, which is
/// never what a reader of an empty file means.
final class BackupDocumentEmpty implements Exception {
  /// The document is empty.
  const BackupDocumentEmpty();
}

/// The backup feature's own view of the user data: it reads the four
/// user-data namespaces, the settings subset and (on request) the vault
/// into a [BackupDocument] and writes a document back, section by section.
///
/// The repositories stay the single writers of their stores — capture and
/// restore go through the same handles the favorites, history, areas and
/// recorder pages use, so every watch stream fires and the pages refresh
/// at once.
final class BackupRepository {
  /// Serves the four user-data namespaces and, when the vault opened, the
  /// secrets.
  BackupRepository({
    required this.follows,
    required this.history,
    required this.areaFollows,
    required this.recordings,
    this.secrets,
  });

  /// The followed rooms.
  final FollowRepository follows;

  /// The watch history.
  final HistoryRepository history;

  /// The followed areas.
  final AreaFollowRepository areaFollows;

  /// The recorder's tasks.
  final RecordingTaskRepository recordings;

  /// The device vault; null when it never opened (an unsupported platform
  /// or a locked keychain), in which case the secrets section cannot be
  /// captured or restored and the picker does not offer it.
  final SecretStore? secrets;

  /// What the pane's summary shows: the entries per section as they are
  /// now.
  Map<BackupSection, int> summary() => {
    BackupSection.follows: follows.store.keys.length,
    BackupSection.history: history.store.keys.length,
    BackupSection.areaFollows: areaFollows.store.keys.length,
    BackupSection.recordings: recordings.store.keys.length,
    BackupSection.settings: captureSettingsSnapshot().length,
    BackupSection.secrets: secrets?.refs.length ?? 0,
  };

  /// Bundles the selected [sections] into one document. A section not
  /// selected is absent from the document, which is what tells a restore
  /// to keep that box as it is. The secrets ride only when selected and
  /// the vault is open.
  BackupDocument capture({Set<BackupSection> sections = BackupSection.all}) {
    final vault = secrets;
    final present = {...sections};
    if (vault == null) present.remove(BackupSection.secrets);
    return BackupDocument(
      exportedAt: DateTime.now().toUtc(),
      follows: present.contains(BackupSection.follows) ? _entriesOf(follows.store) : const {},
      history: present.contains(BackupSection.history) ? _entriesOf(history.store) : const {},
      areaFollows: present.contains(BackupSection.areaFollows) ? _entriesOf(areaFollows.store) : const {},
      recordings: present.contains(BackupSection.recordings) ? _entriesOf(recordings.store) : const {},
      settings: present.contains(BackupSection.settings) ? captureSettingsSnapshot() : const {},
      secrets: present.contains(BackupSection.secrets) && vault != null
          ? {for (final ref in vault.refs) ref: vault.value(ref) ?? ''}
          : const {},
      presentSections: present,
    );
  }

  /// Restores [document]: every present section clears its store and takes
  /// the document's entries; the settings keys it carries are written
  /// back; the secrets it carries are set in the vault (refs it does not
  /// name stay). A section the document does not carry is left alone.
  ///
  /// Throws [BackupRecordingsBusy] when a restore would clear the task
  /// store under a take this device is recording or still finishing, and
  /// [BackupDocumentEmpty] when the document carries nothing — no write
  /// happens in either case.
  Future<void> apply(BackupDocument document) async {
    if (document.isEmpty) throw const BackupDocumentEmpty();
    // The guard runs before the first write, so a refused restore leaves
    // every box exactly as it was rather than half-applying the document.
    if (document.hasRecordings && _hasLiveTake()) throw const BackupRecordingsBusy();
    // A section the document does not carry is left alone: an old export
    // that predates a store must not empty it. A section it does carry,
    // even empty, is the document's word on that data and replaces it.
    if (document.hasFollows) await _restore(follows.store, document.follows);
    if (document.hasAreas) await _restore(areaFollows.store, document.areaFollows);
    if (document.hasHistory) await _restore(history.store, document.history);
    if (document.hasRecordings) await _restoreRecordings(document.recordings);
    if (document.hasSettings) await applySettingsSnapshot(document.settings);
    if (document.hasSecrets) await _restoreSecrets(document.secrets);
  }

  /// Whether this device has a take the engine still owns: a session
  /// capturing, or a finished one whose join, transcode and rename are
  /// still running. Both write their task entry by id, which a cleared
  /// store would leave them writing to nothing.
  bool _hasLiveTake() => recordings.list().any((task) => task.isRunning || task.postProcessing);

  /// Clears the task store and writes [entries] back as idle tasks.
  ///
  /// A document is a record of what the user set up, not of what a machine
  /// was doing: no session runs behind a restored task, so a take that was
  /// recording becomes a waiting one (the live check starts it when the
  /// room goes live), and a half-finished post-processing flag, its
  /// progress and the warning codes that came with it are dropped. The
  /// facts a take left behind — its file, size, length and error — are kept
  /// as the document tells them.
  Future<void> _restoreRecordings(Map<String, Map<String, Object?>> entries) async {
    final tasks = <String, Object?>{};
    for (final entry in entries.entries) {
      final task = RecordingTask.fromJson(entry.value);
      // An entry without a room cannot be recorded or listed usefully; a
      // newer writer's odd shape reads as an empty task and is skipped.
      if (task.platform.isEmpty || task.roomId.isEmpty) continue;
      final idle = task.copyWith(
        id: entry.key,
        state: task.isRunning ? RecordingTaskState.waiting : task.state,
        postProcessing: false,
        postProcessingProgress: -1,
        warning: '',
      );
      tasks[entry.key] = idle.toJson();
    }
    await recordings.store.clear();
    await recordings.store.putAll(tasks);
    await recordings.store.flush();
  }

  /// Sets every secret the document names. Secrets it does not name are
  /// kept: a backup from another device must not log this one out of the
  /// platforms it never knew about. An empty value removes the ref.
  Future<void> _restoreSecrets(Map<String, String> entries) async {
    final vault = secrets;
    if (vault == null) return;
    for (final entry in entries.entries) {
      if (entry.value.isEmpty) {
        await vault.remove(entry.key);
      } else {
        await vault.set(entry.key, entry.value);
      }
    }
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

/// The backup repository (the four user-data namespaces, the vault when
/// it opens, one process).
final backupRepositoryProvider = FutureProvider<BackupRepository>((ref) async {
  final follows = await ref.watch(followRepositoryProvider.future);
  final history = await ref.watch(historyRepositoryProvider.future);
  final areaFollows = await ref.watch(areaFollowRepositoryProvider.future);
  final recordings = await ref.watch(recordingRepositoryProvider.future);
  SecretStore? secrets;
  try {
    secrets = await ref.watch(appSecretStoreProvider.future);
  } on Object {
    // No vault on this platform: the secrets section is simply not offered.
  }
  return BackupRepository(
    follows: follows,
    history: history,
    areaFollows: areaFollows,
    recordings: recordings,
    secrets: secrets,
  );
});

/// What the stores, the settings subset and the vault hold right now, per
/// section, for the pane's summary row and the picker's counts.
final backupSummaryProvider = FutureProvider<Map<BackupSection, int>>((ref) async {
  final repository = await ref.watch(backupRepositoryProvider.future);
  return repository.summary();
});
