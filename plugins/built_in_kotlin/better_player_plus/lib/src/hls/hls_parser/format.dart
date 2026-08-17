import 'package:better_player_plus/src/hls/hls_parser/drm_init_data.dart';
import 'package:better_player_plus/src/hls/hls_parser/metadata.dart';
import 'package:better_player_plus/src/hls/hls_parser/util.dart';

/// Representation of a media format.
class Format {
  Format({
    this.id,
    this.label,
    this.selectionFlags,
    this.roleFlags,
    this.bitrate,
    this.averageBitrate,
    this.codecs,
    this.metadata,
    this.containerMimeType,
    this.sampleMimeType,
    this.drmInitData,
    this.subsampleOffsetUs,
    this.width,
    this.height,
    this.frameRate,
    this.channelCount,
    String? language,
    this.accessibilityChannel,
    this.isDefault,
  }) : language = language?.toLowerCase();

  factory Format.createVideoContainerFormat({
    String? id,
    String? label,
    String? containerMimeType,
    String? sampleMimeType,
    required String? codecs,
    int? bitrate,
    int? averageBitrate,
    required int? width,
    required int? height,
    required double? frameRate,
    int selectionFlags = Util.selectionFlagDefault,
    int? roleFlags,
    bool? isDefault,
  }) => Format(
    id: id,
    label: label,
    selectionFlags: selectionFlags,
    bitrate: bitrate,
    averageBitrate: averageBitrate,
    codecs: codecs,
    containerMimeType: containerMimeType,
    sampleMimeType: sampleMimeType,
    width: width,
    height: height,
    frameRate: frameRate,
    roleFlags: roleFlags,
    isDefault: isDefault,
  );

  /// An identifier for the format, or null if unknown or not applicable.
  final String? id;

  /// The human readable label, or null if unknown or not applicable.
  final String? label;

  /// Track selection flags.
  /// [Util.selectionFlagDefault] or [Util.selectionFlagForced] or [Util.selectionFlagAutoSelect]
  final int? selectionFlags;

  /// Track role flags.
  /// [Util.roleFlagDescribesMusicAndSound] or [Util.roleFlagDescribesVideo] or [Util.roleFlagEasyToRead] or [Util.roleFlagTranscribesDialog]
  final int? roleFlags;

  ///Average bandwidth
  final int? bitrate;

  /// The average bandwidth in bits per second, or null if unknown or not applicable.
  final int? averageBitrate;

  /// Codecs of the format as described in RFC 6381, or null if unknown or not applicable.
  final String? codecs;

  /// Metadata, or null if unknown or not applicable.
  final Metadata? metadata;

  /// The mime type of the container, or null if unknown or not applicable.
  final String? containerMimeType;

  ///The mime type of the elementary stream (i.e. the individual samples), or null if unknown or not applicable.
  final String? sampleMimeType;

  ///DRM initialization data if the stream is protected, or null otherwise.
  final DrmInitData? drmInitData;

  /// For samples that contain subsamples, this is an offset that should be added to subsample timestamps.
  /// A value of {@link #OFFSET_SAMPLE_RELATIVE} indicates that subsample timestamps are relative to the timestamps of their parent samples.
  final int? subsampleOffsetUs;

  /// The width of the video in pixels, or null if unknown or not applicable.
  final int? width;

  /// The height of the video in pixels, or null if unknown or not applicable.
  final int? height;

  /// The frame rate in frames per second, or null if unknown or not applicable.
  final double? frameRate;

  /// The number of audio channels, or null if unknown or not applicable.
  final int? channelCount;

  /// The language of the video, or null if unknown or not applicable.
  final String? language;

  /// The Accessibility channel, or null if not known or applicable.
  final int? accessibilityChannel;

  /// If track is marked as default, or null if not known or applicable
  final bool? isDefault;

  Format copyWithMetadata(Metadata metadata) => Format(
    id: id,
    label: label,
    selectionFlags: selectionFlags,
    roleFlags: roleFlags,
    bitrate: bitrate,
    averageBitrate: averageBitrate,
    codecs: codecs,
    metadata: metadata,
    containerMimeType: containerMimeType,
    sampleMimeType: sampleMimeType,
    drmInitData: drmInitData,
    subsampleOffsetUs: subsampleOffsetUs,
    width: width,
    height: height,
    frameRate: frameRate,
    channelCount: channelCount,
    language: language,
    accessibilityChannel: accessibilityChannel,
  );
}
