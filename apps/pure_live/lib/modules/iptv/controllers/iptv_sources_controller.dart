import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:live_log/live_log.dart' show LogLevel;
import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_epg_controller.dart';

/// What the playlist-source manager holds: the library's playlists and its
/// channel count, the import in flight, the per-source operations running,
/// and the "sync all" round with its progress.
typedef IptvSourcesState = ({
  bool ready,
  bool importing,
  List<IptvPlaylist> playlists,
  int channelCount,
  Set<String> busy,
  ({int done, int total})? syncAll,
});

IptvSourcesState _initial() =>
    (ready: false, importing: false, playlists: const [], channelCount: 0, busy: const {}, syncAll: null);

/// The playlist half of the IPTV source manager: previewing and importing a
/// playlist (address, local file or pasted text), syncing one from its
/// address, deleting one, and the "sync all" round that walks every network
/// source.
///
/// Every write goes through [IptvImporter], so a name clash is asked about
/// rather than silently overwritten and channels keep their ids (and the
/// viewer's favourites and order) across a sync. The guide sources have
/// their own controller, [IptvEpgController]; "sync all" runs both halves
/// so one button refreshes the whole module.
final class IptvSourcesController extends Notifier<IptvSourcesState> {
  StreamSubscription<void>? _subscription;
  IptvLibrary? _listened;

  @override
  IptvSourcesState build() {
    final library = ref.watch(iptvLibraryProvider).value;
    ref.onDispose(() => unawaited(_subscription?.cancel() ?? Future<void>.value()));
    if (library == null) {
      return _initial();
    }
    // A retry hands back a different library; the old subscription
    // belongs to the old one and is cancelled rather than kept.
    if (!identical(_listened, library)) {
      unawaited(_subscription?.cancel() ?? Future<void>.value());
      _subscription = library.changes.listen((_) => _mirror(library));
      _listened = library;
    }
    // The mirror is the build's result; returning a blank state after it
    // would discard it on every rebuild once the library has opened.
    state = _stateOf(library);
    return state;
  }

  /// Downloads [url] and judges it, writing nothing.
  Future<IptvPlaylistPreview> previewUrl(Uri url) async {
    final importer = await readyIptvImporter(ref);
    if (importer == null) {
      return IptvPlaylistPreview.failed(IptvImportResult(IptvImportStatus.failed), url: '$url');
    }
    return await importer.previewPlaylistFromUrl(url);
  }

  /// Judges pasted [text], writing nothing.
  Future<IptvPlaylistPreview> previewText(String text) async {
    final importer = await readyIptvImporter(ref);
    if (importer == null) {
      return IptvPlaylistPreview.failed(IptvImportResult(IptvImportStatus.failed));
    }
    return importer.previewPlaylistText(text);
  }

  /// Decodes and judges a picked file's [bytes], writing nothing.
  Future<IptvPlaylistPreview> previewBytes(List<int> bytes) async {
    final importer = await readyIptvImporter(ref);
    if (importer == null) {
      return IptvPlaylistPreview.failed(IptvImportResult(IptvImportStatus.failed));
    }
    return importer.previewPlaylistBytes(bytes);
  }

  /// Writes [preview] under [name] — replacing [replaceId] when given — and
  /// hides [hiddenGroups] once it is in.
  Future<IptvImportResult> commitPreview(
    IptvPlaylistPreview preview, {
    required String name,
    String? replaceId,
    Set<String> hiddenGroups = const {},
  }) async {
    final importer = await readyIptvImporter(ref);
    if (importer == null || state.importing) {
      return IptvImportResult(IptvImportStatus.failed);
    }
    state = _with(importing: true);
    try {
      final result = await importer.commitPlaylistPreview(
        preview,
        name: name,
        replaceId: replaceId,
        hiddenGroups: hiddenGroups,
      );
      _logVerdict('import', preview.url ?? name, result);
      return result;
    } on Object catch (error, stack) {
      appLog
          .forCategory('iptv.playlist')
          .error('playlist import threw', fields: {'name': name}, error: error, stackTrace: stack);
      return IptvImportResult(IptvImportStatus.failed, error: error);
    } finally {
      if (ref.mounted) state = _with(importing: false);
    }
  }

  /// One line per import or sync verdict: every failure the toast reports
  /// says why in the log, status and cause together.
  void _logVerdict(String op, String source, IptvImportResult result) {
    final log = appLog.forCategory('iptv.playlist');
    if (result.isImported) {
      log.info(
        'playlist $op imported',
        fields: {
          'source': source,
          'channels': result.channels,
          'added': result.added,
          'removed': result.removed,
          'issues': result.issues.length,
        },
      );
      return;
    }
    if (result.status == IptvImportStatus.cancelled) return;
    log.warning(
      'playlist $op failed',
      fields: {
        'source': source,
        'status': result.status.name,
        if (result.failure != null) 'failure': result.failure!.name,
        if (result.error != null) 'error': '${result.error}',
      },
    );
  }

  /// Re-downloads [playlist] from the address it was imported from; null
  /// when there is no importer or this source is already busy.
  Future<IptvImportResult?> syncPlaylist(IptvPlaylist playlist) async {
    final importer = await readyIptvImporter(ref);
    final key = _keyOf(playlist);
    if (importer == null || state.busy.contains(key)) return null;
    state = _with(busy: {...state.busy, key});
    try {
      final result = await importer.syncPlaylist(playlist);
      _logVerdict('sync', playlist.url ?? playlist.name, result);
      return result;
    } on Object catch (error, stack) {
      appLog
          .forCategory('iptv.playlist')
          .error('playlist sync threw', fields: {'name': playlist.name}, error: error, stackTrace: stack);
      return IptvImportResult(IptvImportStatus.failed, error: error);
    } finally {
      if (ref.mounted) state = _with(busy: {...state.busy}..remove(key));
    }
  }

  /// What deleting [playlist] would take with it, for the confirmation.
  ({int channels, int favourites}) deletionImpact(IptvPlaylist playlist) =>
      _library()?.deletionImpact(playlist.id) ?? (channels: 0, favourites: 0);

  /// Deletes [playlist], if it is still the record on screen; answers
  /// whether it was removed.
  Future<bool> deletePlaylist(IptvPlaylist playlist) async {
    final importer = _importer();
    final key = _keyOf(playlist);
    if (importer == null || state.busy.contains(key)) return false;
    state = _with(busy: {...state.busy, key});
    try {
      return await importer.deletePlaylist(playlist);
    } on Object catch (error) {
      appLog
          .forCategory('iptv.playlist')
          .log(LogLevel.warning, 'playlist delete failed', fields: {'name': playlist.name, 'error': '$error'});
      return false;
    } finally {
      if (ref.mounted) state = _with(busy: {...state.busy}..remove(key));
    }
  }

  /// Syncs every network playlist and guide, one at a time, reporting the
  /// round's size and failures. A round already running is not joined; the
  /// caller gets a zero-total report instead, which the screen words as
  /// nothing to do.
  Future<({int total, int failed})> syncAll() async {
    final library = _library();
    final importer = _importer();
    if (library == null || importer == null || state.syncAll != null) {
      return (total: 0, failed: 0);
    }
    final playlists = [
      for (final playlist in library.playlists)
        if (iptvPlaylistIsRemote(playlist)) playlist,
    ];
    final guides = [
      for (final source in library.guideSources)
        if (source.isRemote) source,
    ];
    final total = playlists.length + guides.length;
    if (total == 0) {
      return (total: 0, failed: 0);
    }
    state = _with(syncAll: (done: 0, total: total));
    var done = 0;
    var failed = 0;
    for (final playlist in playlists) {
      if (!ref.mounted) return (total: total, failed: failed);
      try {
        if (!(await importer.syncPlaylist(playlist)).isImported) failed++;
      } on Object {
        failed++;
      }
      done++;
      if (ref.mounted) state = _with(syncAll: (done: done, total: total));
    }
    final epg = ref.read(iptvEpgProvider.notifier);
    for (final source in guides) {
      if (!ref.mounted) return (total: total, failed: failed);
      try {
        if ((await epg.syncSource(source))?.isImported != true) failed++;
      } on Object {
        failed++;
      }
      done++;
      if (ref.mounted) state = _with(syncAll: (done: done, total: total));
    }
    if (ref.mounted) state = _with(dropSyncAll: true);
    appLog.forCategory('iptv.playlist').info('sync all finished', fields: {'total': total, 'failed': failed});
    return (total: total, failed: failed);
  }

  IptvLibrary? _library() => ref.read(iptvLibraryProvider).value;

  IptvImporter? _importer() => ref.read(iptvImporterProvider);

  static String _keyOf(IptvPlaylist playlist) => 'p:${playlist.id}';

  /// Re-derives the state from [library], keeping what is running.
  void _mirror(IptvLibrary library) {
    if (!ref.mounted) return;
    state = _stateOf(library);
  }

  /// The state [library] makes, carrying the import and round that were
  /// already running.
  IptvSourcesState _stateOf(IptvLibrary library) {
    final previous = stateOrNull;
    return (
      ready: true,
      importing: previous?.importing ?? false,
      playlists: library.playlists,
      channelCount: library.channels.length,
      busy: previous?.busy ?? const {},
      syncAll: previous?.syncAll,
    );
  }

  /// The record assembler every edit goes through: a record has no
  /// `copyWith`, and spelling every field per edit is how an update misses
  /// one.
  IptvSourcesState _with({
    bool? importing,
    Set<String>? busy,
    ({int done, int total})? syncAll,
    bool dropSyncAll = false,
  }) => (
    ready: state.ready,
    importing: importing ?? state.importing,
    playlists: state.playlists,
    channelCount: state.channelCount,
    busy: busy ?? state.busy,
    syncAll: dropSyncAll ? null : (syncAll ?? state.syncAll),
  );
}

/// The playlist source manager's state.
final iptvSourcesProvider = NotifierProvider<IptvSourcesController, IptvSourcesState>(IptvSourcesController.new);
