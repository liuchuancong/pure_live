// Module: lib/src/models/media/media_ticket.dart
// Purpose: The playback credential the platform hands to the player: a resolved, usable media resource plus its policy.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-models.md section 11. MediaTicket is the platform <-> media core boundary
// (docs/media/media-ticket.md). It must not carry playback state: position, buffer, volume, speed,
// playing/paused, engine or instance belong to Media Core (invariant 10, section 11's MUST NOT list).
//
// MediaTrack note: docs/contracts/platform-models.md section 2 asks for media_core's MediaTrack to be
// reused rather than redefined, but media_core depends on the Flutter SDK while this package is
// mandated pure Dart (docs/architecture/dependency-rules.md section 2). This is therefore a field for
// field mirror that pure_live_media maps to media_core's type at the wiring layer.
// See docs/adr/0016-platform-media-track-mirror.md.

import '../../support/json.dart';
import '../content/content_ref.dart';

/// What the resource semantically is. Kept separate from [MediaProtocol], which is how it is transported
/// (docs/contracts/platform-models.md section 11 forbids merging the two).
enum MediaKind { live, vod, music, file }

/// Which essence a track carries. Mirrors media_core's `MediaTrackType` one for one
/// (packages/media_core/lib/source/media_track_type.dart); it is not [MediaKind], which classifies the
/// resource as a whole rather than one stream inside it.
enum MediaTrackType { video, audio, subtitle }

/// How the resource is transported.
enum MediaProtocol { http, https, hls, dash, rtmp, rtsp, websocket, file, unknown }

/// One stream inside a ticket: video essence, audio essence or subtitle.
final class MediaTrack {
  const MediaTrack({
    required this.uri,
    required this.kind,
    this.headers = const <String, String>{},
    this.mimeType,
    this.codec,
    this.bitrate,
    this.language,
    this.startOffset,
    this.metadata = const <String, Object?>{},
  });

  factory MediaTrack.fromJson(Map<String, Object?> json) {
    return MediaTrack(
      uri: Uri.parse(requireString(json, 'uri', 'media_ticket')),
      kind: enumByName(MediaTrackType.values, json['kind'] as String?) ?? MediaTrackType.video,
      headers: _stringMap(json['headers']),
      mimeType: json['mimeType'] as String?,
      codec: json['codec'] as String?,
      bitrate: (json['bitrate'] as num?)?.toInt(),
      language: json['language'] as String?,
      startOffset: parseDurationMs(json['startOffsetMs']),
      metadata: asObjectMap(json['metadata']),
    );
  }

  final Uri uri;

  /// Which essence this track carries, not what the resource as a whole is.
  final MediaTrackType kind;

  /// Per-stream request headers; DASH and HLS essences routinely need their own.
  final Map<String, String> headers;
  final String? mimeType;
  final String? codec;
  final int? bitrate;
  final String? language;
  final Duration? startOffset;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'uri': uri.toString(),
      'kind': kind.name,
      if (headers.isNotEmpty) 'headers': headers,
      if (mimeType != null) 'mimeType': mimeType,
      if (codec != null) 'codec': codec,
      if (bitrate != null) 'bitrate': bitrate,
      if (language != null) 'language': language,
      if (startOffset != null) 'startOffsetMs': durationMs(startOffset),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}

/// What a source says about keeping one ticket alive.
///
/// docs/contracts/platform-models.md section 11 defines it alongside [MediaTicketPolicy], and the two are
/// deliberately separate: the policy is what the *platform* is permitted to do, this is what the *source* is
/// able to do. A source may permit nothing while the policy allows everything, and the intersection is what
/// a scheduler may act on.
final class MediaTicketRefreshInfo {
  const MediaTicketRefreshInfo({this.supported = true, this.expiresAt, this.refreshBefore});

  factory MediaTicketRefreshInfo.fromJson(Map<String, Object?> json) => MediaTicketRefreshInfo(
    supported: json['supported'] as bool? ?? true,
    expiresAt: parseUtc(json['expiresAt']),
    refreshBefore: parseDurationMs(json['refreshBeforeMs']),
  );

  /// Whether this resource can be re-fetched at all. A one-shot signed url sets this false, and asking for a
  /// replacement early would then produce a second url that nothing uses.
  final bool supported;

  /// The source's own expiry statement, which can differ from the ticket's when a protocol reports it in a
  /// second place; the ticket field stays authoritative for the deadline.
  final DateTime? expiresAt;

  /// How long before expiry a replacement should be requested (docs/media/media-contract.md section 2's
  /// `refreshBefore`, the "T-45s" in docs/media/media-ticket.md section 3).
  final Duration? refreshBefore;

  /// When a replacement should be asked for, or null when there is nothing to schedule.
  ///
  /// Null comes from two different reasons and the caller should not have to re-derive them: [supported]
  /// false means a replacement does not exist (a one-shot signed url), and no deadline means the protocol
  /// never said when this one dies. [defaultLead] is the platform's fallback for a source that gives advice
  /// about expiry but not about timing, which is most of them.
  DateTime? nextRefreshAt({required DateTime? ticketExpiry, required Duration defaultLead}) {
    if (!supported) {
      return null;
    }
    final deadline = ticketExpiry ?? expiresAt;
    if (deadline == null) {
      return null;
    }
    final lead = refreshBefore ?? defaultLead;
    // A source that advises a negative or zero lead means "replace it as soon as you can", which is the
    // deadline itself rather than a moment before it; refusing to schedule would be the worse reading.
    if (lead.isNegative || lead == Duration.zero) {
      return deadline;
    }
    return deadline.subtract(lead);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    if (!supported) 'supported': false,
    if (expiresAt != null) 'expiresAt': formatUtc(expiresAt),
    if (refreshBefore != null) 'refreshBeforeMs': durationMs(refreshBefore),
  };

  @override
  String toString() => 'MediaTicketRefreshInfo(supported: $supported, lead: ${refreshBefore?.inSeconds}s)';
}

/// Descriptive fields for a UI or a media session. No playback state.
final class MediaPlaybackMetadata {
  const MediaPlaybackMetadata({
    this.title,
    this.artist,
    this.album,
    this.cover,
    this.duration,
    this.isLive = false,
    this.extra = const <String, Object?>{},
  });

  factory MediaPlaybackMetadata.fromJson(Map<String, Object?> json) {
    return MediaPlaybackMetadata(
      title: json['title'] as String?,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      cover: json['cover'] as String?,
      duration: parseDurationMs(json['durationMs']),
      isLive: json['isLive'] as bool? ?? false,
      extra: asObjectMap(json['extra']),
    );
  }

  final String? title;
  final String? artist;
  final String? album;
  final String? cover;
  final Duration? duration;
  final bool isLive;
  final Map<String, Object?> extra;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (cover != null) 'cover': cover,
      if (duration != null) 'durationMs': durationMs(duration),
      if (isLive) 'isLive': true,
      if (extra.isNotEmpty) 'extra': extra,
    };
  }
}

/// What the platform is allowed to do with a ticket. Defaults follow section 11.
final class MediaTicketPolicy {
  const MediaTicketPolicy({
    this.allowRedirect = true,
    this.allowRefresh = true,
    this.allowRetry = true,
    this.allowLineFallback = true,
    this.allowEngineFallback = false,
    this.seamlessRefresh = false,
    this.retryDelay = const Duration(seconds: 2),
  });

  factory MediaTicketPolicy.fromJson(Map<String, Object?> json) {
    return MediaTicketPolicy(
      allowRedirect: json['allowRedirect'] as bool? ?? true,
      allowRefresh: json['allowRefresh'] as bool? ?? true,
      allowRetry: json['allowRetry'] as bool? ?? true,
      allowLineFallback: json['allowLineFallback'] as bool? ?? true,
      allowEngineFallback: json['allowEngineFallback'] as bool? ?? false,
      seamlessRefresh: json['seamlessRefresh'] as bool? ?? false,
      retryDelay: parseDurationMs(json['retryDelayMs']) ?? const Duration(seconds: 2),
    );
  }

  final bool allowRedirect;

  /// Whether the platform may re-resolve the same content to obtain a fresh resource.
  final bool allowRefresh;
  final bool allowRetry;

  /// Whether another line of the same source may be used.
  final bool allowLineFallback;

  /// Whether a different player engine may be tried. Sources that only work in one engine set this false.
  final bool allowEngineFallback;

  /// Refresh without interrupting playback.
  final bool seamlessRefresh;
  final Duration retryDelay;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'allowRedirect': allowRedirect,
      'allowRefresh': allowRefresh,
      'allowRetry': allowRetry,
      'allowLineFallback': allowLineFallback,
      'allowEngineFallback': allowEngineFallback,
      'seamlessRefresh': seamlessRefresh,
      'retryDelayMs': durationMs(retryDelay),
    };
  }
}

/// A resolved, playable resource.
final class MediaTicket {
  const MediaTicket({
    required this.id,
    required this.uri,
    required this.kind,
    required this.protocol,
    required this.createdAt,
    this.headers = const <String, String>{},
    this.tracks = const <MediaTrack>[],
    this.expiresAt,
    this.policy = const MediaTicketPolicy(),
    this.metadata = const MediaPlaybackMetadata(),
    this.source,
    this.refresh,
  });

  factory MediaTicket.fromJson(Map<String, Object?> json) {
    return MediaTicket(
      id: requireString(json, 'id', 'media_ticket'),
      uri: Uri.parse(requireString(json, 'uri', 'media_ticket')),
      kind: enumByName(MediaKind.values, json['kind'] as String?) ?? MediaKind.vod,
      protocol: enumByName(MediaProtocol.values, json['protocol'] as String?) ?? MediaProtocol.unknown,
      createdAt: parseUtc(json['createdAt']) ?? DateTime.utc(1970),
      headers: _stringMap(json['headers']),
      tracks: _tracksFromJson(json['tracks']),
      expiresAt: parseUtc(json['expiresAt']),
      policy: MediaTicketPolicy.fromJson(asObjectMap(json['policy'])),
      metadata: MediaPlaybackMetadata.fromJson(asObjectMap(json['metadata'])),
      source: json['source'] == null ? null : ContentRef.fromJson(asObjectMap(json['source'])),
      refresh: json['refresh'] == null ? null : MediaTicketRefreshInfo.fromJson(asObjectMap(json['refresh'])),
    );
  }

  /// Stable ticket identity; equality is by this id alone (section 16).
  final String id;
  final Uri uri;

  /// What the resource semantically is.
  final MediaKind kind;
  final MediaProtocol protocol;

  /// Request headers needed to fetch the resource. Sensitive values must be redacted before logging or
  /// persistence (section 16).
  final Map<String, String> headers;

  /// Additional essences; a single-url source leaves this empty and uses [uri].
  final List<MediaTrack> tracks;
  final DateTime createdAt;

  /// When the resource stops being fetchable. Null means the protocol never said.
  final DateTime? expiresAt;
  final MediaTicketPolicy policy;
  final MediaPlaybackMetadata metadata;

  /// The content this ticket was resolved for, kept so a refresh can be attributed without a lookup.
  final ContentRef? source;

  /// What the source itself said about refreshing this ticket. Null means it never answered, which the
  /// scheduler treats as "no advice", not as "impossible".
  final MediaTicketRefreshInfo? refresh;

  /// Whether the ticket can still be handed to a player right now.
  bool isExpiredAt(DateTime now) {
    final expiry = expiresAt;
    return expiry != null && !now.toUtc().isBefore(expiry);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'uri': uri.toString(),
      'kind': kind.name,
      'protocol': protocol.name,
      'createdAt': formatUtc(createdAt),
      if (headers.isNotEmpty) 'headers': headers,
      if (tracks.isNotEmpty) 'tracks': _tracksToJson(tracks),
      if (expiresAt != null) 'expiresAt': formatUtc(expiresAt),
      if (refresh != null) 'refresh': refresh!.toJson(),
      'policy': policy.toJson(),
      'metadata': metadata.toJson(),
      if (source != null) 'source': source!.toJson(),
    };
  }

  @override
  bool operator ==(Object other) => other is MediaTicket && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Reads a persisted track list. An entry this reader cannot interpret is skipped rather than failing
/// the whole ticket: an unknown track is missing data, not a corrupt ticket.
List<MediaTrack> _tracksFromJson(Object? value) =>
    asObjectMapList(value).map(MediaTrack.fromJson).toList(growable: false);

List<Map<String, Object?>> _tracksToJson(List<MediaTrack> tracks) =>
    tracks.map((track) => track.toJson()).toList(growable: false);

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) {
    return const <String, String>{};
  }
  return Map<String, String>.fromEntries(value.entries.map((entry) => MapEntry('${entry.key}', '${entry.value}')));
}
