import 'dart:async';

import 'package:live_iptv/src/guide/guide_matcher.dart';
import 'package:live_iptv/src/library/iptv_store/iptv_store.dart';
import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/order/iptv_channel_ordering.dart';
import 'package:live_iptv/src/order/iptv_zap_sequence.dart';
import 'package:live_iptv/src/playlist/playlist.dart';
import 'package:live_iptv/src/probe/probe.dart';
import 'package:live_storage/live_storage.dart';

/// The user's IPTV library: imported playlists and the channels they
/// yielded, with favourites and ordering.
///
/// Importing reconciles channels by URL: channels that already exist
/// (same URL) keep their channel id and the user's favourite/hidden/
/// position flags; new URLs are appended; channels the new playlist no
/// longer carries are dropped only when `removeMissing` is true — the
/// default keeps them, because a temporarily unavailable source must not
/// delete the user's list.
final class IptvLibrary {
  /// A library over [store].
  new(this.store);

  /// The persistence seam.
  final IptvStore store;

  final _changes = StreamController<void>.broadcast();
  List<IptvChannel> _channels = const [];
  List<IptvPlaylist> _playlists = const [];
  List<EpgSource> _sources = const [];
  List<EpgChannel> _guideChannels = const [];
  List<EpgProgramme> _programmes = const [];
  List<EpgMapping> _mappings = const [];
  List<IptvGroup> _groups = const [];
  Map<String, IptvLineHealth> _health = const {};
  bool _loaded = false;
  bool _writing = false;

  /// Bumped by every commit this library makes, and read by [_reload] to
  /// notice a write that landed while it was reading.
  int _revision = 0;
  bool _reloading = false;
  bool _reloadAgain = false;
  StreamSubscription<void>? _external;

  /// Emits after every committed mutation.
  Stream<void> get changes => _changes.stream;

  /// The channels, ordered by position.
  List<IptvChannel> get channels => List.unmodifiable(_channels);

  /// The imported playlists.
  List<IptvPlaylist> get playlists => List.unmodifiable(_playlists);

  /// The guide sources, in import order.
  List<EpgSource> get guideSources => List.unmodifiable(_sources);

  /// The group records the user arranged, in the order they arranged them.
  ///
  /// A group whose channels the user never touched has no record here, and
  /// that is the normal state rather than a gap: see [groupNames] for the
  /// list a screen should actually draw.
  List<IptvGroup> get groups => List.unmodifiable(sortIptvGroups(_groups));

  /// Every group the channels name, in display order, including the ones
  /// nobody has arranged and the hidden ones.
  List<String> get groupNames => List.unmodifiable(groupRanks.keys);

  /// The display rank of every group, smallest first; the key is
  /// [iptvUngroupedKey] for channels that name no group.
  ///
  /// Derived rather than stored, because the set of groups is a fact about
  /// the playlists and only their *order* is a fact about the user: a group
  /// that appears in tomorrow's list has to land somewhere without anyone
  /// having to record it first.
  Map<String, int> get groupRanks => rankIptvGroups(channels: _channels, groups: _groups);

  /// The last probe verdict of every address that has one, keyed by URL.
  Map<String, IptvLineHealth> get lineHealth => Map.unmodifiable(_health);

  /// The verdict stored for [url], null when there is none.
  IptvLineHealth? healthOfUrl(String url) => _health[url];

  /// The channels in display order, hidden ones included.
  ///
  /// This is the list [zapSequence] and the number lookup walk when nothing
  /// filters them; a screen that shows a filter of its own should sort with
  /// [compareIptvChannels] rather than assume the playlist order it arrived
  /// in is the order the remote will step through.
  List<IptvChannel> get orderedChannels => sortIptvChannels(_channels, groupRanks: groupRanks);

  /// The channel numbered [number] among the visible ones, or null.
  IptvChannel? channelByNumber(int number, {String? group}) => zapSequence(group: group).byNumber(number);

  /// The channel with [id], or null.
  IptvChannel? channelById(String id) {
    for (final channel in _channels) {
      if (channel.id == id) {
        return channel;
      }
    }
    return null;
  }

  /// The next free channel number, so a screen offering "number this
  /// channel" never proposes one that already answers.
  int get nextUnusedNumber => iptvNextFreeNumber([for (final channel in _channels) channel.number ?? 0], 1);

  /// The walk the remote control's up and down keys take.
  ///
  /// Hidden channels and the channels of hidden groups are left out, which
  /// is what makes hiding a channel a real removal from the zapping rather
  /// than a note in a list. [group] restricts the walk to one group while
  /// keeping the numbers the whole line-up uses; [favouritesOnly] is the
  /// same idea for the favourites switch on a TV screen; [reverse] swaps the
  /// two keys without reordering the list.
  IptvZapSequence zapSequence({
    String? group,
    bool favouritesOnly = false,
    bool includeHidden = false,
    bool reverse = false,
  }) {
    final ranks = groupRanks;
    final ordered = sortIptvChannels(_channels, groupRanks: ranks);
    final visible = [
      for (final channel in ordered)
        if ((includeHidden || !channel.hidden) &&
            (group == null || iptvGroupKeyOf(channel) == group) &&
            (!favouritesOnly || channel.favorite) &&
            (includeHidden || !(_recordOf(iptvGroupKeyOf(channel))?.hidden ?? false)))
          channel,
    ];
    return IptvZapSequence(channels: visible, reversed: reverse);
  }

  /// Loads the library (idempotent).
  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    _channels = await store.loadChannels();
    _playlists = await store.loadPlaylists();
    _sources = await store.loadGuideSources();
    _guideChannels = await store.loadGuideChannels();
    _programmes = await store.loadGuideProgrammes();
    _mappings = await store.loadGuideMappings();
    _groups = await store.loadGroups();
    _health = _indexHealth(await store.loadLineHealth());
    _external ??= store.changes.listen((_) => _storeChanged());
  }

  /// The guide source [id], or null.
  EpgSource? guideSource(String id) {
    for (final source in _sources) {
      if (source.id == id) {
        return source;
      }
    }
    return null;
  }

  /// The channels of the guide source [sourceId].
  List<EpgChannel> guideChannels(String sourceId) => List.unmodifiable([
    for (final channel in _guideChannels)
      if (channel.sourceId == sourceId) channel,
  ]);

  /// The mappings of the playlist [playlistId].
  List<EpgMapping> mappings(String playlistId) => List.unmodifiable([
    for (final mapping in _mappings)
      if (mapping.playlistId == playlistId) mapping,
  ]);

  /// The programmes of guide channel [channelKey] that start at or after
  /// [from] and stop at or before [to], by start.
  ///
  /// The key is the one a room carries ([epgChannelKey]), so a caller that
  /// holds a room can ask without knowing how the library sorted them.
  List<EpgProgramme> programmes(String channelKey, {required DateTime from, required DateTime to}) {
    final matching = [
      for (final programme in _programmes)
        if (epgChannelKey(programme.sourceId, programme.channelId) == channelKey &&
            !programme.start.isBefore(from) &&
            !programme.stop.isAfter(to))
          programme,
    ]..sort((a, b) => a.start.compareTo(b.start));
    return List.unmodifiable(matching);
  }

  /// The programmes of [channelKeys] that are on air at [at]: started at or
  /// before it and not stopped yet.
  List<EpgProgramme> programmesAt(Set<String> channelKeys, DateTime at) => List.unmodifiable([
    for (final programme in _programmes)
      if (channelKeys.contains(epgChannelKey(programme.sourceId, programme.channelId)) &&
          !programme.start.isAfter(at) &&
          !programme.stop.isBefore(at))
        programme,
  ]);

  /// The mapping stored for channel [channelId], or null.
  ///
  /// A locked or hand-made mapping is returned exactly like an automatic one:
  /// who made it decides whether a later sync may rewrite it, not whether it
  /// is in force today. A channel with two rows (one per guide source, from
  /// before the matcher ran on a second guide) reports the locked one, and
  /// the first otherwise, so the answer is stable across a reload.
  EpgMapping? mappingFor(String channelId) {
    EpgMapping? found;
    for (final mapping in _mappings) {
      if (mapping.channelId != channelId) {
        continue;
      }
      if (mapping.locked) {
        return mapping;
      }
      found ??= mapping;
    }
    return found;
  }

  /// The guide channel key [channel]'s programmes come from, or null.
  ///
  /// The trust order is the matcher's own, not a second copy of it: a stored
  /// mapping first, then the playlist's `tvg-id`, then the normalized name
  /// asked of each guide source in turn — which is what lets a freshly
  /// imported guide show programmes before anybody has run the matcher over
  /// the whole library.
  String? guideKeyFor(IptvChannel channel) {
    final stored = mappingFor(channel.id);
    for (final source in _sources) {
      final key = resolveGuideChannel(
        channel: channel,
        sourceId: source.id,
        guideChannels: guideChannels(source.id),
        mapping: stored,
      );
      if (key != null) {
        return key;
      }
    }
    // A locked mapping whose guide channel has disappeared resolves to nothing
    // on purpose — the matcher will not guess a replacement for a choice the
    // viewer made. Hand their choice back anyway: the pin should survive a
    // guide that renamed a channel, with no programmes for the hour in between,
    // rather than silently become somebody else's channel.
    if (stored != null && stored.locked) {
      return stored.epgChannelKey;
    }
    return null;
  }

  /// What is on [channel] at [now], and what comes after it.
  ///
  /// The window is deliberately wide behind [now] (an hour and a half of
  /// history) rather than starting at the programme list's own beginning:
  /// a viewer who opened the guide at midnight should still see what is on,
  /// and a guide that only carries today's evening must not read as empty
  /// for that reason.
  IptvProgrammeSlot programmeSlot(IptvChannel channel, {DateTime? now}) {
    final moment = now ?? DateTime.now();
    final list = schedule(channel, from: moment.subtract(const Duration(hours: 6)), span: const Duration(hours: 42));
    EpgProgramme? current;
    EpgProgramme? next;
    for (final programme in list) {
      if (programme.start.isAfter(moment)) {
        next ??= programme;
        continue;
      }
      if (!programme.stop.isBefore(moment) && (current == null || programme.start.isAfter(current.start))) {
        current = programme;
      }
    }
    return IptvProgrammeSlot(current: current, next: next, at: moment);
  }

  /// How far before a schedule's start a programme may begin and still be
  /// shown as part of it.
  static const Duration _programmeLookback = Duration(days: 3);

  /// The programmes of [channel] from [from] for [span], by start.
  ///
  /// Empty for a channel with no guide channel behind it, which the interface
  /// shows as "这个频道没有节目单" rather than as a day with nothing on it.
  List<EpgProgramme> schedule(IptvChannel channel, {DateTime? from, Duration span = const Duration(hours: 6)}) {
    final key = guideKeyFor(channel);
    if (key == null) {
      return const [];
    }
    final start = from ?? DateTime.now();
    final end = start.add(span);
    // The stored query reports the lists that *start* inside its window, and a
    // guide row has to show the programme that began an hour ago with ninety
    // minutes still to run — so the read reaches back and the overlap is
    // decided here. Three days covers the longest programme anybody puts in a
    // guide without pretending to browse history.
    return [
      for (final programme in programmes(key, from: start.subtract(_programmeLookback), to: end))
        if (!programme.stop.isBefore(start) && !programme.start.isAfter(end)) programme,
    ];
  }

  /// The guide channels of [sourceId] whose names contain [query].
  ///
  /// For the mapping editor, which has to let the viewer find the right guide
  /// channel among thousands — the matcher's own name comparison is too strict
  /// to be a search over.
  List<EpgChannel> searchGuideChannels(String sourceId, String query) {
    final needle = query.trim().toLowerCase();
    final found = [
      for (final channel in guideChannels(sourceId))
        if (needle.isEmpty ||
            channel.primaryName.toLowerCase().contains(needle) ||
            channel.channelId.toLowerCase().contains(needle))
          channel,
    ];
    return List.unmodifiable(found);
  }

  /// Pins channel [channelId] to guide channel [epgChannelKey] of
  /// [epgSourceId], replacing whatever mapping it had.
  ///
  /// The mapping is locked: a viewer who chose a channel by hand outranks the
  /// matcher, whose job is to guess where nobody did.
  Future<void> assignGuide({
    required String channelId,
    required String epgSourceId,
    required String epgChannelKey,
    String playlistId = '',
  }) async {
    _mappings = [
      for (final mapping in _mappings)
        if (mapping.channelId != channelId) mapping,
      EpgMapping(
        channelId: channelId,
        epgChannelKey: epgChannelKey,
        playlistId: playlistId,
        epgSourceId: epgSourceId,
        locked: true,
        origin: 'user',
      ),
    ];
    await _commitGuide();
  }

  /// Drops every mapping of [channelId], which leaves it to the matcher's next
  /// run — an unassigned channel is unmapped until then, rather than snapped
  /// back to whatever the last automatic guess was.
  Future<void> releaseGuide(String channelId) async {
    final kept = [
      for (final mapping in _mappings)
        if (mapping.channelId != channelId) mapping,
    ];
    if (kept.length == _mappings.length) {
      return;
    }
    _mappings = kept;
    await _commitGuide();
  }

  /// Runs the matcher for one guide source over the whole library and stores
  /// what it decides; answers how many mappings it wrote or rewrote.
  ///
  /// Every channel is offered, not only those of one playlist: channels are
  /// shared between playlists by URL, so a per-playlist run would leave a
  /// channel mapped in one list and unmapped in the next. [playlistId] is
  /// bookkeeping on the rows it writes — which import decided them — and is
  /// empty for a library-wide pass like the one a guide refresh triggers.
  ///
  /// Locked and hand-made mappings survive the run untouched — that is the
  /// whole reason a mapping records who made it.
  Future<int> autoMatch({required String sourceId, String playlistId = ''}) async {
    final changes = rebuildMappings(
      playlistId: playlistId,
      sourceId: sourceId,
      channels: _channels,
      guideChannels: guideChannels(sourceId),
      previous: _mappings,
    );
    if (changes.upserts.isEmpty && changes.deletes.isEmpty) {
      return 0;
    }
    await applyMappings(upserts: changes.upserts, deletes: changes.deletes);
    return changes.upserts.length;
  }

  /// The playlist named [name] (case-insensitive), or null.
  ///
  /// The importer asks this before it writes anything: a name the user
  /// already has is a replacement, not a second playlist, and only the user
  /// can say whether that is what they meant.
  IptvPlaylist? playlistNamed(String name) {
    final wanted = name.trim().toLowerCase();
    for (final playlist in _playlists) {
      if (playlist.name.trim().toLowerCase() == wanted) {
        return playlist;
      }
    }
    return null;
  }

  /// Imports a parsed playlist, replacing the record named [replaceId] when
  /// given.
  ///
  /// The channels are reconciled by URL exactly as [importFromText] does —
  /// the user's favourites, hidden flags and ordering survive a re-import —
  /// and the playlist record is updated in place when it is a replacement,
  /// so a room that points at a channel id keeps working across a sync.
  Future<({String id, int channels, int added, int updated})> importResult(
    PlaylistParseResult result, {
    required String name,
    String? url,
    String? replaceId,
    bool removeMissing = false,
  }) async {
    final entries = result.entries;
    if (entries.isEmpty) {
      throw const StorageValidationException('playlist has no channels');
    }
    final byUrl = {for (final channel in _channels) channel.entry.url: channel};
    var nextPosition = _channels.isEmpty
        ? 0
        : _channels.map((channel) => channel.position).reduce((a, b) => a > b ? a : b) + 1;
    // A provider that numbered its whole list is worth believing: those
    // numbers are what its own docs tell people to dial. A list that
    // numbered three channels out of two hundred is not, and adopting them
    // would push the other one hundred and ninety-seven behind them.
    final adoptNumbers = _providerNumbersComplete(entries);
    final seenUrls = <String>{};
    final reconciled = <IptvChannel>[];
    var added = 0;
    var updated = 0;
    for (final entry in entries) {
      seenUrls.add(entry.url);
      final existing = byUrl[entry.url];
      if (existing != null) {
        reconciled.add(existing.copyWith(entry: entry));
        updated++;
      } else {
        reconciled.add(
          IptvChannel(
            id: 'c${DateTime.now().microsecondsSinceEpoch}_${reconciled.length}',
            entry: entry,
            position: nextPosition++,
            number: adoptNumbers ? entry.channelNumber : null,
          ),
        );
        added++;
      }
    }
    if (!removeMissing) {
      for (final channel in _channels) {
        if (!seenUrls.contains(channel.entry.url)) {
          reconciled.add(channel);
        }
      }
    }
    _channels = reconciled;
    final existing = replaceId == null ? null : _playlistById(replaceId);
    final id = existing?.id ?? 'p${DateTime.now().microsecondsSinceEpoch}';
    final record = IptvPlaylist(
      id: id,
      name: name,
      importedAt: DateTime.now(),
      url: url ?? existing?.url,
      channelCount: entries.length,
    );
    _playlists = [
      for (final playlist in _playlists)
        if (playlist.id != id) playlist,
      record,
    ];
    await store.saveChannels(_channels);
    await store.savePlaylists(_playlists);
    _changes.add(null);
    return (id: id, channels: entries.length, added: added, updated: updated);
  }

  IptvPlaylist? _playlistById(String id) {
    for (final playlist in _playlists) {
      if (playlist.id == id) {
        return playlist;
      }
    }
    return null;
  }

  /// Imports [text] as a playlist named [name], appending a record.
  ///
  /// [url] records the remote source when the text came from one. Returns
  /// the number of channels the text carried. Callers that need to replace a
  /// playlist of the same name, or to know how many channels were new, use
  /// [importResult] instead — this method keeps its original shape for the
  /// call sites that only wanted the count.
  Future<int> importFromText(String text, {required String name, String? url, bool removeMissing = false}) async {
    final entries = parsePlaylist(text);
    if (entries.isEmpty) {
      throw const StorageValidationException('playlist has no channels');
    }
    final byUrl = {for (final channel in _channels) channel.entry.url: channel};
    var nextPosition = _channels.isEmpty
        ? 0
        : _channels.map((channel) => channel.position).reduce((a, b) => a > b ? a : b) + 1;
    final adoptNumbers = _providerNumbersComplete(entries);
    final seenUrls = <String>{};
    final reconciled = <IptvChannel>[];
    for (final entry in entries) {
      seenUrls.add(entry.url);
      final existing = byUrl[entry.url];
      if (existing != null) {
        // Keep the user's flags; refresh the parsed fields.
        reconciled.add(existing.copyWith(entry: entry));
      } else {
        reconciled.add(
          IptvChannel(
            id: 'c${DateTime.now().microsecondsSinceEpoch}_${reconciled.length}',
            entry: entry,
            position: nextPosition++,
            number: adoptNumbers ? entry.channelNumber : null,
          ),
        );
      }
    }
    if (!removeMissing) {
      for (final channel in _channels) {
        if (!seenUrls.contains(channel.entry.url)) {
          reconciled.add(channel);
        }
      }
    }
    _channels = reconciled;
    _playlists = [
      ..._playlists,
      IptvPlaylist(
        id: 'p${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        importedAt: DateTime.now(),
        url: url,
        channelCount: entries.length,
      ),
    ];
    await store.saveChannels(_channels);
    await store.savePlaylists(_playlists);
    _changes.add(null);
    return entries.length;
  }

  /// Removes the playlist record [id] and, when it was the last one holding
  /// them, the channels only it carried.
  ///
  /// Channels are shared between playlists by URL, so deleting a source may
  /// leave channels another source still lists: those stay, and only the
  /// ones nothing else claims go with it.
  Future<void> deletePlaylist(String id) async {
    final record = _playlistById(id);
    if (record == null) {
      return;
    }
    _playlists = [
      for (final playlist in _playlists)
        if (playlist.id != id) playlist,
    ];
    // The playlist's mappings go with it: a mapping names one of its
    // channels, and that channel no longer exists.
    _mappings = [
      for (final mapping in _mappings)
        if (mapping.playlistId != id) mapping,
    ];
    await store.savePlaylists(_playlists);
    await store.saveGuideMappings(_mappings);
    _changes.add(null);
  }

  /// The playlist held at [id], or null.
  IptvPlaylist? playlistById(String id) => _playlistById(id);

  /// Toggles the favourite flag of [id].
  Future<void> toggleFavorite(String id) => _update(id, (channel) => channel.copyWith(favorite: !channel.favorite));

  /// Toggles the hidden flag of [id].
  Future<void> toggleHidden(String id) => _update(id, (channel) => channel.copyWith(hidden: !channel.hidden));

  /// Moves [id] to [position] in the channel order.
  Future<void> reorder(String id, int position) async {
    final ordered = [..._channels]..sort((a, b) => a.position.compareTo(b.position));
    final index = ordered.indexWhere((channel) => channel.id == id);
    if (index < 0) {
      return;
    }
    final moved = ordered.removeAt(index);
    ordered.insert(position.clamp(0, ordered.length), moved);
    _channels = [for (final (index, channel) in ordered.indexed) channel.copyWith(position: index)];
    await _commit();
  }

  /// Removes one channel.
  Future<void> remove(String id) async {
    final next = [
      for (final channel in _channels)
        if (channel.id != id) channel,
    ];
    if (next.length == _channels.length) {
      return;
    }
    _channels = next;
    await _commit();
  }

  // Numbers ------------------------------------------------------------------

  /// Hands out channel numbers, and answers how many channels needed one.
  ///
  /// Numbering runs over *every* channel, hidden ones included: hiding a
  /// channel takes it out of the walk, not out of the line-up, and a channel
  /// that comes back unhidden without a number would have to be numbered a
  /// second time. With [keepExisting] (the default) the numbers the user
  /// typed stay where they put them and only the channels without one are
  /// filled in.
  Future<int> assignNumbers({
    IptvNumberingMode mode = IptvNumberingMode.sequential,
    int startAt = 1,
    int groupBlock = 100,
    bool keepExisting = true,
  }) async {
    final ordered = orderedChannels;
    final assigned = assignChannelNumbers(
      ordered: ordered,
      mode: mode,
      groupRanks: groupRanks,
      startAt: startAt,
      groupBlock: groupBlock,
      keepExisting: keepExisting,
    );
    var changed = 0;
    _channels = [
      for (final channel in ordered)
        () {
          final number = assigned[channel.id];
          if (number == null || channel.number == number) {
            return channel;
          }
          changed++;
          return channel.copyWith(number: number);
        }(),
    ];
    if (changed > 0) {
      await _commit();
    }
    return changed;
  }

  /// Puts channel [id] on [number] and answers the id of the channel that
  /// had to move, null when nothing was in the way.
  ///
  /// A number that is taken is not a refusal: the channel holding it climbs
  /// to the next free number, the way a line-up editor moves a channel aside
  /// rather than rejecting the edit. The climb runs in display order, so the
  /// channel that was on the wanted number is the one that moves, and the
  /// one behind it is not dragged along by a neighbour it never touched.
  ///
  /// A [number] below 1 changes nothing: use [clearChannelNumber] when the
  /// viewer means "this one has no number", so a mistyped 0 cannot silently
  /// un-number a channel they were dialling.
  ///
  /// Answers null when there is no such channel, as well as when nothing
  /// moved.
  Future<String?> setChannelNumber(String id, int number) async {
    final target = channelById(id);
    if (target == null || number < 1 || target.number == number) {
      return null;
    }
    final ordered = orderedChannels;
    final placed = <String, int>{id: number};
    final used = <int>{number};
    String? displaced;
    for (final channel in ordered) {
      if (channel.id == id) {
        continue;
      }
      final held = channel.number;
      if (held == null || held < 1) {
        continue;
      }
      if (used.contains(held)) {
        final moved = iptvNextFreeNumber(used, held + 1);
        used.add(moved);
        placed[channel.id] = moved;
        displaced ??= channel.id;
      } else {
        used.add(held);
        placed[channel.id] = held;
      }
    }
    _channels = [for (final channel in ordered) channel.copyWith(number: placed[channel.id])];
    await _commit();
    return displaced;
  }

  /// Takes channel [id] out of the numbering.
  ///
  /// An unnumbered channel sorts after the numbered ones, which is where a
  /// viewer expects it to go when they delete the number they had typed;
  /// its old number is left free for whatever they put there next.
  Future<void> clearChannelNumber(String id) => _update(id, (channel) => channel.copyWith(number: null));

  /// Pins channel [id] to the front of the walk, or unpins it.
  Future<void> setChannelPinned(String id, {required bool pinned}) =>
      _update(id, (channel) => channel.copyWith(pinned: pinned));

  // Groups -------------------------------------------------------------------

  /// Moves the group [name] to [index] among the groups, creating its record
  /// when the user is arranging it for the first time.
  ///
  /// The orders are rewritten as a straight 0..n-1 run afterwards, because
  /// an order kept as "whatever number the user's drop happened to land on"
  /// drifts into a list with 400 groups and no room between two of them.
  /// A pinned group still sorts ahead of the run: pinning is the stronger
  /// statement, and undoing a pin by dragging should not be the user's
  /// problem.
  Future<void> setGroupOrder(String name, int index) async {
    final arranged = sortIptvGroups(_groups).map((group) => group.name).toList();
    if (!arranged.contains(name)) {
      arranged.add(name);
    }
    arranged.remove(name);
    arranged.insert(index.clamp(0, arranged.length), name);
    final records = <IptvGroup>[];
    for (final (position, groupName) in arranged.indexed) {
      final existing = _recordOf(groupName);
      records.add(existing?.copyWith(order: position) ?? IptvGroup(name: groupName, order: position));
    }
    // A group that is in neither the reordered run nor the channels any
    // more keeps its record: the user may re-import tomorrow.
    final known = arranged.toSet();
    _groups = [
      ...records,
      for (final group in _groups)
        if (!known.contains(group.name)) group,
    ];
    await _commitGroups();
  }

  /// Pins the group [name] to the front of the group list, or unpins it.
  Future<void> setGroupPinned(String name, {required bool pinned}) =>
      _updateGroup(name, (group) => group.copyWith(pinned: pinned));

  /// Takes the group [name] out of the walks and lists, or puts it back.
  ///
  /// The channels of a hidden group are not hidden themselves, so turning
  /// the group back on gives back exactly the line-up that was there before
  /// it was switched off — including the favourites and numbers inside it.
  Future<void> setGroupHidden(String name, {required bool hidden}) =>
      _updateGroup(name, (group) => group.copyWith(hidden: hidden));

  /// Whether the group [name] is switched off.
  ///
  /// A group with no record is on: the absence is the user never having
  /// said anything about it, and saying nothing is not hiding.
  bool isGroupHidden(String name) => _recordOf(name)?.hidden ?? false;

  /// Forgets the arrangement of the group [name], which returns it to the
  /// unarranged tail; answers whether there was a record to forget.
  Future<bool> forgetGroup(String name) async {
    final kept = [
      for (final group in _groups)
        if (group.name != name) group,
    ];
    if (kept.length == _groups.length) {
      return false;
    }
    _groups = kept;
    await _commitGroups();
    return true;
  }

  // Lines --------------------------------------------------------------------

  /// The channel's addresses, best first: the working line before the lines
  /// nobody has asked about, and those before the ones that failed.
  ///
  /// This is what a player should be handed as its candidate list, so a
  /// channel whose primary source died starts on a mirror instead of on a
  /// black screen, and the recovery ladder has somewhere to climb.
  ///
  /// A verdict older than [staleAfter] is not believed [now]: yesterday's
  /// dead mirror is tonight's unknown, and the playlist's own order gets to
  /// speak again once the evidence has aged out.
  List<IptvLineCandidate> candidateLines(
    IptvChannel channel, {
    DateTime? now,
    Duration staleAfter = const Duration(hours: 12),
  }) => rankIptvLines(channel, _health, now: now ?? DateTime.now(), staleAfter: staleAfter);

  /// Saves what the probes found, and answers how many verdicts changed.
  ///
  /// An address the probe never reached (because a better one answered
  /// first) keeps the verdict it already had: the probe abstained, it did
  /// not retract. The counting of consecutive failures is the probe
  /// package's [mergeIptvLineHealth]; this only decides what to write.
  Future<int> applyProbeReports(Iterable<IptvProbeReport> reports, {DateTime? now}) async {
    final merged = mergeIptvLineHealth(reports, previous: _health, now: now);
    var changed = 0;
    for (final entry in merged.entries) {
      if (_health[entry.key] != entry.value) {
        changed++;
      }
    }
    if (changed == 0) {
      return 0;
    }
    _health = merged;
    await _commitHealth();
    return changed;
  }

  /// Drops the verdicts made before [before].
  ///
  /// A verdict that old says nothing about tonight's servers, and keeping
  /// the history of them would grow the store to rank the same hundred
  /// addresses forever.
  Future<int> pruneLineHealth(DateTime before) async {
    final kept = {
      for (final entry in _health.entries)
        if (!entry.value.checkedAt.isBefore(before)) entry.key: entry.value,
    };
    if (kept.length == _health.length) {
      return 0;
    }
    final dropped = _health.length - kept.length;
    _health = kept;
    await _commitHealth();
    return dropped;
  }

  // Internals ----------------------------------------------------------------

  bool _providerNumbersComplete(List<IptvEntry> entries) =>
      entries.isNotEmpty && entries.every((entry) => entry.channelNumber != null);

  IptvGroup? _recordOf(String name) {
    for (final group in _groups) {
      if (group.name == name) {
        return group;
      }
    }
    return null;
  }

  Future<void> _updateGroup(String name, IptvGroup Function(IptvGroup) transform) async {
    final existing = _recordOf(name);
    _groups = [..._groups, if (existing == null) IptvGroup(name: name)];
    _groups = [
      for (final group in _groups)
        if (group.name == name) transform(group) else group,
    ];
    await _commitGroups();
  }

  Map<String, IptvLineHealth> _indexHealth(List<IptvLineHealth> records) => {
    for (final record in records) record.url: record,
  };

  Future<void> _commitGroups() async {
    _writing = true;
    _revision++;
    try {
      await store.saveGroups(_groups);
    } finally {
      _writing = false;
    }
    _changes.add(null);
  }

  Future<void> _commitHealth() async {
    _writing = true;
    _revision++;
    try {
      await store.saveLineHealth(_health.values.toList());
    } finally {
      _writing = false;
    }
    _changes.add(null);
  }

  /// Releases the library.
  Future<void> dispose() async {
    await _external?.cancel();
    _external = null;
    await _changes.close();
  }

  /// Replaces guide source [source] with [channels] and [programmes], and
  /// drops the sources in [duplicates] with everything of theirs.
  ///
  /// One write per list: a source's data is only ever replaced whole, because
  /// a guide that updated its channels but not its programmes shows a week of
  /// programmes under the wrong names. The source replaces the stored one of
  /// the same id — a sync must not leave two records of one guide — and
  /// [duplicates] are the sources the user named the same: importing a guide
  /// again under a name they already have must not leave two sources whose
  /// programmes fight over the same channels.
  Future<void> saveGuide(
    EpgSource source,
    List<EpgChannel> channels,
    List<EpgProgramme> programmes, {
    List<EpgSource> duplicates = const [],
  }) async {
    final dropped = {for (final duplicate in duplicates) duplicate.id};
    final merged = <EpgSource>[];
    var placed = false;
    for (final saved in _sources) {
      if (saved.id == source.id) {
        // A sync keeps its place in the list: the sources are shown in the
        // order they were imported, and refreshing one must not move it.
        merged.add(source);
        placed = true;
      } else if (!dropped.contains(saved.id)) {
        merged.add(saved);
      }
    }
    if (!placed) {
      merged.add(source);
    }
    _sources = merged;
    // The source's own previous rows go the way of the duplicates': a sync
    // replaces its channels and programmes, it does not add to them.
    final replaced = {...dropped, source.id};
    _guideChannels = [
      for (final channel in _guideChannels)
        if (!replaced.contains(channel.sourceId)) channel,
    ];
    _programmes = [
      for (final programme in _programmes)
        if (!replaced.contains(programme.sourceId)) programme,
    ];
    _mappings = [
      for (final mapping in _mappings)
        if (!replaced.contains(mapping.epgSourceId)) mapping,
    ];
    _guideChannels = [..._guideChannels, ...channels];
    _programmes = [..._programmes, ...programmes];
    await _commitGuide();
  }

  /// Updates the fields of a guide source without touching its data.
  Future<void> updateGuideSource(EpgSource source) async {
    if (guideSource(source.id) == null) {
      return;
    }
    _sources = [
      for (final saved in _sources)
        if (saved.id == source.id) source else saved,
    ];
    await _commitGuide();
  }

  /// Deletes the guide source [id] with its channels, its programmes and the
  /// mappings that named it; false when there is no such source.
  ///
  /// The mappings go with it because a mapping to a deleted guide would
  /// otherwise keep a room pointing at programmes that no longer exist.
  Future<bool> deleteGuideSource(String id) async {
    if (guideSource(id) == null) {
      return false;
    }
    _sources = [
      for (final source in _sources)
        if (source.id != id) source,
    ];
    _guideChannels = [
      for (final channel in _guideChannels)
        if (channel.sourceId != id) channel,
    ];
    _programmes = [
      for (final programme in _programmes)
        if (programme.sourceId != id) programme,
    ];
    _mappings = [
      for (final mapping in _mappings)
        if (mapping.epgSourceId != id) mapping,
    ];
    await _commitGuide();
    return true;
  }

  /// Applies the mappings the matcher computed: [upserts] replace whatever is
  /// stored for their channel, [deletes] name the guide keys to drop.
  Future<void> applyMappings({required List<EpgMapping> upserts, required List<EpgMapping> deletes}) async {
    if (upserts.isEmpty && deletes.isEmpty) {
      return;
    }
    final removed = {for (final mapping in deletes) '${mapping.channelId}\u0000${mapping.epgChannelKey}'};
    final replaced = {for (final mapping in upserts) mapping.channelId};
    _mappings = [
      for (final mapping in _mappings)
        if (!removed.contains('${mapping.channelId}\u0000${mapping.epgChannelKey}') &&
            !replaced.contains(mapping.channelId))
          mapping,
      ...upserts,
    ];
    await _commitGuide();
  }

  /// Deletes the programmes that stopped before [before].
  ///
  /// A guide carries days of past programmes; keeping them would grow the
  /// store without ever being read, because a guide shows what is on now.
  Future<void> pruneProgrammes(DateTime before) async {
    final kept = [
      for (final programme in _programmes)
        if (!programme.stop.isBefore(before)) programme,
    ];
    if (kept.length == _programmes.length) {
      return;
    }
    _programmes = kept;
    await _commitGuide();
  }

  Future<void> _commitGuide() async {
    _writing = true;
    _revision++;
    try {
      await store.saveGuideSources(_sources);
      await store.saveGuideChannels(_guideChannels);
      await store.saveGuideProgrammes(_programmes);
      await store.saveGuideMappings(_mappings);
    } finally {
      _writing = false;
    }
    _changes.add(null);
  }

  Future<void> _update(String id, IptvChannel Function(IptvChannel) transform) async {
    var changed = false;
    _channels = [
      for (final channel in _channels)
        if (channel.id == id)
          () {
            changed = true;
            return transform(channel);
          }()
        else
          channel,
    ];
    if (changed) {
      await _commit();
    }
  }

  /// A change the store reported: another writer's, or the library's own.
  ///
  /// The library's own writes are ignored while they are in flight, because
  /// reloading between the four lists one commit writes would undo the write
  /// still running. A commit that has already finished is a different matter:
  /// another window's store, and this one's own, both arrive here, and
  /// [_reload] decides whether the snapshot it read is still current.
  void _storeChanged() {
    if (_writing) {
      return;
    }
    unawaited(_reload());
  }

  /// Reads the store back, one pass at a time.
  ///
  /// The trap this guards: the store reports a write *after* it landed, so a
  /// reload that began before a commit and finished after it would install the
  /// older values over the newer ones — the viewer favourites a channel, the
  /// star appears, and a beat later it is gone. So the revision is read before
  /// the lists and checked after: if a commit got in between, this snapshot is
  /// stale and the pass is taken again rather than applied.
  ///
  /// Requests that arrive while a pass is running do not start a second read;
  /// they raise the re-run flag, so the pass going around once more ends up
  /// holding whatever the store said last.
  Future<void> _reload() async {
    if (_reloading) {
      _reloadAgain = true;
      return;
    }
    _reloading = true;
    try {
      do {
        _reloadAgain = false;
        final revision = _revision;
        final channels = await store.loadChannels();
        final playlists = await store.loadPlaylists();
        final sources = await store.loadGuideSources();
        final guideChannels = await store.loadGuideChannels();
        final programmes = await store.loadGuideProgrammes();
        final mappings = await store.loadGuideMappings();
        final groups = await store.loadGroups();
        final health = _indexHealth(await store.loadLineHealth());
        if (revision != _revision) {
          _reloadAgain = true;
          continue;
        }
        _channels = channels;
        _playlists = playlists;
        _sources = sources;
        _guideChannels = guideChannels;
        _programmes = programmes;
        _mappings = mappings;
        _groups = groups;
        _health = health;
      } while (_reloadAgain);
    } finally {
      _reloading = false;
    }
    if (_changes.isClosed) {
      // The library was disposed while this reload was queued.
      return;
    }
    _changes.add(null);
  }

  Future<void> _commit() async {
    _writing = true;
    _revision++;
    try {
      await store.saveChannels(_channels);
    } finally {
      _writing = false;
    }
    _changes.add(null);
  }
}
