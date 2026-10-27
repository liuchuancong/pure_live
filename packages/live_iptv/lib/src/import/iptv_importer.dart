import 'dart:async';

import 'package:live_iptv/src/guide/guide.dart';
import 'package:live_iptv/src/import/iptv_import_result.dart';
import 'package:live_iptv/src/library/iptv_library/iptv_library.dart';
import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/playlist/playlist.dart';

/// Downloads a playlist or guide.
///
/// A seam rather than a dependency: this package stays transport-free, and
/// the application wires its own HTTP client (its proxy rules, its headers,
/// its retry policy) into this one function. That is also what makes an
/// import testable without a network.
typedef IptvFetcher = Future<String> Function(Uri url, {Map<String, String> headers});

/// Downloads a programme guide.
///
/// A second seam rather than a widening of [IptvFetcher]: guides are served
/// gzipped often enough that a textual seam could not read them at all (the
/// gzip magic has no textual form), and a playlist has no such need. An
/// application that only wires [IptvFetcher] still imports guides the user
/// pastes or picks as files.
typedef IptvBytesFetcher = Future<List<int>> Function(Uri url, {Map<String, String> headers});

/// Asks the user whether to replace the stored playlist called [name].
///
/// The answer decides between `imported` and `cancelled`; a caller that has
/// no one to ask (a background sync) leaves it null, and then a name clash
/// is `cancelled` rather than a silent overwrite.
typedef IptvReplaceConfirm = FutureOr<bool> Function(String name);

/// Imports, syncs and deletes IPTV playlists and programme guides over an
/// [IptvLibrary].
///
/// Three rules shape everything here. Operations are **serialized**: an
/// import and a sync touching the same channel list would otherwise
/// interleave their writes and leave a library that matches neither. A name
/// the user already has is a **replacement, asked about**, never a silent
/// overwrite and never a second playlist with the same name. And a broken
/// file — unreadable, empty, or cut off mid-download — **keeps what is
/// stored**: the stored copy is the only one the user has.
///
/// A guide is stored whole per source: its channels and its programmes are
/// replaced together, and the sources that carried the same name are dropped
/// with theirs, because two guides under one name would fight over the same
/// channels. Programmes that have already stopped are pruned after every
/// import ([programmeRetention] of them), so a guide that syncs daily does
/// not grow without bound.
final class IptvImporter {
  /// An importer over [library]; [fetch] downloads remote sources and
  /// [fetchBytes] remote guides.
  new({required this.library, required this.fetch, this.fetchBytes});

  /// The library every import writes to.
  final IptvLibrary library;

  /// How remote sources are downloaded.
  final IptvFetcher fetch;

  /// How remote guides are downloaded, when the application wires one.
  final IptvBytesFetcher? fetchBytes;

  /// How long a guide's past programmes are kept after an import.
  ///
  /// A guide shows what is on now and next; keeping days of what already
  /// ended would grow the store without ever being read.
  static const Duration programmeRetention = Duration(days: 2);

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

  // Guides -------------------------------------------------------------------

  /// Imports guide [text] under [name], recording [source] (the URL or the
  /// file path it came from) so [syncGuide] can read it again.
  ///
  /// [expected] makes this a sync of a stored source: the source must still be
  /// the record on screen, or nothing is written. A name the user already has
  /// is a replacement, asked about, and the *other* sources carrying that name
  /// are dropped with their data — an import that left two guides under one
  /// name would show one guide's channels with the other's programmes.
  Future<IptvImportResult> importGuideText(
    String text, {
    required String name,
    required String source,
    bool force = false,
    EpgSource? expected,
    IptvReplaceConfirm? confirmReplace,
  }) => _serial(
    () => _importGuide(
      text: text,
      name: name,
      source: source,
      force: force,
      expected: expected,
      confirmReplace: confirmReplace,
    ),
  );

  /// Downloads [url] and imports it as a guide.
  ///
  /// Answers [IptvImportStatus.networkFailed] when the application wired no
  /// [fetchBytes]: reading a gzipped guide needs bytes, and this package will
  /// not guess that a text download was decompressed for it.
  Future<IptvImportResult> importGuideFromUrl({
    required Uri url,
    required String name,
    Map<String, String> headers = const {},
    bool force = false,
    IptvReplaceConfirm? confirmReplace,
  }) => _serial(() async {
    final List<int> bytes;
    try {
      bytes = await _downloadGuideBytes(url, headers);
    } on _NoBytesFetcher catch (error) {
      return IptvImportResult(IptvImportStatus.networkFailed, error: error);
    } on Object catch (error) {
      return IptvImportResult(IptvImportStatus.networkFailed, error: error);
    }
    final String text;
    try {
      text = decodeGuideBytes(bytes);
    } on FormatException catch (error) {
      return IptvImportResult(IptvImportStatus.invalid, error: error);
    }
    return await _importGuide(
      text: text,
      name: name,
      source: url.toString(),
      force: force,
      expected: null,
      confirmReplace: confirmReplace,
    );
  });

  /// Re-reads the stored guide [source] from the address it was imported
  /// from, keeping its id.
  ///
  /// A source whose guide is a local file cannot be synced here: the path is
  /// the application's filesystem, which this package does not touch.
  Future<IptvImportResult> syncGuide(EpgSource source) => _serial(() async {
    final current = library.guideSource(source.id);
    if (current == null) {
      return IptvImportResult(IptvImportStatus.stale);
    }
    if (!current.isRemote) {
      return IptvImportResult(IptvImportStatus.unsupportedFormat, error: 'the guide is a file, not an address');
    }
    final Uri uri;
    try {
      uri = Uri.parse(current.source.trim());
    } on FormatException catch (error) {
      return IptvImportResult(IptvImportStatus.unsupportedFormat, error: error);
    }
    final List<int> bytes;
    try {
      bytes = await _downloadGuideBytes(uri, const {});
    } on _NoBytesFetcher catch (error) {
      return IptvImportResult(IptvImportStatus.networkFailed, error: error);
    } on Object catch (error) {
      return IptvImportResult(IptvImportStatus.networkFailed, error: error);
    }
    final String text;
    try {
      text = decodeGuideBytes(bytes);
    } on FormatException catch (error) {
      return IptvImportResult(IptvImportStatus.invalid, error: error);
    }
    return await _importGuide(
      text: text,
      name: current.name,
      source: current.source,
      force: true,
      expected: current,
      confirmReplace: null,
    );
  });

  /// Deletes the guide [expected] with its channels, programmes and mappings,
  /// if it is still the record on screen.
  Future<bool> deleteGuide(EpgSource expected) => _serial(() async {
    final current = library.guideSource(expected.id);
    if (current == null) {
      return false;
    }
    return await library.deleteGuideSource(current.id);
  });

  /// Syncs every remote guide with automatic sync on that was last refreshed
  /// at least [olderThan] ago.
  ///
  /// The global switch is the caller's: this only answers what the sources
  /// say about themselves.
  Future<List<IptvImportResult>> syncExpiredGuides({required Duration olderThan, DateTime? now}) async {
    final moment = now ?? DateTime.now();
    final expired = [
      for (final source in library.guideSources)
        if (source.isRemote && source.autoUpdate)
          if (source.lastRefresh == null || moment.difference(source.lastRefresh!) >= olderThan) source,
    ];
    final results = <IptvImportResult>[];
    for (final source in expired) {
      results.add(await syncGuide(source));
    }
    return results;
  }

  /// The guide's bytes, from [fetchBytes] when the application wired one.
  Future<List<int>> _downloadGuideBytes(Uri url, Map<String, String> headers) async {
    final bytes = fetchBytes;
    if (bytes == null) {
      throw _NoBytesFetcher();
    }
    return await bytes(url, headers: headers);
  }

  /// Parses [text], decides about the name, and writes the guide.
  Future<IptvImportResult> _importGuide({
    required String text,
    required String name,
    required String source,
    required bool force,
    required EpgSource? expected,
    required IptvReplaceConfirm? confirmReplace,
  }) async {
    final ParsedGuide parsed;
    try {
      parsed = parseGuide(text);
    } on FormatException catch (error) {
      return IptvImportResult(IptvImportStatus.invalid, error: error);
    }
    if (parsed.isEmpty) {
      return IptvImportResult(IptvImportStatus.unsupportedFormat, error: 'no channels and no programmes were read');
    }
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      return IptvImportResult(IptvImportStatus.invalid, error: 'the guide needs a name');
    }
    final List<EpgSource> matched;
    if (expected == null) {
      matched = [
        for (final stored in library.guideSources)
          if (stored.name.trim().toLowerCase() == cleanName.toLowerCase()) stored,
      ];
    } else {
      final current = library.guideSource(expected.id);
      if (current == null) {
        return IptvImportResult(IptvImportStatus.stale);
      }
      matched = [current];
    }
    if (matched.isNotEmpty && !force) {
      final confirm = confirmReplace;
      var confirmed = false;
      if (confirm != null) {
        confirmed = await Future.value(confirm(cleanName));
      }
      if (!confirmed) {
        return IptvImportResult(IptvImportStatus.cancelled, id: matched.first.id);
      }
    }
    final moment = DateTime.now();
    final existing = matched.isEmpty ? null : matched.first;
    final id = existing?.id ?? 'epg-${moment.microsecondsSinceEpoch}-${parsed.channels.length}';
    final saved =
        existing?.rebuild((b) => b..name = cleanName..source = source..lastRefresh = moment) ??
        EpgSource.of(id: id, name: cleanName, source: source, lastRefresh: moment, createdAt: moment);
    try {
      await library.saveGuide(
        saved,
        [
          for (final channel in parsed.channels)
            EpgChannel.of(
              sourceId: id,
              channelId: channel.id,
              displayName: channel.displayNames.isEmpty ? '' : channel.displayNames.first,
              iconUrl: channel.iconUrl,
            ),
        ],
        [for (final programme in parsed.programmes) programme.rebuild((b) => b..sourceId = id)],
        duplicates: matched.skip(1).toList(),
      );
      await library.pruneProgrammes(moment.subtract(programmeRetention));
      return IptvImportResult(IptvImportStatus.imported, id: id, channels: parsed.channels.length);
    } on Object catch (error) {
      return IptvImportResult(IptvImportStatus.failed, error: error);
    }
  }
}

/// The application wired no byte fetcher, so a remote guide cannot be read.
class _NoBytesFetcher implements Exception {
  new();

  @override
  String toString() => 'no byte fetcher: remote guides cannot be downloaded';
}
