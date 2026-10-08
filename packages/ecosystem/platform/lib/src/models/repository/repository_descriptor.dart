// Module: lib/src/models/repository/repository_descriptor.dart
// Purpose: Describes a content repository and the providers it exposes, the unit users import and share.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-models.md section 6 and docs/contracts/repository-contract.md. A
// repository is a collection of sources; it is not a plugin and does not become one.

import '../../support/json.dart';
import '../identifiers.dart';

/// What a repository can serve.
enum RepositoryCapability { list, detail, search, category, recommendation, resolve, playlist, epg }

/// Which parser family reads the repository, from docs/contracts/repository-contract.md section 1.
enum RepositoryParser { tvboxJson, m3u, epgXmltv, opml, plugin, unknown }

/// A content repository behind one source.
final class RepositoryDescriptor {
  const RepositoryDescriptor({
    required this.id,
    required this.sourceId,
    required this.name,
    required this.version,
    this.parser = RepositoryParser.unknown,
    this.capabilities = const <RepositoryCapability>{},
    this.metadata = const <String, Object?>{},
  });

  factory RepositoryDescriptor.fromJson(Map<String, Object?> json) {
    return RepositoryDescriptor(
      id: requireString(json, 'id', 'repository_descriptor'),
      sourceId: requireString(json, 'sourceId', 'repository_descriptor'),
      name: requireString(json, 'name', 'repository_descriptor'),
      version: requireString(json, 'version', 'repository_descriptor'),
      parser: enumByName(RepositoryParser.values, json['parser'] as String?) ?? RepositoryParser.unknown,
      capabilities: _capabilities(json['capabilities']),
      metadata: asObjectMap(json['metadata']),
    );
  }

  final RepositoryId id;
  final SourceId sourceId;
  final String name;
  final String version;
  final RepositoryParser parser;
  final Set<RepositoryCapability> capabilities;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'sourceId': sourceId,
      'name': name,
      'version': version,
      if (parser != RepositoryParser.unknown) 'parser': parser.name,
      if (capabilities.isNotEmpty) 'capabilities': capabilities.map((c) => c.name).toList(),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is RepositoryDescriptor &&
        other.id == id &&
        other.sourceId == sourceId &&
        other.version == version &&
        other.parser == parser;
  }

  @override
  int get hashCode => Object.hash(id, sourceId, version, parser);
}

/// What a provider serves inside a repository.
enum ProviderType { live, vod, music, album, artist, lyrics, playlist, epg, search, detail, resolve, recommendation }

/// One provider of one repository.
final class ProviderDescriptor {
  const ProviderDescriptor({
    required this.id,
    required this.repositoryId,
    required this.name,
    required this.type,
    required this.version,
  });

  factory ProviderDescriptor.fromJson(Map<String, Object?> json) {
    return ProviderDescriptor(
      id: requireString(json, 'id', 'repository_descriptor'),
      repositoryId: requireString(json, 'repositoryId', 'repository_descriptor'),
      name: requireString(json, 'name', 'repository_descriptor'),
      type: enumByName(ProviderType.values, json['type'] as String?) ?? ProviderType.vod,
      version: requireString(json, 'version', 'repository_descriptor'),
    );
  }

  final ProviderId id;
  final RepositoryId repositoryId;
  final String name;
  final ProviderType type;
  final String version;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'repositoryId': repositoryId,
      'name': name,
      'type': type.name,
      'version': version,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is ProviderDescriptor &&
        other.id == id &&
        other.repositoryId == repositoryId &&
        other.type == type &&
        other.version == version;
  }

  @override
  int get hashCode => Object.hash(id, repositoryId, type, version);
}

Set<RepositoryCapability> _capabilities(Object? value) {
  if (value is! List) {
    return const <RepositoryCapability>{};
  }
  return value
      .map((item) => enumByName(RepositoryCapability.values, '$item'))
      .whereType<RepositoryCapability>()
      .toSet();
}
