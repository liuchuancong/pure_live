import 'dart:async';
import 'dart:isolate' show Isolate;

import 'package:live_iptv/src/guide/guide.dart';
import 'package:live_iptv/src/import/iptv_import_preview.dart';
import 'package:live_iptv/src/import/iptv_import_result.dart';
import 'package:live_iptv/src/library/iptv_library/iptv_library.dart';
import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/playlist/playlist.dart';
import 'package:live_log/live_log.dart' show LiveLog, LogLevel;
import 'package:live_net/live_net.dart' show HttpStatusFailure, TimeoutFailure, TlsFailure;

/// The guide's decode and parse, run where they belong: a guide is tens of
/// megabytes, and both passes freeze the calling isolate while they read.
///
/// These are top-level on purpose. A closure made inside an instance method
/// carries the instance in its captured context, and the importer holds
/// unsendable fields (the serial write chain's futures) — the send would
/// fail on the second import, the one whose chain was no longer null.
Future<String> _decodeGuideBytesIsolated(List<int> bytes) => Isolate.run(() => decodeGuideBytes(bytes));

Future<ParsedGuide> _parseGuideIsolated(String text) => Isolate.run(() => parseGuide(text));

Future<IptvDecodedText> _decodeIptvTextIsolated(List<int> bytes) => Isolate.run(() => decodeIptvText(bytes));

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
/// overwrite and never a second playlist with the same name — and an
/// address the user already has is that playlist, updated, never a second
/// copy of it. And a broken file — unreadable, empty, a web page, or cut off
/// mid-download — **keeps what is stored**: the stored copy is the only one
/// the user has.
///
/// An import can be split in two: a preview reads and judges the source
/// without writing ([previewPlaylistFromUrl], [previewPlaylistText],
/// [previewPlaylistBytes]), and a commit writes exactly what was previewed
/// ([commitPlaylistPreview]). The one-step imports remain for callers with
/// nobody to show a preview to.
///
/// A guide is stored whole per source: its channels and its programmes are
/// replaced together, and the sources that carried the same name are dropped
/// with theirs, because two guides under one name would fight over the same
/// channels. Programmes that have already stopped are pruned after every
/// import ([programmeRetention] of them), so a guide that syncs daily does
/// not grow without bound.
final class IptvImporter {
  /// An importer over [library]; [fetch] downloads remote sources and
  /// [fetchBytes] remote guides. [fetchPlaylistBytes], when wired, downloads
  /// playlists as bytes, so their encoding is read from the bytes themselves
  /// (and named in a preview) and a gzipped list inflates. [log] is the
  /// owner's category view — every verdict this importer answers (the
  /// statuses the UI words) and every storage failure it absorbs lands there.
  new({required this.library, required this.fetch, this.fetchBytes, this.fetchPlaylistBytes, LiveLog? log})
    // A private named parameter cannot be an initializing formal; the field
    // stays private so the verdict logging never leaks into the seam's API.
    // ignore: prefer_initializing_formals
    : _log = log;

  /// The verdict log; null keeps the importer quiet.
  final LiveLog? _log;

  /// The library every import writes to.
  final IptvLibrary library;

  /// How remote sources are downloaded.
  final IptvFetcher fetch;

  /// How remote guides are downloaded, when the application wires one.
  final IptvBytesFetcher? fetchBytes;

  /// How remote playlists are downloaded as bytes, when the application
  /// wires one; [fetch] reads them otherwise.
  final IptvBytesFetcher? fetchPlaylistBytes;

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

  // Playlist previews ---------------------------------------------------------

  /// Reads playlist [text] and judges it, writing nothing.
  ///
  /// [url] is the address the text came from, when it came from one: it
  /// names the stored playlist that already has it, and an Xtream panel's
  /// list keeps only its live rows.
  IptvPlaylistPreview previewPlaylistText(String text, {String? url, IptvTextEncoding? encoding}) {
    final result = _read(text, url: url);
    return IptvPlaylistPreview(
      result: result,
      url: url,
      encoding: encoding,
      urlClash: url == null ? null : library.playlistWithUrl(url),
      failure: _unreadable(result),
    );
  }

  /// Decodes a picked file's [bytes] and previews them.
  IptvPlaylistPreview previewPlaylistBytes(List<int> bytes) {
    final IptvDecodedText decoded;
    try {
      decoded = decodeIptvText(bytes);
    } on FormatException catch (error) {
      return IptvPlaylistPreview.failed(
        IptvImportResult(IptvImportStatus.invalid, failure: IptvImportFailure.unreadable, error: error),
      );
    }
    return previewPlaylistText(decoded.text, encoding: decoded.encoding);
  }

  /// Downloads [url] and previews it.
  Future<IptvPlaylistPreview> previewPlaylistFromUrl(Uri url, {Map<String, String> headers = const {}}) async {
    final ({String text, IptvTextEncoding? encoding}) download;
    try {
      download = await _downloadPlaylist(url, headers);
    } on Object catch (error, stack) {
      _logDownload('preview', url, error, stack);
      return IptvPlaylistPreview.failed(_downloadFailure(error), url: url.toString());
    }
    return previewPlaylistText(download.text, url: url.toString(), encoding: download.encoding);
  }

  /// Writes [preview] under [name], replacing the playlist [replaceId] when
  /// given, and hides the groups in [hiddenGroups] (by their key, the empty
  /// string for channels with none) once it is in.
  ///
  /// The screen decided about the name before this runs: a name that
  /// belongs to another playlist than [replaceId] is not taken over here,
  /// it answers `cancelled` with [IptvImportFailure.nameTaken].
  Future<IptvImportResult> commitPlaylistPreview(
    IptvPlaylistPreview preview, {
    required String name,
    String? replaceId,
    Set<String> hiddenGroups = const {},
  }) => _serial(() async {
    final failure = preview.failure;
    if (failure != null) {
      return failure;
    }
    final cleanName = name.trim();
    final clash = library.playlistNamed(cleanName);
    if (clash != null && clash.id != replaceId) {
      return IptvImportResult(
        IptvImportStatus.cancelled,
        id: clash.id,
        failure: IptvImportFailure.nameTaken,
        issues: preview.result.issues,
      );
    }
    if (replaceId != null && library.playlistById(replaceId) == null) {
      return IptvImportResult(IptvImportStatus.stale);
    }
    final written = await _write(preview.result, name: cleanName, replaceId: replaceId, url: preview.url);
    if (written.isImported) {
      for (final group in hiddenGroups) {
        try {
          await library.setGroupHidden(group, hidden: true);
        } on Object catch (error, stack) {
          // The playlist is in; a group left visible is the viewer's to hide
          // again, not a reason to call the import failed.
          _log
              ?.forCategory('playlist')
              .log(LogLevel.warning, 'group hide failed', fields: {'group': group}, error: error, stackTrace: stack);
        }
      }
    }
    _logVerdict('import', preview.url ?? cleanName, cleanName, written);
    return written;
  });

  // One-step playlist imports -------------------------------------------------

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
      text = (await _downloadPlaylist(url, headers)).text;
    } on Object catch (error, stack) {
      _logDownload('import', url, error, stack);
      return _downloadFailure(error);
    }
    final result = await _import(
      text: text,
      name: name,
      url: url.toString(),
      confirmReplace: confirmReplace,
      force: force,
    );
    _logVerdict('import', url.toString(), name, result);
    return result;
  });

  /// Re-downloads [playlist] from the address it was imported from.
  ///
  /// The channels are reconciled by address, so the user's favourites,
  /// hidden flags and ordering survive — and the record keeps its id, which
  /// is what keeps a room that points at a channel id working across a sync.
  /// The channels the source stopped listing leave with the sync (a
  /// favourite stays until it is unfavourited: see [IptvLibrary.importResult]).
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
      text = (await _downloadPlaylist(uri, const {})).text;
    } on Object catch (error, stack) {
      _logDownload('sync', uri, error, stack);
      return _downloadFailure(error);
    }
    final result = _read(text, url: url);
    final unreadable = _unreadable(result);
    if (unreadable != null) {
      // A cut-off download, an error page or an empty answer must not
      // replace a working playlist: the stored one is the only complete copy
      // the user has.
      _log
          ?.forCategory('playlist')
          .warning(
            'playlist sync kept the stored copy',
            fields: {'name': current.name, 'host': uri.host, 'failure': unreadable.failure?.name},
          );
      return IptvImportResult(
        IptvImportStatus.invalid,
        issues: unreadable.issues,
        failure: unreadable.failure,
        error: unreadable.error,
      );
    }
    final written = await _write(result, name: current.name, replaceId: current.id, url: url);
    _logVerdict('sync', current.url ?? current.name, current.name, written);
    return written;
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
  ///
  /// An address the library already has is that playlist: it is updated in
  /// place under the new name. A name that belongs to another playlist is a
  /// replacement, asked about.
  Future<IptvImportResult> _import({
    required String text,
    required String name,
    required String? url,
    required IptvReplaceConfirm? confirmReplace,
    required bool force,
  }) async {
    final result = _read(text, url: url);
    final unreadable = _unreadable(result);
    if (unreadable != null) {
      return unreadable;
    }
    final sameSource = url == null ? null : library.playlistWithUrl(url);
    final named = library.playlistNamed(name);
    if (named != null && sameSource != null && named.id != sameSource.id) {
      // Updating the stored copy of this address under a name another
      // playlist carries would leave two playlists one name.
      return IptvImportResult(
        IptvImportStatus.cancelled,
        id: named.id,
        failure: IptvImportFailure.nameTaken,
        issues: result.issues,
      );
    }
    if (named != null && sameSource == null && !force) {
      final confirm = confirmReplace;
      var confirmed = false;
      if (confirm != null) {
        confirmed = await Future.value(confirm(name));
      }
      if (!confirmed) {
        return IptvImportResult(IptvImportStatus.cancelled, id: named.id, issues: result.issues);
      }
    }
    return await _write(result, name: name, replaceId: (sameSource ?? named)?.id, url: url);
  }

  /// [text] read the way every import reads it: parsed, an Xtream panel's
  /// list cut to its live rows, and the repeats folded into lines.
  PlaylistParseResult _read(String text, {String? url}) {
    var result = parsePlaylistResult(text);
    final address = url == null ? null : Uri.tryParse(url);
    if (address != null && isXtreamPlaylistUrl(address)) {
      result = result.where((entry) => isXtreamLiveEntry(entry.url));
    }
    return result.mergeDuplicates();
  }

  /// Why [result] cannot be written, or null when it can.
  IptvImportResult? _unreadable(PlaylistParseResult result) {
    final markup = result.markup;
    if (markup != null) {
      return IptvImportResult(
        IptvImportStatus.unsupportedFormat,
        failure: markup == PlaylistMarkup.guide ? IptvImportFailure.guideFile : IptvImportFailure.webPage,
        issues: result.issues,
        error: 'the text is markup, not a playlist',
      );
    }
    if (result.truncated) {
      return IptvImportResult(
        IptvImportStatus.invalid,
        failure: IptvImportFailure.truncated,
        issues: result.issues,
        error: 'the file ends mid-stanza',
      );
    }
    if (result.entries.isEmpty) {
      return IptvImportResult(
        IptvImportStatus.unsupportedFormat,
        failure: IptvImportFailure.noChannels,
        issues: result.issues,
        error: 'no channels were read',
      );
    }
    return null;
  }

  /// The playlist at [url] as text, read from bytes when the application
  /// wired a byte fetcher for playlists.
  Future<({String text, IptvTextEncoding? encoding})> _downloadPlaylist(Uri url, Map<String, String> headers) async {
    final bytes = fetchPlaylistBytes;
    if (bytes != null) {
      final decoded = decodeIptvText(await bytes(url, headers: headers));
      return (text: decoded.text, encoding: decoded.encoding);
    }
    return (text: await fetch(url, headers: headers), encoding: null);
  }

  /// A failed download, worded by what failed.
  IptvImportResult _downloadFailure(Object error) => switch (error) {
    HttpStatusFailure(:final statusCode) => IptvImportResult(
      IptvImportStatus.networkFailed,
      failure: IptvImportFailure.httpStatus,
      statusCode: statusCode,
      error: error,
    ),
    TimeoutFailure() || TimeoutException() => IptvImportResult(
      IptvImportStatus.networkFailed,
      failure: IptvImportFailure.timeout,
      error: error,
    ),
    TlsFailure() => IptvImportResult(IptvImportStatus.networkFailed, failure: IptvImportFailure.tls, error: error),
    FormatException() => IptvImportResult(
      IptvImportStatus.invalid,
      failure: IptvImportFailure.unreadable,
      error: error,
    ),
    _ => IptvImportResult(IptvImportStatus.networkFailed, failure: IptvImportFailure.unreachable, error: error),
  };

  /// Writes a parsed playlist, mapping storage failures to a status.
  ///
  /// The source's own word is final: what it stopped listing leaves with
  /// this write, so a list that drops a dead channel drops it here too.
  Future<IptvImportResult> _write(
    PlaylistParseResult result, {
    required String name,
    required String? replaceId,
    required String? url,
  }) async {
    try {
      final written = await library.importResult(
        result,
        name: name,
        url: url,
        replaceId: replaceId,
        removeMissing: true,
      );
      return IptvImportResult(
        IptvImportStatus.imported,
        id: written.id,
        channels: written.channels,
        added: written.added,
        updated: written.updated,
        removed: written.removed,
        issues: result.issues,
      );
    } on Object catch (error, stack) {
      _log
          ?.forCategory('playlist')
          .error('playlist write failed', fields: {'name': name}, error: error, stackTrace: stack);
      return IptvImportResult(
        IptvImportStatus.failed,
        failure: IptvImportFailure.storage,
        issues: result.issues,
        error: error,
      );
    }
  }

  void _logDownload(String op, Uri url, Object error, StackTrace stack) => _log
      ?.forCategory('playlist')
      .log(
        LogLevel.warning,
        'playlist download failed',
        fields: {'op': op, 'host': url.host, 'error': '$error'},
        error: error,
        stackTrace: stack,
      );

  /// One line per verdict: the statuses the UI words, with the cause the
  /// toast cannot hold.
  void _logVerdict(String op, String source, String name, IptvImportResult result) {
    final log = _log;
    if (log == null) return;
    if (result.isImported) {
      log.info(
        'imported',
        fields: {
          'op': op,
          'source': source,
          'name': name,
          'channels': result.channels,
          'added': result.added,
          'removed': result.removed,
          'issues': result.issues.length,
        },
      );
      return;
    }
    if (result.status == IptvImportStatus.cancelled) return;
    log.warning(
      'failed',
      fields: {
        'op': op,
        'source': source,
        'name': name,
        'status': result.status.name,
        'failure': result.failure?.name,
        'error': '${result.error}',
      },
    );
  }

  // Guide previews ------------------------------------------------------------

  /// Reads guide [text] and judges it against the library, writing nothing.
  ///
  /// [source] is the address or file the text came from — what a sync will
  /// read again. The small path (pasted text); the byte paths parse off
  /// the caller's isolate in [previewGuideBytes].
  IptvGuidePreview previewGuideText(String text, {required String source, IptvTextEncoding? encoding}) {
    final ParsedGuide parsed;
    try {
      parsed = parseGuide(text);
    } on FormatException catch (error) {
      return IptvGuidePreview.failed(
        IptvImportResult(
          IptvImportStatus.invalid,
          failure: detectMarkup(text) == PlaylistMarkup.html ? IptvImportFailure.webPage : IptvImportFailure.unreadable,
          error: error,
        ),
        source: source,
      );
    }
    return _previewParsedGuide(parsed, source: source, encoding: encoding);
  }

  /// The verdicts that follow the parse: emptiness, and how much of the
  /// library the guide would answer.
  IptvGuidePreview _previewParsedGuide(ParsedGuide parsed, {required String source, IptvTextEncoding? encoding}) {
    if (parsed.isEmpty) {
      return IptvGuidePreview.failed(
        IptvImportResult(
          IptvImportStatus.unsupportedFormat,
          failure: IptvImportFailure.noChannels,
          error: 'no channels and no programmes were read',
        ),
        source: source,
      );
    }
    final index = GuideIndex([
      for (final channel in parsed.channels)
        EpgChannel.of(
          sourceId: 'preview',
          channelId: channel.id,
          displayName: channel.displayNames.isEmpty ? '' : channel.displayNames.first,
          iconUrl: channel.iconUrl,
        ),
    ]);
    final matchable = library.channels.where((channel) => index.match(channel) != null).length;
    return IptvGuidePreview(source: source, guide: parsed, encoding: encoding, matchable: matchable);
  }

  /// Decodes a picked guide file's [bytes] and previews them.
  ///
  /// Decoding and parsing run off the caller's isolate: a guide is tens of
  /// megabytes of text, and parsing one on the way in would freeze whatever
  /// page is showing while it reads.
  Future<IptvGuidePreview> previewGuideBytes(List<int> bytes, {required String source}) async {
    final IptvDecodedText decoded;
    try {
      decoded = await _decodeIptvTextIsolated(bytes);
    } on FormatException catch (error) {
      return IptvGuidePreview.failed(
        IptvImportResult(IptvImportStatus.invalid, failure: IptvImportFailure.unreadable, error: error),
        source: source,
      );
    }
    final ParsedGuide parsed;
    try {
      parsed = await _parseGuideIsolated(decoded.text);
    } on FormatException catch (error) {
      return IptvGuidePreview.failed(
        IptvImportResult(
          IptvImportStatus.invalid,
          failure: detectMarkup(decoded.text) == PlaylistMarkup.html
              ? IptvImportFailure.webPage
              : IptvImportFailure.unreadable,
          error: error,
        ),
        source: source,
      );
    }
    return _previewParsedGuide(parsed, source: source, encoding: decoded.encoding);
  }

  /// Downloads guide [url] and previews it.
  Future<IptvGuidePreview> previewGuideFromUrl(Uri url, {Map<String, String> headers = const {}}) async {
    final List<int> bytes;
    try {
      bytes = await _downloadGuideBytes(url, headers);
    } on _NoBytesFetcher catch (error) {
      return IptvGuidePreview.failed(IptvImportResult(IptvImportStatus.networkFailed, error: error), source: '$url');
    } on Object catch (error, stack) {
      _log
          ?.forCategory('guide')
          .log(
            LogLevel.warning,
            'guide download failed',
            fields: {'op': 'preview', 'host': url.host, 'error': '$error'},
            error: error,
            stackTrace: stack,
          );
      return IptvGuidePreview.failed(_downloadFailure(error), source: '$url');
    }
    return await previewGuideBytes(bytes, source: '$url');
  }

  /// Writes [preview] under [name]; [replace] takes over the stored guides of
  /// that name, which otherwise answer `cancelled` with
  /// [IptvImportFailure.nameTaken].
  Future<IptvImportResult> commitGuidePreview(IptvGuidePreview preview, {required String name, bool replace = false}) =>
      _serial(() async {
        final failure = preview.failure;
        final guide = preview.guide;
        if (failure != null) {
          return failure;
        }
        if (guide == null) {
          return IptvImportResult(IptvImportStatus.unsupportedFormat, failure: IptvImportFailure.noChannels);
        }
        final result = await _storeGuide(
          guide,
          name: name,
          source: preview.source,
          force: replace,
          expected: null,
          confirmReplace: null,
        );
        if (result.status == IptvImportStatus.cancelled) {
          return IptvImportResult(IptvImportStatus.cancelled, id: result.id, failure: IptvImportFailure.nameTaken);
        }
        _logVerdict('import', preview.source, name, result);
        return result;
      });

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
    } on Object catch (error, stack) {
      _log
          ?.forCategory('guide')
          .log(
            LogLevel.warning,
            'guide download failed',
            fields: {'op': 'import', 'host': url.host, 'error': '$error'},
            error: error,
            stackTrace: stack,
          );
      return _downloadFailure(error);
    }
    final String text;
    try {
      text = await _decodeGuideBytesIsolated(bytes);
    } on FormatException catch (error, stack) {
      _log
          ?.forCategory('guide')
          .log(
            LogLevel.warning,
            'guide decode failed',
            fields: {'op': 'import', 'host': url.host, 'error': '$error'},
            error: error,
            stackTrace: stack,
          );
      return IptvImportResult(IptvImportStatus.invalid, failure: IptvImportFailure.unreadable, error: error);
    }
    final result = await _importGuide(
      text: text,
      name: name,
      source: url.toString(),
      force: force,
      expected: null,
      confirmReplace: confirmReplace,
    );
    _logVerdict('import', url.toString(), name, result);
    return result;
  });

  /// Re-reads the stored guide [source] from the address it was imported
  /// from, keeping its id.
  ///
  /// A source whose guide is a local file cannot be synced here: the path is
  /// the application's filesystem, which this package does not touch.
  ///
  /// [now] is when the sync happened — [syncExpiredGuides] passes the round's
  /// instant so every write of one round carries its own time.
  Future<IptvImportResult> syncGuide(EpgSource source, {DateTime? now}) => _serial(() async {
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
      return _downloadFailure(error);
    }
    final String text;
    try {
      text = await _decodeGuideBytesIsolated(bytes);
    } on FormatException catch (error) {
      return IptvImportResult(IptvImportStatus.invalid, failure: IptvImportFailure.unreadable, error: error);
    }
    return await _importGuide(
      text: text,
      name: current.name,
      source: current.source,
      force: true,
      expected: current,
      confirmReplace: null,
      now: now,
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
      results.add(await syncGuide(source, now: moment));
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
  ///
  /// [now] is when the import happened; it stamps the source's refresh dates
  /// and fixes the programme-retention cutoff. It defaults to the wall clock,
  /// and [syncGuide] passes the sync round's own instant through — a test (or
  /// a replay) that runs an old round must not prune what that round's guide
  /// covers just because the real clock has moved on.
  Future<IptvImportResult> _importGuide({
    required String text,
    required String name,
    required String source,
    required bool force,
    required EpgSource? expected,
    required IptvReplaceConfirm? confirmReplace,
    DateTime? now,
  }) async {
    final ParsedGuide parsed;
    try {
      parsed = await _parseGuideIsolated(text);
    } on FormatException catch (error) {
      _log?.forCategory('guide').log(LogLevel.warning, 'guide parse failed', fields: {'name': name}, error: error);
      return IptvImportResult(IptvImportStatus.invalid, failure: IptvImportFailure.unreadable, error: error);
    }
    if (parsed.isEmpty) {
      _log?.forCategory('guide').warning('the guide answered nothing readable', fields: {'name': name});
      return IptvImportResult(
        IptvImportStatus.unsupportedFormat,
        failure: IptvImportFailure.noChannels,
        error: 'no channels and no programmes were read',
      );
    }
    return await _storeGuide(
      parsed,
      name: name,
      source: source,
      force: force,
      expected: expected,
      confirmReplace: confirmReplace,
      now: now,
    );
  }

  /// Decides about the name of [parsed] and writes it.
  Future<IptvImportResult> _storeGuide(
    ParsedGuide parsed, {
    required String name,
    required String source,
    required bool force,
    required EpgSource? expected,
    required IptvReplaceConfirm? confirmReplace,
    DateTime? now,
  }) async {
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
    final moment = now ?? DateTime.now();
    final existing = matched.isEmpty ? null : matched.first;
    final id = existing?.id ?? 'epg-${moment.microsecondsSinceEpoch}-${parsed.channels.length}';
    final saved =
        existing?.rebuild(
          (b) => b
            ..name = cleanName
            ..source = source
            ..lastRefresh = moment,
        ) ??
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
      _log
          ?.forCategory('guide')
          .info(
            'guide stored',
            fields: {'name': cleanName, 'channels': parsed.channels.length, 'programmes': parsed.programmes.length},
          );
      return IptvImportResult(IptvImportStatus.imported, id: id, channels: parsed.channels.length);
    } on Object catch (error, stack) {
      _log
          ?.forCategory('guide')
          .error('guide write failed', fields: {'name': cleanName}, error: error, stackTrace: stack);
      return IptvImportResult(IptvImportStatus.failed, failure: IptvImportFailure.storage, error: error);
    }
  }
}

/// The application wired no byte fetcher, so a remote guide cannot be read.
class _NoBytesFetcher implements Exception {
  new();

  @override
  String toString() => 'no byte fetcher: remote guides cannot be downloaded';
}
