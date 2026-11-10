import 'package:live_iptv/src/import/iptv_import_result.dart';
import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/playlist/playlist.dart';

/// A playlist read and judged but not yet written: what an import screen
/// shows before the viewer says "import".
///
/// The read is the one the write will use — parsed, its repeats folded into
/// lines — so what the preview counts is what lands in the library. A
/// preview that has nothing to import carries the [failure] instead, worded
/// the way a finished import would have been.
final class IptvPlaylistPreview {
  /// A preview of [result].
  new({required this.result, this.url, this.encoding, this.urlClash, this.failure});

  /// A preview that read nothing, for the reason [failure] gives.
  new failed(IptvImportResult this.failure, {this.url})
    : result = PlaylistParseResult(entries: const []),
      encoding = null,
      urlClash = null;

  /// The playlist as it will be written.
  final PlaylistParseResult result;

  /// The remote address it came from, when it came from one.
  final String? url;

  /// The encoding its bytes were read with, when the bytes were seen.
  final IptvTextEncoding? encoding;

  /// The stored playlist that already has this address: importing it again
  /// is an update of that one, not a second copy.
  final IptvPlaylist? urlClash;

  /// Why there is nothing to import, or null when there is.
  final IptvImportResult? failure;

  /// Whether there is something to import.
  bool get isReadable => failure == null;

  /// How many channels the import would write.
  int get channels => result.entries.length;

  /// The name the playlist gives itself (`#PLAYLIST:`), when it gives one.
  String? get suggestedName => result.header.title;
}

/// A guide read and judged but not yet written.
///
/// [matchable] is the number that tells the viewer whether this is the
/// guide they want: a guide of three thousand channels that gives none of
/// theirs a schedule is the wrong guide, however large it is.
final class IptvGuidePreview {
  /// A preview of [guide], read from [source].
  new({required this.source, this.guide, this.encoding, this.matchable = 0, this.failure});

  /// A preview that read nothing, for the reason [failure] gives.
  new failed(IptvImportResult this.failure, {required this.source}) : guide = null, encoding = null, matchable = 0;

  /// The address or file the guide came from — what a sync reads again.
  final String source;

  /// The guide, when it was read.
  final ParsedGuide? guide;

  /// The encoding its bytes were read with, when the bytes were seen.
  final IptvTextEncoding? encoding;

  /// How many of the library's channels the guide would give a schedule.
  final int matchable;

  /// Why there is nothing to import, or null when there is.
  final IptvImportResult? failure;

  /// Whether there is something to import.
  bool get isReadable => failure == null && guide != null;

  /// How many channels the guide lists.
  int get channels => guide?.channels.length ?? 0;

  /// How many programmes the guide lists.
  int get programmes => guide?.programmes.length ?? 0;

  /// When the earliest programme starts, or null for a guide without any.
  DateTime? get firstStart {
    DateTime? first;
    for (final programme in guide?.programmes ?? const <EpgProgramme>[]) {
      if (first == null || programme.start.isBefore(first)) {
        first = programme.start;
      }
    }
    return first;
  }

  /// When the latest programme stops, or null for a guide without any.
  DateTime? get lastStop {
    DateTime? last;
    for (final programme in guide?.programmes ?? const <EpgProgramme>[]) {
      if (last == null || programme.stop.isAfter(last)) {
        last = programme.stop;
      }
    }
    return last;
  }
}
