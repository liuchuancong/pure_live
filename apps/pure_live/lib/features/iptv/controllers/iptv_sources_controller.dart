import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:pure_live/features/iptv/controllers/iptv_controller.dart';
import 'package:pure_live/features/iptv/controllers/iptv_epg_controller.dart';

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

/// The playlist half of the IPTV source manager: importing a playlist
/// (URL, local file or pasted text), syncing one from its address, deleting
/// one, and the "sync all" round that walks every network source.
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

  /// Imports a playlist downloaded from [url] under [name].
  ///
  /// [confirmReplace] is the screen's question when [name] already exists;
  /// without an answer the importer writes nothing.
  Future<IptvImportResult> importPlaylistUrl({
    required Uri url,
    required String name,
    IptvReplaceConfirm? confirmReplace,
  }) async {
    final importer = _importer();
    if (importer == null || state.importing) {
      return IptvImportResult(IptvImportStatus.failed);
    }
    state = _with(importing: true);
    try {
      return await importer.importPlaylistFromUrl(url: url, name: name, confirmReplace: confirmReplace);
    } on Object catch (error) {
      return IptvImportResult(IptvImportStatus.failed, error: error);
    } finally {
      if (ref.mounted) state = _with(importing: false);
    }
  }

  /// Imports playlist [text] under [name]; [url] records where a download
  /// came from, so [syncPlaylist] can re-read it later. Pasted and local
  /// text records none.
  Future<IptvImportResult> importPlaylistText({
    required String text,
    required String name,
    String? url,
    IptvReplaceConfirm? confirmReplace,
  }) async {
    final importer = _importer();
    if (importer == null || state.importing) {
      return IptvImportResult(IptvImportStatus.failed);
    }
    state = _with(importing: true);
    try {
      return await importer.importPlaylistText(text: text, name: name, url: url, confirmReplace: confirmReplace);
    } on Object catch (error) {
      return IptvImportResult(IptvImportStatus.failed, error: error);
    } finally {
      if (ref.mounted) state = _with(importing: false);
    }
  }

  /// Re-downloads [playlist] from the address it was imported from; null
  /// when there is no importer or this source is already busy.
  Future<IptvImportResult?> syncPlaylist(IptvPlaylist playlist) async {
    final importer = _importer();
    final key = _keyOf(playlist);
    if (importer == null || state.busy.contains(key)) return null;
    state = _with(busy: {...state.busy, key});
    try {
      return await importer.syncPlaylist(playlist);
    } on Object catch (error) {
      return IptvImportResult(IptvImportStatus.failed, error: error);
    } finally {
      if (ref.mounted) state = _with(busy: {...state.busy}..remove(key));
    }
  }

  /// Deletes [playlist], if it is still the record on screen; answers
  /// whether it was removed.
  Future<bool> deletePlaylist(IptvPlaylist playlist) async {
    final importer = _importer();
    final key = _keyOf(playlist);
    if (importer == null || state.busy.contains(key)) return false;
    state = _with(busy: {...state.busy, key});
    try {
      return await importer.deletePlaylist(playlist);
    } on Object {
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
