import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:live_net/live_net.dart' show ClientProfile;
import 'package:pure_live/app/providers/network_providers.dart' show networkFactoryProvider;
import 'package:pure_live/features/iptv/iptv_controller.dart' show iptvChannelsProvider, iptvLibraryProvider;

/// What the IPTV guide's source row holds: the load in flight and the
/// failure, if any. The sources themselves live in the library.
typedef IptvEpgState = ({bool loading, Object? error});

/// The IPTV programme guide's source management (the reference's guide
/// store): importing a URL reads it with the package's parser, stores it
/// in the library, and runs the unique-only matcher so every playlist
/// line that clearly names a guide channel gets its schedule at once.
///
/// The page's per-channel slots come from `IptvLibrary.programmeSlot`,
/// which reads exactly this stored guide.
final class IptvEpgController extends Notifier<IptvEpgState> {
  @override
  IptvEpgState build() => (loading: false, error: null);

  /// The library the guide lands in, or null while it is still opening.
  IptvLibrary? _library() => ref.read(iptvLibraryProvider).value;

  /// Imports [url] as a guide source: download, parse, store, map.
  ///
  /// A source re-imported under the same id replaces its own rows (a
  /// refresh, not a duplicate); the mapping matcher rewrites the automatic
  /// half and leaves the viewer's hand-locked mappings alone.
  Future<bool> importFromUrl(String url) async {
    final library = _library();
    if (library == null || state.loading) return false;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    state = (loading: true, error: null);
    try {
      // The guide rides the app's shared transport, like every other
      // module's remote reads (proxies and cookies stay the shell's).
      final http = ref.read(networkFactoryProvider).create(profile: ClientProfile.api);
      ref.onDispose(http.close);
      final guide = await EpgParser(fetchBytes: iptvBytesFetcherFor(http)).fetchGuide(Uri.parse(trimmed));
      if (guide.isEmpty) {
        state = (loading: false, error: StateError('empty guide'));
        return false;
      }
      final sourceId = 'epg-${Uri.parse(trimmed).host}';
      final source = EpgSource(
        id: sourceId,
        name: Uri.parse(trimmed).host,
        source: trimmed,
        lastRefresh: DateTime.now().toUtc(),
        createdAt: DateTime.now().toUtc(),
      );
      final channels = [
        for (final channel in guide.channels)
          EpgChannel(
            sourceId: sourceId,
            channelId: channel.id,
            displayName: channel.displayNames.isEmpty ? channel.id : channel.displayNames.first,
            iconUrl: channel.iconUrl,
          ),
      ];
      await library.saveGuide(source, channels, guide.entries);
      final playlistId = library.playlists.isEmpty ? '' : library.playlists.first.id;
      final mapping = rebuildMappings(
        playlistId: playlistId,
        sourceId: sourceId,
        channels: library.channels,
        guideChannels: library.guideChannels(sourceId),
        previous: library.mappings(playlistId),
      );
      await library.applyMappings(upserts: mapping.upserts, deletes: mapping.deletes);
      // The stored guide changed: the channels controller's slots read the
      // library, and a fresh read shows the new schedules.
      ref.invalidate(iptvChannelsProvider);
      state = (loading: false, error: null);
      return true;
    } on Object catch (error) {
      state = (loading: false, error: error);
      return false;
    }
  }

  /// Forgets every guide source; the schedules go with them.
  Future<void> removeAll() async {
    final library = _library();
    if (library == null) return;
    state = (loading: true, error: null);
    for (final source in library.guideSources) {
      await library.deleteGuideSource(source.id);
    }
    ref.invalidate(iptvChannelsProvider);
    state = (loading: false, error: null);
  }
}

/// The IPTV page's guide source state.
final iptvEpgProvider = NotifierProvider<IptvEpgController, IptvEpgState>(IptvEpgController.new);
