// Module: lib/src/models/resolver/resolve_request.dart
// Purpose: The request and result types on the content boundary: what the caller wants played, and what the resolver produced.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-models.md section 10. ResolveRequest carries intent and preferences as
// input; it must not carry player state, and the resolver must not create players (invariant 3).
//
// The spec's `CancellationToken? cancellation` field is intentionally absent: media_core owns the cancel
// token, it is runtime-only and never serialized, and this package must stay Flutter free. The caller
// that owns the token passes it to the resolver call itself rather than through the serializable model.

import '../../support/json.dart';
import '../content/content_ref.dart';
import '../media/media_ticket.dart';

/// Why the caller is resolving. It is an input to resolution, not a player mode.
enum PlaybackIntent { normal, audioOnly, background, cast, external, preview }

/// The conditions a resolver should honour.
final class ResolveContext {
  const ResolveContext({
    this.intent = PlaybackIntent.normal,
    this.preferredQuality,
    this.preferredLanguage,
    this.region,
    this.networkMetered = false,
    this.metadata = const <String, Object?>{},
  });

  factory ResolveContext.fromJson(Map<String, Object?> json) {
    return ResolveContext(
      intent: enumByName(PlaybackIntent.values, json['intent'] as String?) ?? PlaybackIntent.normal,
      preferredQuality: json['preferredQuality'] as String?,
      preferredLanguage: json['preferredLanguage'] as String?,
      region: json['region'] as String?,
      networkMetered: json['networkMetered'] as bool? ?? false,
      metadata: asObjectMap(json['metadata']),
    );
  }

  final PlaybackIntent intent;

  /// A quality label agreed with the source, for example `1080p`. Never a player setting.
  final String? preferredQuality;
  final String? preferredLanguage;
  final String? region;

  /// True when the network charges by volume, which makes a lower quality the better default.
  final bool networkMetered;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'intent': intent.name,
      if (preferredQuality != null) 'preferredQuality': preferredQuality,
      if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
      if (region != null) 'region': region,
      if (networkMetered) 'networkMetered': true,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}

/// A request to turn content into something playable.
final class ResolveRequest {
  const ResolveRequest({required this.ref, this.context = const ResolveContext(), this.allowFallback = true});

  factory ResolveRequest.fromJson(Map<String, Object?> json) {
    return ResolveRequest(
      ref: ContentRef.fromJson(asObjectMap(json['ref'])),
      context: ResolveContext.fromJson(asObjectMap(json['context'])),
      allowFallback: json['allowFallback'] as bool? ?? true,
    );
  }

  final ContentRef ref;
  final ResolveContext context;

  /// Whether another source may be tried when this one cannot serve the content.
  final bool allowFallback;

  Map<String, Object?> toJson() {
    return <String, Object?>{'ref': ref.toJson(), 'context': context.toJson(), 'allowFallback': allowFallback};
  }
}

/// How to choose among the tickets a resolver produced.
final class MediaSelectionPolicy {
  const MediaSelectionPolicy({
    this.preferredQuality,
    this.preferredProtocol,
    this.preferredFormat,
    this.preferLowLatency = false,
    this.preferStable = true,
  });

  factory MediaSelectionPolicy.fromJson(Map<String, Object?> json) {
    return MediaSelectionPolicy(
      preferredQuality: json['preferredQuality'] as String?,
      preferredProtocol: enumByName(MediaProtocol.values, json['preferredProtocol'] as String?),
      preferredFormat: json['preferredFormat'] as String?,
      preferLowLatency: json['preferLowLatency'] as bool? ?? false,
      preferStable: json['preferStable'] as bool? ?? true,
    );
  }

  final String? preferredQuality;
  final MediaProtocol? preferredProtocol;
  final String? preferredFormat;
  final bool preferLowLatency;
  final bool preferStable;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (preferredQuality != null) 'preferredQuality': preferredQuality,
      if (preferredProtocol != null) 'preferredProtocol': preferredProtocol!.name,
      if (preferredFormat != null) 'preferredFormat': preferredFormat,
      if (preferLowLatency) 'preferLowLatency': true,
      if (!preferStable) 'preferStable': false,
    };
  }
}

/// The outcome of a resolve: tickets plus the policy that ranked them.
final class ResolveResult {
  const ResolveResult({
    required this.source,
    required this.tickets,
    required this.createdAt,
    this.selection = const MediaSelectionPolicy(),
    this.metadata = const <String, Object?>{},
  });

  factory ResolveResult.fromJson(Map<String, Object?> json) {
    return ResolveResult(
      source: ContentRef.fromJson(asObjectMap(json['source'])),
      tickets: asObjectMapList(json['tickets']).map(MediaTicket.fromJson).toList(growable: false),
      createdAt: parseUtc(json['createdAt']) ?? DateTime.utc(1970),
      selection: MediaSelectionPolicy.fromJson(asObjectMap(json['selection'])),
      metadata: asObjectMap(json['metadata']),
    );
  }

  /// The content that was asked for, echoed so a cached result stays attributable.
  final ContentRef source;

  /// Ordered by preference; empty means nothing playable was found.
  final List<MediaTicket> tickets;
  final DateTime createdAt;
  final MediaSelectionPolicy selection;
  final Map<String, Object?> metadata;

  bool get isEmpty => tickets.isEmpty;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'source': source.toJson(),
      'tickets': tickets.map((ticket) => ticket.toJson()).toList(growable: false),
      'createdAt': formatUtc(createdAt),
      'selection': selection.toJson(),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}
