import 'dart:async';

import 'package:live_iptv/src/library/iptv_store.dart';
import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/order/iptv_channel_ordering.dart';
import 'package:live_iptv/src/order/iptv_zap_sequence.dart';
import 'package:live_iptv/src/playlist/playlist_parse_result.dart';
import 'package:live_iptv/src/playlist/playlist_parser.dart';
import 'package:live_iptv/src/probe/iptv_line_prober.dart';
import 'package:live_sites/live_sites.dart' as sites;
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
    try {
      await store.saveGroups(_groups);
    } finally {
      _writing = false;
    }
    _changes.add(null);
  }

  Future<void> _commitHealth() async {
    _writing = true;
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
  /// The library's own writes are ignored, because a reload there would read
  /// the lists back while they are still being saved — a commit that writes
  /// four lists fires an event per list, and reloading between two of them
  /// would undo the write that is in flight.
  void _storeChanged() {
    if (_writing) {
      return;
    }
    unawaited(_reload());
  }

  Future<void> _commit() async {
    _writing = true;
    try {
      await store.saveChannels(_channels);
    } finally {
      _writing = false;
    }
    _changes.add(null);
  }

  Future<void> _reload() async {
    _channels = await store.loadChannels();
    _playlists = await store.loadPlaylists();
    _sources = await store.loadGuideSources();
    _guideChannels = await store.loadGuideChannels();
    _programmes = await store.loadGuideProgrammes();
    _mappings = await store.loadGuideMappings();
    _groups = await store.loadGroups();
    _health = _indexHealth(await store.loadLineHealth());
    if (_changes.isClosed) {
      // The library was disposed while this reload was queued.
      return;
    }
    _changes.add(null);
  }
}

/// The library as the `live_sites` IPTV site's channel source: the site
/// layer exposes these through [sites.IptvSite] so IPTV channels play
/// through the ordinary playback stack.
///
/// The channels come out in zap order rather than in import order, because
/// the site's directory is what a screen lists and what a remote steps
/// through: the two must agree, or the sixth row of the list is not the
/// sixth channel the down key reaches. Hidden channels and hidden groups
/// are left out unless [includeHidden] asks for them, and the line of each
/// channel is the health-ranked candidate list, so a source that died on
/// the last probe hands the player its mirror instead of a dead URL.
final class LibraryIptvChannelSource implements sites.IptvChannelSource {
  /// A source over [library]; [includeHidden] keeps hidden channels out
  /// by default.
  new(this.library, {this.includeHidden = false});

  /// The library to read.
  final IptvLibrary library;

  /// Whether hidden channels are exposed.
  final bool includeHidden;

  @override
  List<sites.IptvChannel> get channels => [
    for (final channel in library.zapSequence(includeHidden: includeHidden).channels) _toSiteChannel(channel),
  ];

  @override
  sites.IptvChannel? channelById(String id) {
    // Looked up by id, a hidden channel is still there: [channels] is the
    // list the viewer walks, while an id is something a room already holds.
    // Refusing here would kill a stream the user is watching the moment
    // they hide its channel, and a hidden channel is a request to not be
    // offered it, not a request to be cut off from it.
    final channel = library.channelById(id);
    if (channel == null) {
      return null;
    }
    return _toSiteChannel(channel);
  }

  sites.IptvChannel _toSiteChannel(IptvChannel channel) => sites.IptvChannel(
    id: channel.id,
    name: channel.entry.name,
    url: channel.entry.url,
    group: channel.entry.group,
    headers: channel.entry.headers,
    epgChannelId: channel.entry.tvgId,
    favorite: channel.favorite,
    number: channel.number,
    lines: [
      for (final candidate in library.candidateLines(channel))
        sites.IptvLine(url: candidate.url, headers: candidate.headers, lineId: candidate.isHealthy ? 'healthy' : null),
    ],
  );
}
