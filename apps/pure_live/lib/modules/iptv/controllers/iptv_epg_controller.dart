import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:live_log/live_log.dart' show LogLevel;
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/l10n/translations.dart' show t;
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart'
    show iptvImporterProvider, iptvLibraryProvider, readyIptvImporter;

/// The preference the chosen guide source is kept under.
const String _activeGuidePref = 'iptv.guide.active';

/// What the guide-source manager holds: the library's guide sources with
/// their channel counts, the guide in use, the import or sync in flight,
/// and the per-source operations running.
typedef IptvEpgState = ({
  bool ready,
  bool importing,
  Object? error,
  List<EpgSource> sources,
  Map<String, int> channelCounts,
  String? activeId,
  Set<String> busy,
});

IptvEpgState _initial(String? activeId) => (
  ready: false,
  importing: false,
  error: null,
  sources: const [],
  channelCounts: const {},
  activeId: activeId,
  busy: const {},
);

/// The guide half of the IPTV source manager: importing a guide from an
/// address, syncing one, deleting one — with the active guide kept valid —
/// and the per-source automatic update switch.
///
/// A written guide is followed by the matcher's unique-name pass, so the
/// channel cards gain schedules without the viewer mapping anything by
/// hand. Deleting one source removes that source with its channels,
/// programmes and mappings only; the active guide moves to the next source
/// when the deleted one was in use, so the page never points at a guide
/// that no longer exists.
final class IptvEpgController extends Notifier<IptvEpgState> {
  StreamSubscription<void>? _subscription;
  IptvLibrary? _listened;

  /// The stored choice; null when nothing is chosen (or the stored id no
  /// longer names a source, in which case the first source stands in).
  String? _active;

  @override
  IptvEpgState build() {
    _active = _readActive();
    final library = ref.watch(iptvLibraryProvider).value;
    ref.onDispose(() => unawaited(_subscription?.cancel() ?? Future<void>.value()));
    if (library == null) {
      return _initial(_active);
    }
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

  /// Downloads the guide at [url] and judges it against the library,
  /// writing nothing.
  Future<IptvGuidePreview> previewUrl(Uri url) async {
    final importer = await readyIptvImporter(ref);
    if (importer == null) {
      return IptvGuidePreview.failed(IptvImportResult(IptvImportStatus.failed), source: '$url');
    }
    return await importer.previewGuideFromUrl(url);
  }

  /// Decodes and judges a picked guide file's [bytes]; [source] is the
  /// file's path, kept so the source list can say where it came from.
  Future<IptvGuidePreview> previewBytes(List<int> bytes, {required String source}) async {
    final importer = await readyIptvImporter(ref);
    if (importer == null) {
      return IptvGuidePreview.failed(IptvImportResult(IptvImportStatus.failed), source: source);
    }
    return await importer.previewGuideBytes(bytes, source: source);
  }

  /// Writes [preview] under [name] (taking over the guides of that name when
  /// [replace]), then matches the channels to it and makes it the guide in
  /// use when none is.
  Future<IptvImportResult> commitPreview(IptvGuidePreview preview, {required String name, bool replace = false}) async {
    final importer = await readyIptvImporter(ref);
    if (importer == null || state.importing) {
      return IptvImportResult(IptvImportStatus.failed);
    }
    state = _with(importing: true, dropError: true);
    final IptvImportResult result;
    try {
      result = await importer.commitGuidePreview(preview, name: name, replace: replace);
    } on Object catch (error, stack) {
      appLog
          .forCategory('iptv.epg')
          .error('guide import threw', fields: {'name': name}, error: error, stackTrace: stack);
      if (ref.mounted) state = _with(error: error);
      return IptvImportResult(IptvImportStatus.failed, error: error);
    } finally {
      if (ref.mounted) state = _with(importing: false);
    }
    _logVerdict('import', preview.source, result);
    await _afterImport(result);
    return result;
  }

  /// Re-downloads [source] from its address and re-runs the matcher; null
  /// when there is no importer or the source is already busy.
  Future<IptvImportResult?> syncSource(EpgSource source) async {
    final key = _keyOf(source);
    final importer = await readyIptvImporter(ref);
    if (importer == null || state.busy.contains(key)) return null;
    state = _with(busy: {...state.busy, key});
    IptvImportResult? result;
    try {
      result = await importer.syncGuide(source);
    } on Object catch (error, stack) {
      appLog
          .forCategory('iptv.epg')
          .error('guide sync threw', fields: {'source': source.name}, error: error, stackTrace: stack);
      result = IptvImportResult(IptvImportStatus.failed, error: error);
    } finally {
      if (ref.mounted) state = _with(busy: {...state.busy}..remove(key));
    }
    _logVerdict('sync', source.source, result);
    await _afterImport(result, sourceId: source.id);
    return result;
  }

  /// The best-effort half of a landed import: match the playlists' channels
  /// to the guide and make it the guide in use. Neither is the import's
  /// verdict — a failure here leaves the guide stored and unmapped, and the
  /// matcher's next run picks the matching up.
  Future<void> _afterImport(IptvImportResult? result, {String? sourceId}) async {
    if (result == null || !result.isImported) return;
    final id = result.id ?? sourceId;
    if (id == null) return;
    try {
      final library = _library();
      if (library != null) await library.autoMatch(sourceId: id);
      // The import may have dropped a same-named duplicate that was the
      // guide in use; fall back to what just landed.
      final active = _active;
      if (active == null || library?.guideSource(active) == null) await _choose(id);
    } on Object catch (error) {
      // The guide itself is stored; this half runs again on the next sync.
      // A landing whose matching failed reads as “导入成功却没节目”, so the
      // cause belongs in the log, not just on the screen.
      appLog
          .forCategory('iptv.epg')
          .warning('import landed but matching failed', fields: {'id': id, 'error': '$error'});
    }
  }

  /// Gives a freshly imported playlist its guide: the playlist header's own
  /// addresses (the list named its guide when it was read), and the first
  /// address that imports, matches some of the library's channels and still
  /// covers the present hour is kept, and made the guide in use when none is.
  ///
  /// The freshness test is what keeps a dead guide from wearing success: a
  /// guide of last August's programmes would pass a "readable and matching"
  /// test with nothing on air to show.
  ///
  /// A library that already has a guide gets another only when the viewer
  /// asked for it ([force], the preview's "add this guide too"): one guide
  /// in use is the design.
  Future<void> attachPlaylistGuide(String playlistId, {bool force = false}) async {
    final library = _library();
    if (library == null) return;
    final playlist = library.playlistById(playlistId);
    if (playlist == null || (library.guideSources.isNotEmpty && !force)) return;
    for (final address in playlist.guideUrls) {
      final uri = Uri.tryParse(address.trim());
      if (uri == null || !uri.isAbsolute || uri.host.isEmpty) continue;
      try {
        final preview = await previewUrl(uri);
        if (!preview.isReadable || preview.matchable == 0) continue;
        final lastStop = preview.lastStop;
        if (lastStop == null || lastStop.isBefore(DateTime.now())) continue;
        final result = await commitPreview(preview, name: t.iptv.guideNameOf(name: playlist.name), replace: true);
        if (result.isImported) return;
      } on Object catch (error) {
        appLog
            .forCategory('iptv.epg')
            .warning("the playlist's guide address failed", fields: {'address': address, 'error': '$error'});
      }
    }
  }

  /// Deletes [expected] with its channels, programmes and mappings; when it
  /// was the guide in use, the first remaining source takes over.
  Future<bool> deleteSource(EpgSource expected) async {
    final importer = _importer();
    final key = _keyOf(expected);
    if (importer == null || state.busy.contains(key)) return false;
    state = _with(busy: {...state.busy, key});
    try {
      final deleted = await importer.deleteGuide(expected);
      if (!deleted) return false;
      if (_active == expected.id) {
        final remaining = _library()?.guideSources ?? const <EpgSource>[];
        await _choose(remaining.isEmpty ? null : remaining.first.id);
      }
      return true;
    } on Object catch (error) {
      appLog
          .forCategory('iptv.epg')
          .log(LogLevel.warning, 'guide delete failed', fields: {'source': expected.name, 'error': '$error'});
      return false;
    } finally {
      if (ref.mounted) state = _with(busy: {...state.busy}..remove(key));
    }
  }

  /// One line per import or sync verdict: every failure the toast reports
  /// says why in the log, status and cause together.
  void _logVerdict(String op, String source, IptvImportResult? result) {
    final log = appLog.forCategory('iptv.epg');
    if (result == null) return;
    if (result.isImported) {
      log.info(
        'guide $op imported',
        fields: {'source': source, 'channels': result.channels, 'issues': result.issues.length},
      );
      return;
    }
    if (result.status == IptvImportStatus.cancelled) return;
    log.warning(
      'guide $op failed',
      fields: {'source': source, 'status': result.status.name, if (result.error != null) 'error': '${result.error}'},
    );
  }

  /// Turns [source]'s automatic refresh on or off. The flag is the
  /// source's own; the round that reads it is the caller's to schedule.
  Future<void> setAutoUpdate(EpgSource source, {required bool value}) async {
    final library = _library();
    final current = library?.guideSource(source.id);
    if (library == null || current == null || current.autoUpdate == value) return;
    await library.updateGuideSource(current.rebuild((b) => b..autoUpdate = value));
  }

  /// Turns automatic refresh on or off for every network guide — the
  /// header switch's bulk action. Local guides cannot be re-downloaded, so
  /// their flags stay as they are.
  Future<void> setAllAutoUpdate({required bool value}) async {
    final library = _library();
    if (library == null) return;
    for (final source in library.guideSources) {
      if (!source.isRemote || source.autoUpdate == value) continue;
      await library.updateGuideSource(source.rebuild((b) => b..autoUpdate = value));
    }
  }

  /// Makes [source] the guide in use, or clears the choice with null.
  Future<void> selectGuide(EpgSource? source) => _choose(source?.id);

  IptvLibrary? _library() => ref.read(iptvLibraryProvider).value;

  IptvImporter? _importer() => ref.read(iptvImporterProvider);

  static String _keyOf(EpgSource source) => 'g:${source.id}';

  /// Writes [id] as the active guide and mirrors the choice.
  Future<void> _choose(String? id) async {
    _active = id;
    if (ref.mounted) state = _with(activeId: id, dropActive: id == null);
    try {
      await StoragePrefs.setString(_activeGuidePref, id ?? '');
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }

  static String? _readActive() {
    try {
      final stored = StoragePrefs.getString(_activeGuidePref) ?? '';
      return stored.isEmpty ? null : stored;
    } on Object {
      return null;
    }
  }

  /// Re-derives the state from [library], keeping what is running and
  /// falling back to the first source when the chosen one is gone.
  void _mirror(IptvLibrary library) {
    if (!ref.mounted) return;
    state = _stateOf(library);
  }

  /// The state [library] makes, keeping the import, error and per-source
  /// operations that were already running.
  IptvEpgState _stateOf(IptvLibrary library) {
    final previous = stateOrNull;
    final sources = library.guideSources;
    final ids = {for (final source in sources) source.id};
    if (_active != null && !ids.contains(_active)) {
      _active = sources.isEmpty ? null : sources.first.id;
    }
    _active ??= sources.isEmpty ? null : sources.first.id;
    return (
      ready: true,
      importing: previous?.importing ?? false,
      error: previous?.error,
      sources: sources,
      channelCounts: {for (final source in sources) source.id: library.guideChannels(source.id).length},
      activeId: _active,
      busy: previous?.busy ?? const {},
    );
  }

  /// The record assembler every edit goes through.
  IptvEpgState _with({
    bool? importing,
    Object? error = _noError,
    bool dropError = false,
    Set<String>? busy,
    String? activeId,
    bool dropActive = false,
  }) => (
    ready: state.ready,
    importing: importing ?? state.importing,
    error: dropError ? null : (error == _noError ? state.error : error),
    sources: state.sources,
    channelCounts: state.channelCounts,
    activeId: dropActive ? null : (activeId ?? state.activeId),
    busy: busy ?? state.busy,
  );
}

/// A sentinel separating "leave the error as it is" from "set it to null".
const Object _noError = Object();

/// The guide source manager's state.
final iptvEpgProvider = NotifierProvider<IptvEpgController, IptvEpgState>(IptvEpgController.new);
