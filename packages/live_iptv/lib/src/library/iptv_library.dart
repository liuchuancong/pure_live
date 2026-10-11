import 'dart:async';

import 'package:live_iptv/src/library/iptv_store.dart';
import 'package:live_iptv/src/model/iptv_models.dart';
import 'package:live_iptv/src/playlist/playlist_parser.dart';
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
  bool _loaded = false;
  StreamSubscription<void>? _external;

  /// Emits after every committed mutation.
  Stream<void> get changes => _changes.stream;

  /// The channels, ordered by position.
  List<IptvChannel> get channels => List.unmodifiable(_channels);

  /// The imported playlists.
  List<IptvPlaylist> get playlists => List.unmodifiable(_playlists);

  /// Loads the library (idempotent).
  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    _channels = await store.loadChannels();
    _playlists = await store.loadPlaylists();
    _external ??= store.changes.listen((_) => unawaited(_reload()));
  }

  /// Imports [text] as a playlist named [name].
  ///
  /// [url] records the remote source when the text came from one.
  /// Returns the number of channels the library now holds from the
  /// import.
  Future<int> importFromText(String text, {required String name, String? url, bool removeMissing = false}) async {
    final entries = parsePlaylist(text);
    if (entries.isEmpty) {
      throw const StorageValidationException('playlist has no channels');
    }
    final byUrl = {for (final channel in _channels) channel.entry.url: channel};
    var nextPosition = _channels.isEmpty
        ? 0
        : _channels.map((channel) => channel.position).reduce((a, b) => a > b ? a : b) + 1;
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

  /// Releases the library.
  Future<void> dispose() async {
    await _external?.cancel();
    _external = null;
    await _changes.close();
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

  Future<void> _commit() async {
    await store.saveChannels(_channels);
    _changes.add(null);
  }

  Future<void> _reload() async {
    _channels = await store.loadChannels();
    _playlists = await store.loadPlaylists();
    _changes.add(null);
  }
}

/// The library as the `live_sites` IPTV site's channel source: the site
/// layer exposes these through [sites.IptvSite] so IPTV channels play
/// through the ordinary playback stack.
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
    for (final channel in library.channels)
      if (includeHidden || !channel.hidden) _toSiteChannel(channel),
  ];

  @override
  sites.IptvChannel? channelById(String id) {
    for (final channel in library.channels) {
      if (channel.id == id) {
        return _toSiteChannel(channel);
      }
    }
    return null;
  }

  static sites.IptvChannel _toSiteChannel(IptvChannel channel) => sites.IptvChannel(
    id: channel.id,
    name: channel.entry.name,
    url: channel.entry.url,
    group: channel.entry.group,
    headers: channel.entry.headers,
    epgChannelId: channel.entry.tvgId,
    favorite: channel.favorite,
  );
}
