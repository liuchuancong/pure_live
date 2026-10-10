// Module: lib/src/watch_later.dart
// Purpose: The built-in "稍后再看" list, and the import path that turns external text into a playlist.
// Author: liuchuancong
// Created: 2026-10-11
//
// playlist.md makes WatchLater a system playlist, which means three things an ordinary list does not have to
// hold: it always exists, it cannot be deleted, and adding something that is already in it moves the row rather
// than appending a second copy - "稍后再看" is a queue with an intent, not a set of bookmarks. The importer next
// to it exists because an imported list arrives as text with a title the user already has, and silently making
// "My List (2)" is how two playlists end up with the same meaning and no way back.

import 'package:pure_live_platform/pure_live_platform.dart';

import 'm3u.dart';
import 'playlist.dart';

/// The built-in list's identity, fixed so it survives a rename of its title.
final class WatchLater {
  const WatchLater._();

  /// The repository key. Not user-visible and never reused for a user list.
  static const String id = 'system.watch-later';

  /// The default title; a rename changes the title only, never this id.
  static const String defaultTitle = '稍后再看';

  /// Rows the list holds by default. An unbounded "later" list is a second library nobody reads.
  static const int defaultCapacity = 200;
}

/// The queue behaviour of the system list, over an ordinary [PlaylistsService].
final class WatchLaterService {
  WatchLaterService({required this.playlists, this.capacity = WatchLater.defaultCapacity});

  final PlaylistsService playlists;
  final int capacity;

  /// The list itself, created empty on first use so a fresh install has the tile without a setup step.
  Future<Playlist> open() async {
    try {
      return await playlists.get(WatchLater.id);
    } on PlaylistException catch (error) {
      if (error.kind != PlaylistFailure.notFound) {
        rethrow;
      }
      return playlists.create(WatchLater.id, WatchLater.defaultTitle);
    }
  }

  /// Adds [item] at the front, or moves its existing row there.
  ///
  /// Moving rather than appending is the whole point: a user who saves the same video twice has not changed
  /// their mind about the video, and two rows would push the other twelve down for nothing.
  Future<Playlist> save(PlaylistItem item) async {
    final playlist = await open();
    final items = List<PlaylistItem>.of(playlist.items);
    final existing = items.indexWhere((candidate) => candidate.ref == item.ref);
    if (existing >= 0) {
      items.removeAt(existing);
    }
    items.insert(0, item);
    final kept = items.length > capacity ? items.take(capacity).toList(growable: false) : items;
    return playlists.replaceItems(WatchLater.id, kept);
  }

  Future<Playlist> drop(ContentRef ref) async {
    final playlist = await open();
    final items = List<PlaylistItem>.of(playlist.items);
    items.removeWhere((candidate) => candidate.ref == ref);
    return playlists.replaceItems(WatchLater.id, items);
  }

  Future<Playlist> next() async {
    final playlist = await open();
    if (playlist.isEmpty) {
      return playlist;
    }
    final items = List<PlaylistItem>.of(playlist.items)..removeAt(0);
    return playlists.replaceItems(WatchLater.id, items);
  }

  Future<List<PlaylistItem>> peek({int limit = 10}) async {
    final playlist = await open();
    return List<PlaylistItem>.unmodifiable(playlist.items.take(limit < 1 ? 1 : limit));
  }

  Future<Playlist> rename(String title) async => playlists.rename(WatchLater.id, title);

  /// The system list is not deletable; the UI has no button for it and this has no reason to trust that it
  /// never calls one.
  Future<void> refuseDelete() async {
    throw const PlaylistException(
      PlaylistFailure.notFound,
      'the built-in Watch Later list cannot be deleted; clear it instead',
    );
  }
}

/// What an import produced, with everything it had to decide about.
final class PlaylistImportResult {
  const PlaylistImportResult({
    required this.playlist,
    required this.import,
    required this.resolvedCount,
    required this.titleUsed,
    required this.renamed,
  });

  final Playlist playlist;
  final M3uImport import;

  /// Entries whose reference the caller could resolve into this app's content.
  final int resolvedCount;

  /// The title actually stored, which is [requestedTitle] unless the user already had that list.
  final String titleUsed;

  /// True when [requestedTitle] was taken and a counter was appended.
  final bool renamed;

  /// Rows the caller's mapping could not place, so the import screen can say "3 of 40 lines were not ours".
  int get unresolvedCount => import.entries.length - resolvedCount;

  @override
  String toString() =>
      'PlaylistImportResult(${playlist.id}, $resolvedCount/${import.entries.length} rows'
      '${renamed ? ', renamed to $titleUsed' : ''})';
}

/// Turns M3U text into a new playlist.
///
/// The import always creates a list rather than merging into one: merging needs a rule for "same row twice" and
/// "same title in two lists" that belongs to the UI's intent, and an importer that guesses can't be undone.
Future<PlaylistImportResult> importM3uAsPlaylist({
  required PlaylistsService playlists,
  required String text,
  required String requestedTitle,
  required ContentRef? Function(M3uEntry entry) refFor,
  Uri? baseUri,
  int maxEntries = 5000,
}) async {
  final parsed = parseM3u(text, baseUri: baseUri, maxEntries: maxEntries);
  final items = itemsFromM3u(parsed.entries, refFor: refFor);
  final id = await _freeId(playlists, requestedTitle);
  final title = await _freeTitle(playlists, requestedTitle);
  final created = await playlists.create(id, title);
  if (items.isEmpty) {
    return PlaylistImportResult(
      playlist: created,
      import: parsed,
      resolvedCount: 0,
      titleUsed: title,
      renamed: title != requestedTitle,
    );
  }
  final filled = await playlists.addAllItems(id, items);
  return PlaylistImportResult(
    playlist: filled,
    import: parsed,
    resolvedCount: items.length,
    titleUsed: title,
    renamed: title != requestedTitle,
  );
}

String _slug(String title) {
  final cleaned = title.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  return cleaned.isEmpty ? 'playlist' : cleaned;
}

Future<String> _freeId(PlaylistsService playlists, String title) async {
  final base = _slug(title);
  final taken = <String>{for (final playlist in await playlists.list()) playlist.id};
  if (!taken.contains(base)) {
    return base;
  }
  for (var suffix = 2; suffix < 1000; suffix++) {
    final candidate = '$base-$suffix';
    if (!taken.contains(candidate)) {
      return candidate;
    }
  }
  throw PlaylistException(PlaylistFailure.duplicateId, 'no free id for a playlist titled "$title"');
}

Future<String> _freeTitle(PlaylistsService playlists, String title) async {
  final wanted = title.trim();
  final taken = <String>{for (final playlist in await playlists.list()) playlist.title};
  if (!taken.contains(wanted)) {
    return wanted;
  }
  for (var suffix = 2; suffix < 1000; suffix++) {
    final candidate = '$wanted ($suffix)';
    if (!taken.contains(candidate)) {
      return candidate;
    }
  }
  throw PlaylistException(PlaylistFailure.duplicateId, 'no free title for "$wanted"');
}
