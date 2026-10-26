import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/features/iptv/controllers/iptv_controller.dart' show iptvImporterProvider, iptvLibraryProvider;

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

  /// Imports the guide at [url]. An empty [name] falls back to the
  /// address's host, so the source list always has something to show.
  ///
  /// [confirmReplace] is the screen's question when the name already
  /// exists; a sync of one stored source never asks.
  Future<IptvImportResult> importFromUrl({
    required String url,
    String name = '',
    IptvReplaceConfirm? confirmReplace,
  }) async {
    final importer = _importer();
    if (importer == null || state.importing) {
      return IptvImportResult(IptvImportStatus.failed);
    }
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !_isHttp(uri)) {
      return IptvImportResult(IptvImportStatus.unsupportedFormat);
    }
    state = _with(importing: true, dropError: true);
    try {
      final cleanName = name.trim().isEmpty ? uri.host : name.trim();
      final result = await importer.importGuideFromUrl(url: uri, name: cleanName, confirmReplace: confirmReplace);
      if (result.isImported && result.id != null) {
        final library = _library();
        if (library != null) await library.autoMatch(sourceId: result.id!);
        // The import may have dropped a same-named duplicate that was the
        // guide in use; fall back to what just landed.
        final active = _active;
        if (active == null || library?.guideSource(active) == null) await _choose(result.id);
      }
      return result;
    } on Object catch (error) {
      if (ref.mounted) state = _with(error: error);
      return IptvImportResult(IptvImportStatus.failed, error: error);
    } finally {
      if (ref.mounted) state = _with(importing: false);
    }
  }

  /// Re-downloads [source] from its address and re-runs the matcher; null
  /// when there is no importer or the source is already busy.
  Future<IptvImportResult?> syncSource(EpgSource source) async {
    final importer = _importer();
    final key = _keyOf(source);
    if (importer == null || state.busy.contains(key)) return null;
    state = _with(busy: {...state.busy, key});
    try {
      final result = await importer.syncGuide(source);
      if (result.isImported) {
        final library = _library();
        if (library != null) await library.autoMatch(sourceId: source.id);
        final active = _active;
        if (active == null || library?.guideSource(active) == null) await _choose(source.id);
      }
      return result;
    } on Object catch (error) {
      return IptvImportResult(IptvImportStatus.failed, error: error);
    } finally {
      if (ref.mounted) state = _with(busy: {...state.busy}..remove(key));
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
    } on Object {
      return false;
    } finally {
      if (ref.mounted) state = _with(busy: {...state.busy}..remove(key));
    }
  }

  /// Turns [source]'s automatic refresh on or off. The flag is the
  /// source's own; the round that reads it is the caller's to schedule.
  Future<void> setAutoUpdate(EpgSource source, {required bool value}) async {
    final library = _library();
    final current = library?.guideSource(source.id);
    if (library == null || current == null || current.autoUpdate == value) return;
    await library.updateGuideSource(current.copyWith(autoUpdate: value));
  }

  /// Turns automatic refresh on or off for every network guide — the
  /// header switch's bulk action. Local guides cannot be re-downloaded, so
  /// their flags stay as they are.
  Future<void> setAllAutoUpdate({required bool value}) async {
    final library = _library();
    if (library == null) return;
    for (final source in library.guideSources) {
      if (!source.isRemote || source.autoUpdate == value) continue;
      await library.updateGuideSource(source.copyWith(autoUpdate: value));
    }
  }

  /// Makes [source] the guide in use, or clears the choice with null.
  Future<void> selectGuide(EpgSource? source) => _choose(source?.id);

  IptvLibrary? _library() => ref.read(iptvLibraryProvider).value;

  IptvImporter? _importer() => ref.read(iptvImporterProvider);

  static String _keyOf(EpgSource source) => 'g:${source.id}';

  static bool _isHttp(Uri uri) => (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;

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
