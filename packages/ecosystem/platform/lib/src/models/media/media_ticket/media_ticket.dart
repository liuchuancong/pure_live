// Module: lib/src/models/media/media_ticket/media_ticket.dart
// Purpose: MediaTicket, split out of the file that bundled it (see package-architecture.md
// §2.1): one public type per file, and the file in a folder of its own so anything generated for
// it lands beside it.
// Author: liuchuancong
// Created: 2026-10-11

import '../../../support/json.dart';
import '../../content/content_ref/content_ref.dart';
import '../media_kind/media_kind.dart';
import '../media_playback_metadata/media_playback_metadata.dart';
import '../media_protocol/media_protocol.dart';
import '../media_ticket_policy/media_ticket_policy.dart';
import '../media_ticket_refresh_info/media_ticket_refresh_info.dart';
import '../media_track/media_track.dart';

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
      headers: stringMapField(json['headers']),
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
