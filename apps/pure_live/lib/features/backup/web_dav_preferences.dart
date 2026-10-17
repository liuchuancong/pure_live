import 'package:flutter/foundation.dart' show immutable;
import 'package:pure_live/features/backup/web_dav_config.dart';

/// The WebDAV cloud-backup choices, as persisted.
///
/// One document in the settings box (`preferences.webdav.v1`), shaped like
/// the appearance document: plain JSON primitives only, versioned in its
/// key, so a reshaped document moves to `.v2` with a migration instead of
/// poisoning this group's reader.
@immutable
final class WebDavPreferences {
  /// The preferences with the shipping defaults: nothing configured, no
  /// sync ever recorded.
  const new({this.config, this.lastBackupAt, this.lastRestoreAt});

  /// Reads the document from JSON; unknown shapes degrade to their default
  /// field rather than failing the whole document.
  factory fromJson(Map<String, Object?> json) {
    DateTime? when(Object? value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;
    final rawConfig = json['config'];
    return WebDavPreferences(
      config: rawConfig is Map<Object?, Object?> ? WebDavConfig.fromJson(Map<String, Object?>.from(rawConfig)) : null,
      lastBackupAt: when(json['lastBackupAt']),
      lastRestoreAt: when(json['lastRestoreAt']),
    );
  }

  /// The configured server, null while the form is still empty.
  final WebDavConfig? config;

  /// When the last backup upload finished, null before the first one.
  final DateTime? lastBackupAt;

  /// When the last restore from the server finished, null before the first.
  final DateTime? lastRestoreAt;

  /// Writes this document to JSON.
  Map<String, Object?> toJson() => {
    if (config case final config?) 'config': config.toJson(),
    if (lastBackupAt case final at?) 'lastBackupAt': at.toUtc().toIso8601String(),
    if (lastRestoreAt case final at?) 'lastRestoreAt': at.toUtc().toIso8601String(),
  };

  /// Returns a copy with the given fields replaced.
  WebDavPreferences copyWith({WebDavConfig? config, DateTime? lastBackupAt, DateTime? lastRestoreAt}) =>
      WebDavPreferences(
        config: config ?? this.config,
        lastBackupAt: lastBackupAt ?? this.lastBackupAt,
        lastRestoreAt: lastRestoreAt ?? this.lastRestoreAt,
      );

  @override
  bool operator ==(Object other) =>
      other is WebDavPreferences &&
      other.config == config &&
      other.lastBackupAt == lastBackupAt &&
      other.lastRestoreAt == lastRestoreAt;

  @override
  int get hashCode => Object.hash(config, lastBackupAt, lastRestoreAt);
}
