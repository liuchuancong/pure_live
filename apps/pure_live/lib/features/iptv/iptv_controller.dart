import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';

/// The IPTV library over its Hive box (one box, one process).
///
/// Opened the way the follows and history boxes are: through the storage
/// box manager, behind the `IptvStore` seam the live_iptv package defines.
/// Nothing in the app reads a channel anywhere else, so every surface that
/// changes the library (this page's heart button, the importer when it
/// arrives) lands on every other through the library's own `changes`
/// stream.
final iptvLibraryProvider = FutureProvider<IptvLibrary>((ref) async {
  final box = await StorageBoxManager().list<Object?>('iptv');
  final library = IptvLibrary(BoxIptvStore(HiveStorageListRepository<Object?>(box: box)));
  await library.load();
  ref.onDispose(() => unawaited(library.dispose()));
  return library;
});

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
  channels: const [],
  shown: 0,
  loadingMore: false,
  slots: const {},
);

/// The IPTV module's channel browser: the library's groups as tabs, the
/// open group's channels as a grid that reveals a page at a time.
///
/// The channels themselves live in the library; this notifier only mirrors
/// them — it listens to the library's `changes` stream the way the follows
/// notifier listens to its box, so a favourite toggled anywhere, or a
/// playlist re-imported by whatever surface gains that job, arrives here
/// without anyone telling this page. Nothing here knows a site: the
/// library is the source, not `selectedSiteProvider`.
final class IptvChannelsController extends Notifier<IptvChannelsState> {
  StreamSubscription<void>? _subscription;

  @override
  IptvChannelsState build() {
    ref.watch(iptvLibraryProvider).whenData((library) {
      // A retry (or any rebuild) hands back a different library: the old
      // subscription belongs to the old one and is cancelled rather than
      // kept by the `??=` that would quietly hold a dead stream.
      unawaited(_subscription?.cancel() ?? Future<void>.value());
      _subscription = library.changes.listen((_) => _mirror(library));
      _mirror(library);
    });
    ref.onDispose(() => unawaited(_subscription?.cancel() ?? Future<void>.value()));
    return _initial();
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
    final pageSize = ref.read(browseSettingsProvider).homePageSize;
    final target = _capped(state.shown + pageSize, state.channels.length);
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
  /// forces it to the first page.
  void _mirror(IptvLibrary library, {int? reveal, bool resetReveal = false}) {
    final favouritesOnly = state.scope == IptvChannelScope.favourites;
    final groups = [
      for (final name in library.groupNames)
        if (!library.isGroupHidden(name)) name,
    ];
    // A re-import may drop the open group; the list falls back to every
    // channel rather than to an empty page nobody can explain.
    final selected = state.selectedGroup != null && groups.contains(state.selectedGroup) ? state.selectedGroup : null;
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
    final channels = library.zapSequence(group: selected, favouritesOnly: favouritesOnly).channels;
    final pageSize = ref.read(browseSettingsProvider).homePageSize;
    // A list that just gained its first channels opens on the first page;
    // an established reveal survives a change, capped by what is there.
    final kept = state.shown == 0 ? _capped(pageSize, channels.length) : _capped(state.shown, channels.length);
    final base = resetReveal ? _capped(pageSize, channels.length) : (reveal ?? kept);
    final shown = _capped(base, channels.length);
    state = (
      ready: true,
      groups: groups,
      groupCounts: counts,
      libraryCount: libraryCount,
      totalCount: walk.length,
      selectedGroup: selected,
      scope: state.scope,
      channels: channels,
      shown: shown,
      loadingMore: false,
      slots: _slotsOf(library, channels, shown),
    );
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
    channels: state.channels,
    shown: state.shown,
    loadingMore: loadingMore ?? state.loadingMore,
    slots: slots ?? state.slots,
  );

  static int _capped(int value, int max) => value > max ? max : value;
}

/// The channels page's state.
final iptvChannelsProvider = NotifierProvider<IptvChannelsController, IptvChannelsState>(IptvChannelsController.new);
