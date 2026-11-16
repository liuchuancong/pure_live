import 'dart:async' show Completer;
import 'dart:convert' show utf8;
import 'dart:io' show Directory, File, HttpClient, IOSink, Platform;

import 'package:media_core/media_core.dart' show PlayerSource;

/// Why a replay refused to download, in codes the page maps to copy.
enum ArchiveReplayDownloadFailure {
  /// The playlist asks for AES keys; segment decryption is not built.
  encrypted,

  /// The playlist is cut in a way a plain join cannot rebuild (fMP4 with an
  /// initialisation segment, byte ranges), or names no variant to read.
  playlist,

  /// A request failed or a stream broke mid-way (a cancel surfaces here too).
  network,
}

/// The failure the download stopped with.
final class ArchiveReplayDownloadException implements Exception {
  /// Creates the failure.
  ArchiveReplayDownloadException(this.code);

  /// Why the download stopped.
  final ArchiveReplayDownloadFailure code;

  @override
  String toString() => 'ArchiveReplayDownloadException($code)';
}

/// What an m3u8 document says, read out once so the download loop stays
/// plain: a master playlist points at one variant to re-read; a media
/// playlist lists the segments to fetch in order.
final class ArchiveReplayPlaylist {
  ArchiveReplayPlaylist._({
    required this.isMaster,
    required this.variant,
    required this.segments,
    required this.totalSeconds,
    required this.encrypted,
    required this.unsupported,
  });

  /// Reads [text] as an m3u8 document addressed at [base].
  ///
  /// A master playlist answers with its highest-bandwidth variant and
  /// nothing else; a media playlist answers with its segment list resolved
  /// against the document's own address, the summed `#EXTINF` seconds,
  /// whether it asks for decryption keys, and whether it is cut in a way a
  /// plain concatenation cannot rebuild (neither of which the download can
  /// honour).
  factory ArchiveReplayPlaylist.parse(String text, Uri base) {
    var encrypted = false;
    var unsupported = false;
    var totalSeconds = 0.0;
    final segments = <Uri>[];
    Uri? variant;
    var variantBandwidth = -1;
    var pendingBandwidth = -1;
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXT-X-KEY')) {
        // `METHOD=NONE` is the honest "plain"; anything else needs keys the
        // downloader does not keep.
        if (!line.contains('METHOD=NONE')) encrypted = true;
        continue;
      }
      // An fMP4 playlist names an initialisation segment the media segments
      // are meaningless without, and a byte-range playlist addresses slices
      // of one file: joining what the segment lines alone say would write a
      // file nothing can open.
      if (line.startsWith('#EXT-X-MAP') || line.startsWith('#EXT-X-BYTERANGE')) {
        unsupported = true;
        continue;
      }
      if (line.startsWith('#EXTINF')) {
        final value = double.tryParse(line.substring(8).split(',').first.trim());
        if (value != null) totalSeconds += value;
        continue;
      }
      if (line.startsWith('#EXT-X-STREAM-INF')) {
        final match = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
        pendingBandwidth = match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
        continue;
      }
      if (line.startsWith('#')) continue;
      final resolved = base.resolve(line);
      // The non-comment line after a `#EXT-X-STREAM-INF` is that variant's
      // address; the highest bandwidth seen wins.
      if (pendingBandwidth >= 0) {
        if (pendingBandwidth > variantBandwidth) {
          variantBandwidth = pendingBandwidth;
          variant = resolved;
        }
        pendingBandwidth = -1;
        continue;
      }
      segments.add(resolved);
    }
    final isMaster = variant != null;
    return ArchiveReplayPlaylist._(
      isMaster: isMaster,
      variant: variant,
      segments: segments,
      totalSeconds: totalSeconds,
      encrypted: encrypted,
      unsupported: unsupported,
    );
  }

  /// Whether the document was a master playlist.
  final bool isMaster;

  /// The master playlist's chosen variant (highest bandwidth); null on a
  /// media playlist.
  final Uri? variant;

  /// The media playlist's segments, resolved against the document address.
  final List<Uri> segments;

  /// The summed `#EXTINF` seconds; zero when none were said.
  final double totalSeconds;

  /// Whether the playlist asks for decryption keys.
  final bool encrypted;

  /// Whether the playlist is cut as fMP4 (an initialisation segment) or by
  /// byte ranges — shapes a segment-by-segment join cannot rebuild.
  final bool unsupported;
}

/// One replay download the archive page drives: the current rendition's
/// address (an m3u8 playlist or a plain stream) fetched to a finished-video
/// file, reporting progress as a 0–1 fraction (null while unknowable).
///
/// The task lives with the page that started it — leaving the page cancels
/// the download and strikes the partial file. One task at a time.
final class ArchiveReplayDownloader {
  /// Creates the downloader; [directory] is the finished-videos folder the
  /// file lands in.
  ArchiveReplayDownloader({required this.directory});

  /// The folder the finished file is written to.
  final Directory directory;

  HttpClient? _client;
  IOSink? _sink;
  Future<File>? _run;
  bool _cancelRequested = false;

  /// Whether a download is under way.
  bool get isRunning => _run != null;

  /// Runs the download to a file named after [title], reporting progress
  /// through [onProgress]; completes with the finished file. Throws
  /// [ArchiveReplayDownloadException] when the source refuses to be
  /// downloaded. A second call while one is running throws.
  Future<File> run({
    required PlayerSource source,
    required String title,
    required void Function(double? progress) onProgress,
  }) {
    if (_run != null) throw StateError('a replay download is already running');
    final run = _runTo(source: source, title: title, onProgress: onProgress);
    _run = run;
    return run.whenComplete(() => _run = null);
  }

  Future<File> _runTo({
    required PlayerSource source,
    required String title,
    required void Function(double? progress) onProgress,
  }) async {
    _cancelRequested = false;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    _client = client;
    File? partial;
    try {
      final headers = source.headers?.values ?? const <String, String>{};
      final base = source.uri;
      final file = File('${directory.path}${Platform.pathSeparator}${_fileName(title, base)}');
      partial = file;
      await directory.create(recursive: true);
      final sink = file.openWrite();
      _sink = sink;

      var address = base;
      // A master playlist is re-read once, at the variant the document
      // itself ranks highest; what comes back is the media playlist.
      ArchiveReplayPlaylist playlist;
      while (true) {
        final text = await _readText(client, address, headers);
        playlist = ArchiveReplayPlaylist.parse(text, address);
        if (playlist.encrypted) {
          throw ArchiveReplayDownloadException(ArchiveReplayDownloadFailure.encrypted);
        }
        if (playlist.unsupported) {
          throw ArchiveReplayDownloadException(ArchiveReplayDownloadFailure.playlist);
        }
        if (!playlist.isMaster) break;
        final variant = playlist.variant;
        if (variant == null) {
          throw ArchiveReplayDownloadException(ArchiveReplayDownloadFailure.playlist);
        }
        address = variant;
      }
      if (playlist.segments.isEmpty) {
        // Not a playlist at all: a plain stream (an mp4 or an flv) is one
        // progressive fetch the same sink takes.
        await _pipe(client, base, headers, sink, onProgress: onProgress);
      } else {
        final count = playlist.segments.length;
        for (var index = 0; index < count; index++) {
          _throwIfCancelled();
          await _pipe(
            client,
            playlist.segments[index],
            headers,
            sink,
            onProgress: (value) {
              // A segment whose length the server withheld reports null; the
              // walk stays honest rather than inventing a fraction.
              onProgress(value == null ? null : (index + value) / count);
            },
          );
        }
      }
      await sink.flush();
      await sink.close();
      _sink = null;
      _throwIfCancelled();
      return file;
    } on ArchiveReplayDownloadException {
      await _strike(partial);
      rethrow;
    } on Object {
      await _strike(partial);
      throw ArchiveReplayDownloadException(ArchiveReplayDownloadFailure.network);
    } finally {
      _client?.close(force: true);
      _client = null;
    }
  }

  /// Asks the running download to stop; the run throws and the partial file
  /// is struck.
  void cancel() {
    if (_run == null) return;
    _cancelRequested = true;
    _client?.close(force: true);
  }

  /// Stops any running download and waits for it to wind down (the page is
  /// going away).
  Future<void> dispose() async {
    cancel();
    final run = _run;
    if (run != null) {
      try {
        await run;
      } on Object {
        // The run's own failure has already been reported to its caller.
      }
    }
  }

  Future<String> _readText(HttpClient client, Uri address, Map<String, String> headers) async {
    final request = await client.getUrl(address);
    headers.forEach(request.headers.set);
    final response = await request.close();
    if (response.statusCode != 200) {
      throw ArchiveReplayDownloadException(ArchiveReplayDownloadFailure.network);
    }
    return await utf8.decoder.bind(response).join();
  }

  Future<void> _pipe(
    HttpClient client,
    Uri address,
    Map<String, String> headers,
    IOSink sink, {
    required void Function(double? progress) onProgress,
  }) async {
    final request = await client.getUrl(address);
    headers.forEach(request.headers.set);
    final response = await request.close();
    if (response.statusCode != 200) {
      throw ArchiveReplayDownloadException(ArchiveReplayDownloadFailure.network);
    }
    final total = response.contentLength;
    var received = 0;
    final piped = Completer<void>();
    final subscription = response.listen(
      (chunk) {
        _throwIfCancelled();
        received += chunk.length;
        sink.add(chunk);
        onProgress(total > 0 ? received / total : null);
      },
      onError: (Object error) {
        if (!piped.isCompleted) piped.completeError(error);
      },
      onDone: () {
        if (!piped.isCompleted) piped.complete();
      },
      cancelOnError: true,
    );
    try {
      await piped.future;
    } finally {
      await subscription.cancel();
    }
  }

  void _throwIfCancelled() {
    if (_cancelRequested) throw ArchiveReplayDownloadException(ArchiveReplayDownloadFailure.network);
  }

  Future<void> _strike(File? file) async {
    final sink = _sink;
    _sink = null;
    if (sink != null) {
      try {
        await sink.close();
      } on Object {
        // The sink's own failure does not outshine the download's.
      }
    }
    if (file == null) return;
    try {
      if (file.existsSync()) await file.delete();
    } on Object {
      // A struck partial that would not leave is a disk orphans; the next
      // download starts a new name.
    }
  }

  String _fileName(String title, Uri base) {
    final slug = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').replaceAll(RegExp(r'\s+'), '_').trim();
    final stem = slug.isEmpty ? 'replay' : (slug.length > 40 ? slug.substring(0, 40) : slug);
    final path = base.path.toLowerCase();
    final extension = path.endsWith('.mp4')
        ? '.mp4'
        : path.endsWith('.flv')
        ? '.flv'
        : '.ts';
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return 'archive-$stem-$stamp$extension';
  }
}
