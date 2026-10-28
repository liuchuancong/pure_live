import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:live_net/live_net.dart' show ClientProfile;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_user_agent.dart'
    show iptvUserAgentProvider, normalizedIptvUserAgent;

/// The IPTV library over its shared JSON store (one namespace, one process).
///
/// Opened the way the follows and history stores are: through the process's
/// SQLite store, behind the `IptvStore` seam the live_iptv package defines.
/// Nothing in the app reads a channel anywhere else, so every surface that
/// changes the library (this page's heart button, the importer when it
/// arrives) lands on every other through the library's own `changes`
/// stream.
final iptvLibraryProvider = FutureProvider<IptvLibrary>((ref) async {
  final store = await StorageStores.instance.openStore(IptvKeys.table);
  final library = IptvLibrary(StorageIptvStore(JsonListStore(store)));
  await library.load();
  ref.onDispose(() => unawaited(library.dispose()));
  return library;
});

/// The importer every playlist and guide write goes through, over the open
/// library.
///
/// Its two download seams ride the app's shared transport, so an IPTV
/// download honours the network settings (proxy, cookies) exactly as the
/// rest of the app does. Null while the library is still opening — an
/// import cannot land before the store it writes to exists.
final iptvImporterProvider = Provider<IptvImporter?>((ref) {
  final library = ref.watch(iptvLibraryProvider).value;
  if (library == null) return null;
  final http = ref.read(networkFactoryProvider).create(profile: ClientProfile.api);
  ref.onDispose(http.close);
  // The viewer's override applies to playlist and guide downloads; a change
  // rebuilds the importer, so the next import uses the new value.
  final userAgent = normalizedIptvUserAgent(ref.watch(iptvUserAgentProvider));
  return IptvImporter(
    library: library,
    fetch: iptvFetcherFor(http, userAgent: userAgent),
    fetchBytes: iptvBytesFetcherFor(http, userAgent: userAgent),
  );
});

/// Whether [playlist] was imported from a web address, so a sync has
/// something to download again. Local files and pasted text record no
/// address ([IptvPlaylist.url] is null) and are never "due".
bool iptvPlaylistIsRemote(IptvPlaylist playlist) {
  final url = (playlist.url ?? '').trim().toLowerCase();
  return url.startsWith('http://') || url.startsWith('https://');
}

/// What the channels list filters to: every channel, or the favourites.
enum IptvChannelScope {
  /// Every visible channel of the open group.
  all,

  /// Only the channels the viewer favourited.
  favourites,
}

/// What the channels page holds: the browse groups with their live counts,
/// how many channels the library itself holds, which group is open and
/// under which scope, the filtered channels with how many the grid has
/// revealed, and the programme slot of every channel it shows.
typedef IptvChannelsState = ({
  bool ready,
  List<String> groups,
  Map<String, int> groupCounts,
  int libraryCount,
  int totalCount,
  String? selectedGroup,
  IptvChannelScope scope,
  String query,
  List<IptvChannel> channels,
  int shown,
  bool loadingMore,
  Map<String, IptvProgrammeSlot> slots,
});

IptvChannelsState _initial() => (
  ready: false,
  groups: const [],
  groupCounts: const {},
  libraryCount: 0,
  totalCount: 0,
  selectedGroup: null,
  scope: IptvChannelScope.all,
  query: '',
  channels: const [],
  shown: 0,
  loadingMore: false,
  slots: const {},
);

/// The channels the channel browser reveals at a time. A local playlist has
/// no site feed window to follow (the browsing feeds take theirs from the
/// platform's own request size), so the reveal is the list's own step: rows
/// to fill a tall window twice over, small enough that the frame between
/// pages stays smooth.
const int kIptvRevealStep = 60;

/// The IPTV module's channel browser: the library's groups as tabs, the
/// open group's channels as a grid that reveals a page at a time.
///
/// The channels themselves live in the library; this notifier only mirrors
/// them — it listens to the library's `changes` stream the way the follows
/// notifier listens to its box, so a favourite toggled anywhere, or a
/// playlist re-imported by whatever surface gains that job, arrives here
/// without anyone telling this page. Nothing here knows a site: the
/// library is the source, not `preferredSiteProvider`.
final class IptvChannelsController extends Notifier<IptvChannelsState> {
  StreamSubscription<void>? _subscription;
  IptvLibrary? _listened;

  @override
  IptvChannelsState build() {
    final library = ref.watch(iptvLibraryProvider).value;
    ref.onDispose(() => unawaited(_subscription?.cancel() ?? Future<void>.value()));
    if (library == null) {
      return _initial();
    }
    // A retry (or any rebuild) hands back a different library: the old
    // subscription belongs to the old one and is cancelled rather than
    // kept by the `??=` that would quietly hold a dead stream.
    if (!identical(_listened, library)) {
      unawaited(_subscription?.cancel() ?? Future<void>.value());
      _subscription = library.changes.listen((_) => _mirror(library));
      _listened = library;
    }
    // The mirrored state is the build's result: assigning it and then
    // returning a blank state would throw the mirror away on every
    // rebuild that lands after the library finished opening.
    _mirror(library, from: stateOrNull ?? _initial());
    return state;
  }

  /// Opens [group] — null for every group at once. The reveal restarts at
  /// the first page, so the new group never opens half-scrolled to where
  /// the old one was.
  void selectGroup(String? group) {
    if (group == state.selectedGroup || (group != null && !state.groups.contains(group))) {
      return;
    }
    // `dropGroup` carries the "every group at once" choice: a null
    // argument is that choice, not "leave it as it was".
    state = _with(selectedGroup: group, dropGroup: group == null);
    _remirrorFromFirstPage();
  }

  /// Moves the list to [scope] — every channel or only the favourites. The
  /// reveal restarts at the first page for the same reason as
  /// [selectGroup].
  void selectScope(IptvChannelScope scope) {
    if (scope == state.scope) return;
    state = _with(scope: scope);
    _remirrorFromFirstPage();
  }

  /// Filters the open list by [value] — a channel's name, number or group,
  /// case-insensitively. A search shows every match at once rather than
  /// revealing them page by page: the viewer is looking for one name, not
  /// browsing. Empty clears the filter.
  void setQuery(String value) {
    final query = value.trim().toLowerCase();
    if (query == state.query) return;
    state = _with(query: query);
    _remirrorFromFirstPage();
  }

  /// Reveals the next page of the open list when one is left.
  ///
  /// The data is already in memory, so a page is only a slice — but the
  /// slice is revealed across a frame on purpose: the footer's loading row
  /// paints first (it is the grid's signal that more is coming), and a
  /// whole page of cards is not built in the same frame as the scroll that
  /// asked for it.
  Future<void> loadMore() async {
    final library = _library();
    if (library == null || state.loadingMore || state.shown >= state.channels.length) {
      return;
    }
    final target = _capped(state.shown + kIptvRevealStep, state.channels.length);
    final group = state.selectedGroup;
    final scope = state.scope;
    state = _with(loadingMore: true);
    await Future<void>.delayed(Duration.zero);
    // A filter switch during the frame lands through the switch's own
    // mirror, which has already restarted the reveal — this page turn is
    // for the list that asked for it.
    if (!ref.mounted || state.selectedGroup != group || state.scope != scope) return;
    _mirror(library, reveal: target);
  }

  /// Toggles the favourite flag of the channel [channelId]; the library's
  /// own change notification brings the new list back here.
  Future<void> toggleFavorite(String channelId) async {
    final library = _library();
    if (library == null) return;
    await library.toggleFavorite(channelId);
  }

  /// Reads the programme slots again at the current moment, so "what is on
  /// now" and its progress keep moving while the page is open. The page
  /// calls this from a minute timer.
  void refreshSlots() {
    final library = _library();
    if (library == null || !state.ready) return;
    state = _with(slots: _slotsOf(library, state.channels, state.shown));
  }

  IptvLibrary? _library() => ref.read(iptvLibraryProvider).value;

  /// Re-derives the state after a filter change, which restarts the reveal
  /// at the first page of the list the new filter makes.
  void _remirrorFromFirstPage() {
    final library = _library();
    if (library != null) {
      _mirror(library, resetReveal: true);
    }
  }

  /// Re-derives the whole state from [library], keeping the open group and
  /// scope and how much was revealed; [reveal] forces the reveal to a
  /// count instead (the next page from [loadMore]), and [resetReveal]
  /// forces it to the first page. [from] is the state the derivation
  /// starts from — the blank state during a build, the current one
  /// otherwise.
  void _mirror(IptvLibrary library, {int? reveal, bool resetReveal = false, IptvChannelsState? from}) {
    final current = from ?? state;
    final favouritesOnly = current.scope == IptvChannelScope.favourites;
    final groups = [
      for (final name in library.groupNames)
        if (!library.isGroupHidden(name)) name,
    ];
    // A re-import may drop the open group; the list falls back to every
    // channel rather than to an empty page nobody can explain.
    final selected = current.selectedGroup != null && groups.contains(current.selectedGroup)
        ? current.selectedGroup
        : null;
    final walk = library.zapSequence(favouritesOnly: favouritesOnly).channels;
    // The library's own size, whatever the filter: an empty favourites
    // list and an empty library are different facts, and the page words
    // them differently.
    final libraryCount = favouritesOnly ? library.zapSequence().channels.length : walk.length;
    final counts = <String, int>{};
    for (final channel in walk) {
      final key = iptvGroupKeyOf(channel);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final channels = [
      for (final channel in library.zapSequence(group: selected, favouritesOnly: favouritesOnly).channels)
        if (_matches(channel, current.query)) channel,
    ];
    // A search is complete at once — the viewer names what they look for —
    // while browsing reveals a page at a time. A list that just gained its
    // first channels opens on the first page; an established reveal
    // survives a change, capped by what is there.
    final shown = current.query.isNotEmpty
        ? channels.length
        : _capped(
            resetReveal
                ? _capped(kIptvRevealStep, channels.length)
                : (reveal ??
                      (current.shown == 0
                          ? _capped(kIptvRevealStep, channels.length)
                          : _capped(current.shown, channels.length))),
            channels.length,
          );
    state = (
      ready: true,
      groups: groups,
      groupCounts: counts,
      libraryCount: libraryCount,
      totalCount: walk.length,
      selectedGroup: selected,
      scope: current.scope,
      query: current.query,
      channels: channels,
      shown: shown,
      loadingMore: false,
      slots: _slotsOf(library, channels, shown),
    );
  }

  /// Whether [channel] answers [query] by its name, number, id or group;
  /// [query] is already lower-cased, and empty matches everything.
  static bool _matches(IptvChannel channel, String query) {
    if (query.isEmpty) return true;
    if (channel.entry.name.toLowerCase().contains(query)) return true;
    if ((channel.number?.toString() ?? '').contains(query)) return true;
    if ((channel.entry.tvgId ?? '').toLowerCase().contains(query)) return true;
    return iptvGroupKeyOf(channel).toLowerCase().contains(query);
  }

  /// The slot of every channel the grid shows, read at one shared moment
  /// — a "now" that moves per card would disagree with the progress bars
  /// beside it.
  static Map<String, IptvProgrammeSlot> _slotsOf(IptvLibrary library, List<IptvChannel> channels, int shown) => {
    for (final channel in channels.take(shown)) channel.id: library.programmeSlot(channel),
  };

  /// The record assembler every small edit goes through: a record has no
  /// `copyWith`, and spelling every field per edit is how an update misses
  /// one.
  IptvChannelsState _with({
    String? selectedGroup,
    bool dropGroup = false,
    IptvChannelScope? scope,
    String? query,
    bool? loadingMore,
    Map<String, IptvProgrammeSlot>? slots,
  }) => (
    ready: state.ready,
    groups: state.groups,
    groupCounts: state.groupCounts,
    libraryCount: state.libraryCount,
    totalCount: state.totalCount,
    selectedGroup: dropGroup ? null : (selectedGroup ?? state.selectedGroup),
    scope: scope ?? state.scope,
    query: query ?? state.query,
    channels: state.channels,
    shown: state.shown,
    loadingMore: loadingMore ?? state.loadingMore,
    slots: slots ?? state.slots,
  );

  static int _capped(int value, int max) => value > max ? max : value;
}

/// The channels page's state.
final iptvChannelsProvider = NotifierProvider<IptvChannelsController, IptvChannelsState>(IptvChannelsController.new);
