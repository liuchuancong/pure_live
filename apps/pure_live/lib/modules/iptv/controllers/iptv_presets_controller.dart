import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:live_net/live_net.dart' show ClientProfile;
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/app/providers/network/github_mirror_provider.dart' show githubMirrorProvider;
import 'package:pure_live/app/providers/network/network_providers.dart' show networkFactoryProvider;
import 'package:pure_live/l10n/translations.dart' show LocaleSettings, t;
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_epg_controller.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_sources_controller.dart';
import 'package:pure_live/modules/iptv/data/iptv_fetch_routes.dart' show iptvDownloadCandidates;
import 'package:pure_live/modules/iptv/data/iptv_preset.dart';
import 'package:pure_live/modules/iptv/data/iptv_preset_catalog.dart';

/// The keys the preset layer persists under.
const String _tombstonesPref = 'iptv.presets.deleted';
const String _mappingPref = 'iptv.presets.map';
const String _onboardedPref = 'iptv.presets.onboarded';
const String _feedPref = 'iptv.presets.feed';
const String _feedAtPref = 'iptv.presets.feedAt';

/// What the preset layer holds: the catalogue on offer (built-in, plus the
/// repository's feed once it has been read), the presets the viewer removed,
/// and which stored playlist each added preset became.
typedef IptvPresetsState = ({
  /// The catalogue, tombstones removed.
  List<IptvPreset> presets,

  /// The preset ids the viewer removed; a preset here is not offered again
  /// until "restore default sources" clears it.
  Set<String> deleted,

  /// Preset id → stored playlist id, for the ones added.
  Map<String, String> added,

  /// Whether the feed fetch is running.
  bool loading,

  /// Whether the first visit's automatic add has run (or found nothing to
  /// run on) — it never runs twice, whatever happened in between.
  bool onboarded,

  /// The preset an add is running on, for the start screen's busy state.
  String? adding,
});

IptvPresetsState _stateOf({
  required List<IptvPreset> presets,
  required Set<String> deleted,
  required Map<String, String> added,
  required bool onboarded,
  String? adding,
  bool loading = false,
}) => (presets: presets, deleted: deleted, added: added, loading: loading, onboarded: onboarded, adding: adding);

/// The recommended-source layer over the IPTV library.
///
/// Three rules shape it. **A preset is an invitation, not a setting**: what
/// the viewer keeps is the playlist the import made, and deleting that
/// playlist is an ordinary deletion — the preset only stops being offered
/// again (the `deleted` tombstones, the reference's deleted list).
/// **The first visit adds the default** so the screens are never empty on
/// arrival; it runs once, and a viewer who deleted the preset is never
/// re-added behind their back. **The catalogue is data**: the repository's
/// feed replaces the built-in list without a release, read through the same
/// GitHub mirrors every other catalogue of this app uses.
final class IptvPresetsController extends Notifier<IptvPresetsState> {
  /// When this session last asked the feed, read or not.
  DateTime? _feedTriedAt;

  @override
  IptvPresetsState build() {
    final deleted = _readStrings(_tombstonesPref).toSet();
    final mapping = _readMapping();
    final feed = _readFeed();
    final onboarded = _readBool(_onboardedPref);
    ref.listen(iptvLibraryProvider, (_, _) => _rebuild());
    // `deleted` is passed in: build() runs before `state` exists, and
    // _catalogue must not read it there — a read during build throws
    // "uninitialized provider" and fails the whole presets layer.
    return _stateOf(
      presets: _catalogue(feed, deleted: deleted),
      deleted: deleted,
      added: mapping,
      onboarded: onboarded,
    );
  }

  /// The catalogue: the feed's entries when it was read, else the built-ins,
  /// with the tombstones taken out.
  ///
  /// [deleted] must be handed in from build (where `state` is not yet
  /// readable); everywhere else reads it from the current state.
  List<IptvPreset> _catalogue(List<IptvPreset> feed, {Set<String>? deleted}) {
    final removed = deleted ?? state.deleted;
    final source = feed.isNotEmpty ? feed : builtinIptvPresets;
    return [
      for (final preset in source)
        if (!removed.contains(preset.id)) preset,
    ];
  }

  void _rebuild() {
    if (!ref.mounted) return;
    state = _stateOf(
      presets: _catalogue(_readFeed()),
      deleted: state.deleted,
      added: _readMapping(),
      loading: state.loading,
      onboarded: state.onboarded,
      adding: state.adding,
    );
  }

  /// The stored playlist [preset] became, or null while it is not added.
  IptvPlaylist? playlistOf(IptvPreset preset) {
    final id = state.added[preset.id];
    if (id == null) return null;
    return ref.read(iptvLibraryProvider).value?.playlistById(id);
  }

  /// Imports [preset]: previews its address, writes it under the preset's
  /// name, and answers the import.
  ///
  /// The viewer sees the same preview an address import shows — a preset is
  /// a shortcut to that flow, not a second one.
  Future<IptvImportResult> add(IptvPreset preset, {String? name}) async {
    final sources = ref.read(iptvSourcesProvider.notifier);
    final uri = Uri.tryParse(preset.url.trim());
    if (uri == null) {
      return IptvImportResult(IptvImportStatus.unsupportedFormat, failure: IptvImportFailure.unreadable);
    }
    state = _with(adding: preset.id);
    try {
      final preview = await sources.previewUrl(uri);
      if (!preview.isReadable) {
        return preview.failure ?? IptvImportResult(IptvImportStatus.failed);
      }
      final result = await sources.commitPreview(
        preview,
        name: (name ?? '').trim().isEmpty ? preset.nameIn(currentLanguageTag()) : name!.trim(),
        replaceId: preview.urlClash?.id,
      );
      if (result.isImported && result.id != null) {
        _remember(preset.id, result.id!);
      }
      return result;
    } finally {
      if (ref.mounted) state = _with(clearAdding: true);
    }
  }

  /// Records that the viewer deleted the playlist a preset had become.
  ///
  /// Called by the source manager when a deleted playlist maps to a preset:
  /// the tombstone is what keeps "delete" meaning "gone", on the start
  /// screen too.
  void forget(String presetId) {
    if (!state.deleted.contains(presetId)) {
      final next = {...state.deleted, presetId};
      state = _with(deleted: next);
      _writeStrings(_tombstonesPref, next.toList());
    }
    final added = {...state.added}..remove(presetId);
    state = _with(added: added);
    _writeMapping(added);
  }

  /// Brings the built-in catalogue back: the tombstones go, the feed does
  /// not change. Nothing is imported here — the start screen offers them
  /// again, and adding is still the viewer's tap.
  void restoreDefaults() {
    const restored = <String>{};
    state = _with(deleted: restored);
    _writeStrings(_tombstonesPref, const []);
  }

  /// Marks the first visit as handled without adding anything: an existing
  /// library is the viewer's own arrangement, and it is not added to.
  void skipOnboarding() {
    if (state.onboarded) return;
    _markOnboarded();
  }

  /// The first visit's add: the default preset is imported so the screens
  /// open on channels rather than on an empty state, with its guide (or the
  /// first catalogue guide) behind it.
  ///
  /// Failures are silent but logged: a first visit without network is a
  /// first visit with the start screen's add buttons, not an error dialog —
  /// and it is not marked done, so the next visit tries again. Only a
  /// landed add (or a library the viewer filled themselves, see
  /// [skipOnboarding]) ends the first-visit behaviour for good.
  Future<void> onboard() async {
    if (state.onboarded || state.adding != null) return;
    final library = ref.read(iptvLibraryProvider).value;
    if (library == null) return;
    final preset = _catalogue(_readFeed()).where((entry) => entry.id == iptvDefaultPresetId).firstOrNull;
    if (preset == null) {
      _markOnboarded();
      return;
    }
    try {
      final result = await add(preset);
      if (!result.isImported) {
        appLog
            .forCategory('iptv.presets')
            .info('first-run add skipped', fields: {'preset': preset.id, 'status': result.status.name});
        return;
      }
      _markOnboarded();
      unawaited(attachGuide(result.id!, preset: preset));
    } on Object catch (error) {
      appLog
          .forCategory('iptv.presets')
          .warning('first-run add failed', fields: {'preset': preset.id, 'error': '$error'});
    }
  }

  /// Refreshes playlists the catalogue marks short-lived: on entering the
  /// IPTV screens, a signed playlist whose addresses have gone stale is
  /// re-downloaded, which is the only way its channels play again.
  Future<void> refreshStale() async {
    final library = ref.read(iptvLibraryProvider).value;
    if (library == null) return;
    final catalogue = {for (final preset in _catalogue(_readFeed())) preset.id: preset};
    final now = DateTime.now();
    for (final MapEntry(key: presetId, value: playlistId) in state.added.entries) {
      final preset = catalogue[presetId];
      if (preset == null || !preset.shortLived) continue;
      final playlist = library.playlistById(playlistId);
      if (playlist == null || !iptvPlaylistIsRemote(playlist)) continue;
      if (now.difference(playlist.importedAt) < iptvShortLivedAge) continue;
      try {
        await ref.read(iptvSourcesProvider.notifier).syncPlaylist(playlist);
      } on Object catch (error) {
        appLog
            .forCategory('iptv.presets')
            .warning('stale preset refresh failed', fields: {'preset': presetId, 'error': '$error'});
      }
    }
  }

  /// Gives a playlist its guide: the playlist header's own addresses first
  /// (the provider named its guide), then the preset's, then — when the
  /// library has no guide at all — the catalogue's. The first address that
  /// imports, matches some of the library's channels and still covers the
  /// present hour is kept, and the guide controller makes it the one in use
  /// when none is.
  ///
  /// The freshness test is what keeps a dead guide from wearing success: the
  /// Migu playback list the LemonTV header names can stand still for months
  /// while its channels keep working, and a guide of last August's programmes
  /// would pass a "readable and matching" test with nothing on air to show.
  ///
  /// A library that already has a guide gets another only when the viewer
  /// asked for it ([force], the preview's "add this guide too"): one guide in
  /// use is the design, and a second preset must not pile up a second copy
  /// of the same Chinese schedule behind the viewer's back.
  Future<void> attachGuide(String playlistId, {IptvPreset? preset, bool force = false}) async {
    final library = ref.read(iptvLibraryProvider).value;
    final epg = ref.read(iptvEpgProvider.notifier);
    if (library == null) return;
    final playlist = library.playlistById(playlistId);
    final hasGuide = library.guideSources.isNotEmpty;
    if (playlist == null || (hasGuide && !force)) return;
    final addresses = <String>{
      // The list's own word about its guide outranks the catalogue's guess.
      ...playlist.guideUrls,
      ...?preset?.guideUrls,
      if (!hasGuide)
        for (final entry in builtinIptvPresets) ...entry.guideUrls,
    };
    for (final address in addresses) {
      final uri = Uri.tryParse(address.trim());
      if (uri == null || !uri.isAbsolute || uri.host.isEmpty) continue;
      try {
        final preview = await epg.previewUrl(uri);
        if (!preview.isReadable || preview.matchable == 0) continue;
        final lastStop = preview.lastStop;
        if (lastStop == null || lastStop.isBefore(DateTime.now())) continue;
        // Named after what it serves, not after the mirror it came through.
        final name = t.iptv.guideNameOf(name: preset?.nameIn(currentLanguageTag()) ?? playlist.name);
        final result = await epg.commitPreview(preview, name: name, replace: true);
        if (result.isImported) return;
      } on Object catch (error) {
        appLog
            .forCategory('iptv.presets')
            .warning('preset guide failed', fields: {'preset': preset?.id, 'guide': address, 'error': '$error'});
      }
    }
  }

  /// Records that the import page added [presetId] as [playlistId].
  void noteAdded(String presetId, String playlistId) => _remember(presetId, playlistId);

  /// Reads the repository's feed through the GitHub mirrors, caching the
  /// last good answer; a feed that fails keeps yesterday's.
  Future<void> refreshFeed() async {
    if (state.loading) return;
    // Once in a while is enough for a catalogue: a good read holds for half
    // a day, and a failed one is not retried in the same session's hour.
    final now = DateTime.now();
    final tried = _feedTriedAt;
    if (tried != null && now.difference(tried) < const Duration(hours: 1)) return;
    final storedAt = DateTime.tryParse(_readString(_feedAtPref) ?? '');
    if (storedAt != null && now.difference(storedAt) < const Duration(hours: 12)) return;
    _feedTriedAt = now;
    state = _with(loading: true);
    try {
      final http = ref.read(networkFactoryProvider).create(profile: ClientProfile.api);
      final fetcher = iptvFetcherFor(http, timeout: const Duration(seconds: 20));
      final uri = Uri.parse(iptvPresetFeedUrl);
      var text = '';
      for (final candidate in iptvDownloadCandidates(uri, ref.read(githubMirrorProvider))) {
        try {
          text = await fetcher(candidate, headers: const {});
          break;
        } on Object {
          continue;
        }
      }
      if (text.isEmpty) return;
      final decoded = jsonDecode(text);
      final List<IptvPreset> entries;
      if (decoded is List) {
        entries = [for (final entry in decoded) ?IptvPreset.fromJson(entry)];
      } else if (decoded case {'presets': final List<Object?> presets}) {
        entries = [for (final entry in presets) ?IptvPreset.fromJson(entry)];
      } else {
        return;
      }
      if (entries.isEmpty) return;
      unawaited(StoragePrefs.setString(_feedPref, jsonEncode([for (final entry in entries) entry.toJson()])));
      unawaited(StoragePrefs.setString(_feedAtPref, DateTime.now().toIso8601String()));
      state = _with(presets: _catalogue(entries), loading: false);
    } on Object catch (error) {
      appLog.forCategory('iptv.presets').warning('preset feed failed', fields: {'error': '$error'});
    } finally {
      if (ref.mounted) state = _with(loading: false);
    }
  }

  void _remember(String presetId, String playlistId) {
    final added = {...state.added, presetId: playlistId};
    state = _with(added: added);
    _writeMapping(added);
  }

  void _markOnboarded() {
    state = _with(onboarded: true);
    unawaited(StoragePrefs.setBool(_onboardedPref, true));
  }

  IptvPresetsState _with({
    List<IptvPreset>? presets,
    Set<String>? deleted,
    Map<String, String>? added,
    bool? loading,
    bool? onboarded,
    String? adding,
    bool clearAdding = false,
  }) => (
    presets: presets ?? state.presets,
    deleted: deleted ?? state.deleted,
    added: added ?? state.added,
    loading: loading ?? state.loading,
    onboarded: onboarded ?? state.onboarded,
    adding: clearAdding ? null : (adding ?? state.adding),
  );

  static List<String> _readStrings(String key) {
    try {
      return StoragePrefs.getStringList(key) ?? const [];
    } on Object {
      return const [];
    }
  }

  static void _writeStrings(String key, List<String> values) {
    unawaited(StoragePrefs.setStringList(key, values));
  }

  static Map<String, String> _readMapping() {
    try {
      final stored = StoragePrefs.getString(_mappingPref);
      if (stored == null || stored.isEmpty) return const {};
      final decoded = jsonDecode(stored);
      if (decoded is! Map) return const {};
      return {
        for (final MapEntry(:key, :value) in decoded.entries)
          if (key is String && value is String) key: value,
      };
    } on Object {
      return const {};
    }
  }

  static void _writeMapping(Map<String, String> mapping) {
    unawaited(StoragePrefs.setString(_mappingPref, jsonEncode(mapping)));
  }

  static List<IptvPreset> _readFeed() {
    try {
      final stored = StoragePrefs.getString(_feedPref);
      if (stored == null || stored.isEmpty) return const [];
      final decoded = jsonDecode(stored);
      if (decoded is! List) return const [];
      return [for (final entry in decoded) ?IptvPreset.fromJson(entry)];
    } on Object {
      return const [];
    }
  }

  static bool _readBool(String key) {
    try {
      return StoragePrefs.getBool(key) ?? false;
    } on Object {
      return false;
    }
  }

  static String? _readString(String key) {
    try {
      return StoragePrefs.getString(key);
    } on Object {
      return null;
    }
  }
}

/// The language tag the preset words are picked in; read once per call so a
/// language switch mid-session is honoured by the next screen build.
String currentLanguageTag() => LocaleSettings.currentLocale.languageTag;

/// The preset layer's state.
final iptvPresetsProvider = NotifierProvider<IptvPresetsController, IptvPresetsState>(IptvPresetsController.new);
