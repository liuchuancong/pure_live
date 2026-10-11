import 'dart:async';

import 'package:live_iptv/src/import/iptv_import_result.dart';
import 'package:live_iptv/src/library/iptv_library.dart';
import 'package:live_iptv/src/model/iptv_models.dart';
import 'package:live_iptv/src/playlist/playlist_parse_result.dart';
import 'package:live_iptv/src/playlist/playlist_parser.dart';

/// Downloads a playlist or guide.
///
/// A seam rather than a dependency: this package stays transport-free, and
/// the application wires its own HTTP client (its proxy rules, its headers,
/// its retry policy) into this one function. That is also what makes an
/// import testable without a network.
typedef IptvFetcher = Future<String> Function(Uri url, {Map<String, String> headers});

/// Asks the user whether to replace the stored playlist called [name].
///
/// The answer decides between `imported` and `cancelled`; a caller that has
/// no one to ask (a background sync) leaves it null, and then a name clash
/// is `cancelled` rather than a silent overwrite.
typedef IptvReplaceConfirm = FutureOr<bool> Function(String name);

/// Imports, syncs and deletes IPTV playlists over an [IptvLibrary].
///
/// Three rules shape everything here. Operations are **serialized**: an
/// import and a sync touching the same channel list would otherwise
/// interleave their writes and leave a library that matches neither. A name
/// the user already has is a **replacement, asked about**, never a silent
/// overwrite and never a second playlist with the same name. And a broken
/// file — unreadable, empty, or cut off mid-download — **keeps what is
/// stored**: the stored playlist is the only copy the user has.
///
/// Programme guides are not imported here yet: the guide parsing and
/// matching are in place, and importing them needs the guide storage in the
/// library first.
final class IptvImporter {
  /// An importer over [library]; [fetch] downloads remote sources.
  new({required this.library, required this.fetch});

  /// The library every import writes to.
  final IptvLibrary library;

  /// How remote sources are downloaded.
  final IptvFetcher fetch;

  Future<void> _tail = Future<void>.value();

  /// Runs [task] after every operation already queued.
  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  /// Imports playlists [text] under [name], asking before it replaces one of
  /// the same name.
  ///
  /// [url] records the remote source so [syncPlaylist] can re-read it later.
  Future<IptvImportResult> importPlaylistText({
    required String text,
    required String name,
    String? url,
    IptvReplaceConfirm? confirmReplace,
    bool force = false,
  }) => _serial(() => _import(text: text, name: name, url: url, confirmReplace: confirmReplace, force: force));

  /// Downloads [url] and imports it under [name].
  ///
  /// The name defaults to nothing: a source's own name is the caller's
  /// decision, because the URL's last segment is a file name and the
  /// playlist's own `#PLAYLIST:` header is optional — neither is a name the
  /// user chose.
  Future<IptvImportResult> importPlaylistFromUrl({
    required Uri url,
    required String name,
    Map<String, String> headers = const {},
    IptvReplaceConfirm? confirmReplace,
    bool force = false,
  }) => _serial(() async {
    final String text;
    try {
      text = await fetch(url, headers: headers);
    } on Object catch (error) {
      return IptvImportResult(IptvImportStatus.networkFailed, error: error);
    }
    return await _import(text: text, name: name, url: url.toString(), confirmReplace: confirmReplace, force: force);
  });

  /// Re-downloads [playlist] from the address it was imported from.
  ///
  /// The channels are reconciled by URL, so the user's favourites, hidden
  /// flags and ordering survive — and the record keeps its id, which is what
  /// keeps a room that points at a channel id working across a sync.
  Future<IptvImportResult> syncPlaylist(IptvPlaylist playlist) => _serial(() async {
    final url = playlist.url;
    final current = library.playlistById(playlist.id);
    if (url == null || url.isEmpty) {
      return IptvImportResult(IptvImportStatus.unsupportedFormat);
    }
    if (current == null) {
      // The playlist was deleted while this sync was queued.
      return IptvImportResult(IptvImportStatus.stale);
    }
    final Uri uri;
    try {
      uri = Uri.parse(url);
    } on FormatException catch (error) {
      return IptvImportResult(IptvImportStatus.unsupportedFormat, error: error);
    }
    final String text;
    try {
      text = await fetch(uri);
    } on Object catch (error) {
      return IptvImportResult(IptvImportStatus.networkFailed, error: error);
    }
    final result = parsePlaylistResult(text);
    if (result.entries.isEmpty) {
      return IptvImportResult(
        IptvImportStatus.invalid,
        issues: result.issues,
        error: 'the source answered no channels',
      );
    }
    if (result.truncated) {
      // A cut-off download must not replace a working playlist: the stored
      // one is the only complete copy the user has.
      return IptvImportResult(IptvImportStatus.invalid, issues: result.issues, error: 'the download was cut off');
    }
    return await _write(result, name: current.name, replaceId: current.id, url: url);
  });

  /// Deletes the playlist [expected], if it is still the record on screen.
  ///
  /// The id check is what stops a delete from removing a playlist that was
  /// replaced between the screen rendering and the tap.
  Future<bool> deletePlaylist(IptvPlaylist expected) => _serial(() async {
    final current = library.playlistById(expected.id);
    if (current == null) {
      return false;
    }
    await library.deletePlaylist(current.id);
    return true;
  });

  /// Syncs every remote playlist older than [olderThan].
  ///
  /// Serial by construction: [syncPlaylist] queues, so a batch that takes
  /// minutes cannot interleave with the user importing something by hand.
  Future<List<IptvImportResult>> syncExpired({required Duration olderThan, DateTime? now}) async {
    final moment = now ?? DateTime.now();
    final expired = [
      for (final playlist in library.playlists)
        if ((playlist.url ?? '').isNotEmpty)
          if (moment.difference(playlist.importedAt) >= olderThan) playlist,
    ];
    final results = <IptvImportResult>[];
    for (final playlist in expired) {
      results.add(await syncPlaylist(playlist));
    }
    return results;
  }

  /// Parses, decides about the name, and writes.
  Future<IptvImportResult> _import({
    required String text,
    required String name,
    required String? url,
    required IptvReplaceConfirm? confirmReplace,
    required bool force,
  }) async {
    final result = parsePlaylistResult(text);
    if (result.truncated) {
      return IptvImportResult(IptvImportStatus.invalid, issues: result.issues, error: 'the file ends mid-stanza');
    }
    if (result.entries.isEmpty) {
      return IptvImportResult(
        IptvImportStatus.unsupportedFormat,
        issues: result.issues,
        error: 'no channels were read',
      );
    }
    final existing = library.playlistNamed(name);
    if (existing != null && !force) {
      final confirm = confirmReplace;
      var confirmed = false;
      if (confirm != null) {
        confirmed = await Future.value(confirm(name));
      }
      if (!confirmed) {
        return IptvImportResult(IptvImportStatus.cancelled, id: existing.id, issues: result.issues);
      }
    }
    return await _write(result, name: name, replaceId: existing?.id, url: url);
  }

  /// Writes a parsed playlist, mapping storage failures to a status.
  Future<IptvImportResult> _write(
    PlaylistParseResult result, {
    required String name,
    required String? replaceId,
    required String? url,
  }) async {
    try {
      final written = await library.importResult(result, name: name, url: url, replaceId: replaceId);
      return IptvImportResult(
        IptvImportStatus.imported,
        id: written.id,
        channels: written.channels,
        issues: result.issues,
      );
    } on Object catch (error) {
      return IptvImportResult(IptvImportStatus.failed, issues: result.issues, error: error);
    }
  }
}
