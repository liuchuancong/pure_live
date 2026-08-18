import 'package:better_player_plus/src/hls/hls_parser/drm_init_data.dart';
import 'package:better_player_plus/src/hls/hls_parser/playlist.dart';
import 'package:better_player_plus/src/hls/hls_parser/segment.dart';

class HlsMediaPlaylist extends HlsPlaylist {
  HlsMediaPlaylist._({
    required this.playlistType,
    required this.startOffsetUs,
    required this.startTimeUs,
    required this.hasDiscontinuitySequence,
    required this.discontinuitySequence,
    required this.mediaSequence,
    required this.version,
    required this.targetDurationUs,
    required this.hasEndTag,
    required this.hasProgramDateTime,
    required this.protectionSchemes,
    required this.segments,
    required this.durationUs,
    required String super.baseUri,
    required super.tags,
    required super.hasIndependentSegments,
  });

  factory HlsMediaPlaylist.create({
    required int playlistType,
    required int? startOffsetUs,
    required int? startTimeUs,
    required bool hasDiscontinuitySequence,
    required int discontinuitySequence,
    required int? mediaSequence,
    required int? version,
    required int? targetDurationUs,
    required bool hasEndTag,
    required bool hasProgramDateTime,
    required DrmInitData? protectionSchemes,
    required List<Segment> segments,
    required String baseUri,
    required List<String> tags,
    required bool hasIndependentSegments,
  }) {
    final int? durationUs = segments.isNotEmpty
        ? segments.last.relativeStartTimeUs ?? 0 + segments.last.durationUs!
        : null;

    final int? resolvedStartOffsetUs = (startOffsetUs != null && startOffsetUs < 0)
        ? durationUs ?? 0 + startOffsetUs
        : startOffsetUs;

    return HlsMediaPlaylist._(
      playlistType: playlistType,
      startOffsetUs: resolvedStartOffsetUs,
      startTimeUs: startTimeUs,
      hasDiscontinuitySequence: hasDiscontinuitySequence,
      discontinuitySequence: discontinuitySequence,
      mediaSequence: mediaSequence,
      version: version,
      targetDurationUs: targetDurationUs,
      hasEndTag: hasEndTag,
      hasProgramDateTime: hasProgramDateTime,
      protectionSchemes: protectionSchemes,
      segments: segments,
      durationUs: durationUs,
      baseUri: baseUri,
      tags: tags,
      hasIndependentSegments: hasIndependentSegments,
    );
  }

  static const int playlistTypeUnknown = 0;
  static const int playlistTypeVod = 1;
  static const int playlistTypeEvent = 2;

  /// The type of the playlist. The value is [playlistTypeUnknown] or [playlistTypeVod] or [playlistTypeEvent] and not null.
  final int playlistType;

  /// The start offset in microseconds, as defined by #EXT-X-START, may be null if unknown.
  final int? startOffsetUs;

  /// If [hasProgramDateTime] is true, contains the datetime as microseconds since epoch.
  /// Otherwise, contains the aggregated duration of removed segments up to this snapshot of the playlist.
  final int? startTimeUs;

  /// Whether the playlist contains the #EXT-X-DISCONTINUITY-SEQUENCE tag.
  final bool hasDiscontinuitySequence;

  /// The discontinuity sequence number of the first media segment in the playlist, as defined by #EXT-X-DISCONTINUITY-SEQUENCE, may be null if unknown.
  final int discontinuitySequence;

  /// The media sequence number of the first media segment in the playlist, as defined by #EXT-X-MEDIA-SEQUENCE, may be null if unknown.
  final int? mediaSequence;

  /// The compatibility version, as defined by #EXT-X-VERSION, may be null if unknown.
  final int? version;

  /// The target duration in microseconds, as defined by #EXT-X-TARGETDURATION, may be null if unknown.
  final int? targetDurationUs;

  /// Whether the playlist contains the #EXT-X-ENDLIST tag.
  final bool hasEndTag;

  /// Whether the playlist contains a #EXT-X-PROGRAM-DATE-TIME tag.
  final bool hasProgramDateTime;

  /// Contains the CDM protection schemes used by segments in this playlist. Does not contain any key acquisition data. Null if none of the segments in the playlist is CDM-encrypted.
  final DrmInitData? protectionSchemes;

  /// The list of segments in the playlist.
  final List<Segment> segments;

  /// The total duration of the playlist in microseconds, may be null if unknown.
  final int? durationUs;
}
