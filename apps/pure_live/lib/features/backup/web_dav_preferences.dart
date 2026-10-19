// Named factories spell their class name; the `new` shorthand cannot carry
// per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:flutter/foundation.dart' show immutable;

/// One named WebDAV server the user configured for cloud backups (the
/// reference's `WebDavServer`: the drawer can hold several drives, the
/// document keeps one active at a time). The password is NOT part of it —
/// it lives in the encrypted secret vault under `webdav/<name>`, so nothing
/// sensitive rides in the plain settings document.
@immutable
final class WebDavServer {
  /// A server entry.
  const new({
    required this.name,
    required this.address,
    required this.username,
    this.directory = '',
    this.lastBackupAt,
    this.lastRestoreAt,
  });

  /// Reads a server from JSON; unknown shapes degrade field by field.
  factory WebDavServer.fromJson(Map<String, Object?> json) {
    DateTime? when(Object? value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;
    return WebDavServer(
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      directory: json['directory']?.toString() ?? '',
      lastBackupAt: when(json['lastBackupAt']),
      lastRestoreAt: when(json['lastRestoreAt']),
    );
  }

  /// The label the drawer lists it under; unique across the servers, which
  /// is what makes it the secret vault's key too.
  final String name;

  /// The server's base URL, e.g. `https://dav.jianguoyun.com/dav/`.
  final String address;

  /// The account name the server authenticates.
  final String username;

  /// A sub-directory the backups are stored in, relative to the address;
  /// empty means the address' own root.
  final String directory;

  /// When this server last received an upload, null before the first.
  final DateTime? lastBackupAt;

  /// When this server last gave a restore, null before the first.
  final DateTime? lastRestoreAt;

  /// Writes this server to JSON.
  Map<String, Object?> toJson() => {
    'name': name,
    'address': address,
    'username': username,
    if (directory.isNotEmpty) 'directory': directory,
    if (lastBackupAt case final at?) 'lastBackupAt': at.toUtc().toIso8601String(),
    if (lastRestoreAt case final at?) 'lastRestoreAt': at.toUtc().toIso8601String(),
  };

  /// Returns a copy with the given fields replaced.
  WebDavServer copyWith({
    String? name,
    String? address,
    String? username,
    String? directory,
    DateTime? lastBackupAt,
    DateTime? lastRestoreAt,
  }) => WebDavServer(
    name: name ?? this.name,
    address: address ?? this.address,
    username: username ?? this.username,
    directory: directory ?? this.directory,
    lastBackupAt: lastBackupAt ?? this.lastBackupAt,
    lastRestoreAt: lastRestoreAt ?? this.lastRestoreAt,
  );

  @override
  bool operator ==(Object other) =>
      other is WebDavServer &&
      other.name == name &&
      other.address == address &&
      other.username == username &&
      other.directory == directory &&
      other.lastBackupAt == lastBackupAt &&
      other.lastRestoreAt == lastRestoreAt;

  @override
  int get hashCode => Object.hash(name, address, username, directory, lastBackupAt, lastRestoreAt);
}

/// The WebDAV cloud-backup choices, as persisted (the reference's server
/// list, collapsed to this app's document shape).
///
/// One document in the settings box (`preferences.webdav.v2`), shaped like
/// the appearance document: plain JSON primitives only, versioned in its
/// key — the v1 single-config document is migrated by the store, not read
/// here.
@immutable
final class WebDavPreferences {
  /// The preferences with the shipping defaults: no servers, none active.
  const new({this.servers = const [], this.active});

  /// Reads the document from JSON; unknown shapes degrade to their default
  /// field rather than failing the whole document.
  factory fromJson(Map<String, Object?> json) {
    final rawServers = json['servers'];
    final servers = [
      if (rawServers is List)
        for (final entry in rawServers)
          if (entry is Map) WebDavServer.fromJson(Map<String, Object?>.from(entry)),
    ];
    final active = json['active']?.toString();
    return WebDavPreferences(servers: servers, active: active == null || active.isEmpty ? null : active);
  }

  /// The configured servers, oldest added first.
  final List<WebDavServer> servers;

  /// The name of the server the page works against; null while there is
  /// none (or the stored name no longer has a server).
  final String? active;

  /// The active server, falling back to the only/first one when the stored
  /// name is stale — a deleted selection must not strand the page.
  WebDavServer? get activeServer {
    for (final server in servers) {
      if (server.name == active) {
        return server;
      }
    }
    return servers.isEmpty ? null : servers.first;
  }

  /// Writes this document to JSON.
  Map<String, Object?> toJson() => {
    'servers': [for (final server in servers) server.toJson()],
    'active': ?active,
  };

  /// Returns a copy with the given fields replaced; [clearActive] takes the
  /// selection off (the update idiom's null-else-keeps cannot say that).
  WebDavPreferences copyWith({List<WebDavServer>? servers, String? active, bool clearActive = false}) =>
      WebDavPreferences(servers: servers ?? this.servers, active: clearActive ? null : (active ?? this.active));

  @override
  bool operator ==(Object other) =>
      other is WebDavPreferences &&
      other.active == active &&
      other.servers.length == servers.length &&
      [
        for (var index = 0; index < servers.length; index++)
          if (other.servers[index] != servers[index]) false,
      ].every((changed) => changed);

  @override
  int get hashCode => Object.hash(active, Object.hashAll(servers));
}
