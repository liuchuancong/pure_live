import 'package:better_player_plus/src/hls/hls_parser/drm_init_data.dart';

class Segment {
  Segment({
    required this.url,
    this.initializationSegment,
    this.durationUs,
    this.title,
    this.relativeDiscontinuitySequence,
    this.relativeStartTimeUs,
    this.drmInitData,
    required this.fullSegmentEncryptionKeyUri,
    required this.encryptionIV,
    required this.byterangeOffset,
    required this.byterangeLength,
    this.hasGapTag = false,
  });

  final String? url;

  /// The media initialization section for this segment, as defined by #EXT-X-MAP. May be null if the media playlist does not define a media section for this segment.
  /// The same instance is used for all segments that share an EXT-X-MAP tag.
  final Segment? initializationSegment;

  /// The duration of the segment in microseconds, as defined by #EXTINF.
  final int? durationUs;

  /// The human readable title of the segment, or null if the title is unknown.
  final String? title;

  /// The number of #EXT-X-DISCONTINUITY tags in the playlist before the segment, or null if the it's unknown.
  final int? relativeDiscontinuitySequence;

  /// The start time of the segment in microseconds, relative to the start of the playlist, or null if the it's unknown.
  final int? relativeStartTimeUs;

  /// DRM initialization data for sample decryption, or null if the segment does not use CDM-DRM protection.
  final DrmInitData? drmInitData;

  /// The encryption identity key uri as defined by #EXT-X-KEY, or null if the segment does not use full segment encryption with identity key.
  final String? fullSegmentEncryptionKeyUri;

  /// The encryption initialization vector as defined by #EXT-X-KEY, or null if the segment is not encrypted.
  final String? encryptionIV;

  /// The segment's byte range offset, as defined by #EXT-X-BYTERANGE.
  final int? byterangeOffset;

  /// The segment's byte range length, as defined by #EXT-X-BYTERANGE, or null if no byte range is specified.
  final int? byterangeLength;

  /// Whether the segment is tagged with #EXT-X-GAP.
  final bool hasGapTag;
}
