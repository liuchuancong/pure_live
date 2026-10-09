// Module: lib/src/models/resolver/resolver_descriptor.dart
// Purpose: Identifies one resolver and says what kind of content it turns into tickets.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/contracts/platform-contracts.md section 12 (Resolver: descriptor, canResolve, resolve) and its
// type list Live / Vod / Music / Iptv / Local / Download. The descriptor is data; the behaviour belongs to
// pure_live_resolver, per docs/adr/0018-contract-package-split.md.

import '../../support/json.dart';
import '../content/content_ref.dart';
import '../identifiers.dart';

/// What a resolver turns into a ticket.
enum ResolverKind { live, vod, music, iptv, local, download }

/// A resolver's identity and reach.
final class ResolverDescriptor {
  const ResolverDescriptor({
    required this.id,
    required this.name,
    required this.kind,
    this.providerId,
    this.priority = 0,
  });

  factory ResolverDescriptor.fromJson(Map<String, Object?> json) => ResolverDescriptor(
    id: requireString(json, 'id', 'resolver_descriptor'),
    name: requireString(json, 'name', 'resolver_descriptor'),
    kind: enumByName(ResolverKind.values, json['kind'] as String?) ?? ResolverKind.vod,
    providerId: json['providerId'] as String?,
    priority: (json['priority'] as num?)?.toInt() ?? 0,
  );

  final ResolverId id;
  final String name;
  final ResolverKind kind;

  /// Which provider inside a repository this resolver drives, when the source distinguishes them.
  final ProviderId? providerId;

  /// Higher wins when several resolvers can serve the same content.
  final int priority;

  /// The content kinds this kind of resolver is asked about, used by a registry that selects without
  /// consulting the resolver itself.
  bool serves(ContentKind contentKind) => switch ((kind, contentKind)) {
    (ResolverKind.live, ContentKind.liveChannel || ContentKind.liveRoom || ContentKind.stream) => true,
    (ResolverKind.iptv, ContentKind.liveChannel || ContentKind.epgProgram) => true,
    (ResolverKind.music, ContentKind.music || ContentKind.album || ContentKind.artist) => true,
    (ResolverKind.vod, ContentKind.vod || ContentKind.movie || ContentKind.series || ContentKind.episode) => true,
    (ResolverKind.local, ContentKind.localMedia) => true,
    (ResolverKind.download, ContentKind.stream || ContentKind.vod) => true,
    _ => false,
  };

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'kind': kind.name,
    if (providerId != null) 'providerId': providerId,
    if (priority != 0) 'priority': priority,
  };

  @override
  String toString() => 'ResolverDescriptor($id ${kind.name} priority:$priority)';

  @override
  bool operator ==(Object other) =>
      other is ResolverDescriptor && other.id == id && other.kind == kind && other.priority == priority;

  @override
  int get hashCode => Object.hash(id, kind, priority);
}
