// Module: lib/src/manifest.dart
// Purpose: The backup manifest and the per-domain report that decides what a restore may touch.
// Author: liuchuancong
// Created: 2026-10-08
//
// docs/migration/v1-to-v2.md and docs/services/backup.md set the rules: a backup is a set of independent
// domain snapshots, one failing domain must not stop the others, and credentials are never part of it.
// Excluding them is done through an injected predicate rather than a hard-coded list, because the key
// layout that marks a credential belongs to another package.

/// One domain inside a backup: settings, favorites, history, playlists, and so on.
final class BackupDomain {
  const BackupDomain({required this.name, required this.keyCount, required this.bytes});

  /// A stable identifier such as `settings` or `favorites`; it is the resume unit of a restore.
  final String name;
  final int keyCount;
  final int bytes;

  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'keyCount': keyCount,
        'bytes': bytes,
      };

  factory BackupDomain.fromJson(Map<String, Object?> json) => BackupDomain(
        name: json['name']! as String,
        keyCount: (json['keyCount'] as num?)?.toInt() ?? 0,
        bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      );
}

/// The header of a backup archive.
final class BackupManifest {
  const BackupManifest({
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.domains,
    this.includesCredentials = false,
  });

  /// The data format version, checked before anything is applied.
  final int schemaVersion;

  /// The application build that produced the archive, for display and for migration ordering.
  final String appVersion;
  final DateTime createdAt;
  final List<BackupDomain> domains;

  /// Always false in practice. The field exists so an archive that claims otherwise can be refused
  /// loudly instead of being trusted.
  final bool includesCredentials;

  int get totalBytes => domains.fold<int>(0, (sum, domain) => sum + domain.bytes);

  List<String> get domainNames => domains.map((domain) => domain.name).toList(growable: false);

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'appVersion': appVersion,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'includesCredentials': includesCredentials,
      'domains': domains.map((domain) => domain.toJson()).toList(growable: false),
    };
  }

  factory BackupManifest.fromJson(Map<String, Object?> json) {
    return BackupManifest(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      appVersion: json['appVersion'] as String? ?? '',
      createdAt: DateTime.tryParse('${json['createdAt']}')?.toUtc() ?? DateTime.utc(1970),
      includesCredentials: json['includesCredentials'] as bool? ?? false,
      domains: (json['domains'] as List? ?? const <Object?>[])
          .whereType<Map<Object?, Object?>>()
          .map((item) => BackupDomain.fromJson(Map<String, Object?>.from(item)))
          .toList(growable: false),
    );
  }

  /// Refuses an archive that carries credentials or declares an unknown format.
  ///
  /// [supportedSchemaVersions] is the set this build can read. A future version is rejected rather than
  /// partially applied, because half-restored settings look exactly like a successful restore.
  String? validate({required Set<int> supportedSchemaVersions}) {
    if (includesCredentials) {
      return 'the archive claims to contain credentials, which this build never writes or reads';
    }
    if (!supportedSchemaVersions.contains(schemaVersion)) {
      return 'unsupported backup schema version $schemaVersion';
    }
    final names = <String>{};
    for (final domain in domains) {
      if (domain.name.isEmpty) {
        return 'a domain entry has no name';
      }
      if (!names.add(domain.name)) {
        return 'duplicate domain "${domain.name}" in the manifest';
      }
    }
    return null;
  }
}

/// What happened to one domain during a restore.
enum DomainOutcome { applied, skipped, failed }

/// The per-domain result of a restore, so a retry can resume with only what did not land.
final class RestoreReport {
  const RestoreReport({required this.results, required this.skippedCredentials});

  final Map<String, DomainOutcome> results;

  /// How many keys were refused because they belong to the credential store.
  final int skippedCredentials;

  List<String> get failedDomains =>
      results.entries.where((entry) => entry.value == DomainOutcome.failed).map((entry) => entry.key).toList();

  List<String> get appliedDomains =>
      results.entries.where((entry) => entry.value == DomainOutcome.applied).map((entry) => entry.key).toList();

  bool get isComplete => failedDomains.isEmpty;

  @override
  String toString() =>
      'RestoreReport(applied=${appliedDomains.length}, failed=${failedDomains.length}, '
      'skippedCredentials=$skippedCredentials)';
}
