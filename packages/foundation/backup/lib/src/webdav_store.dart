// Module: lib/src/webdav_store.dart
// Purpose: A WebDAV remote for backup documents: upload, list, download and
// delete named snapshots over any standard WebDAV endpoint.
// Author: liuchuancong
// Created: 2026-10-10
//
// docs/services/backup.md - WebDAV is the cross-device transport v1 users
// already run (坚果云, Nextcloud, self-hosted Apache). This adapter speaks
// PROPFIND/GET/PUT/DELETE through webdav_client and stores one JSON document
// per snapshot name; it knows nothing about the document contents.

import 'dart:convert';

import 'package:webdav_client/webdav_client.dart' as webdav;

/// One snapshot listed on the remote.
final class WebDavSnapshot {
  const WebDavSnapshot({required this.name, required this.sizeBytes, required this.modifiedAt});

  final String name;
  final int sizeBytes;
  final DateTime modifiedAt;
}

/// A WebDAV endpoint bound to one backup directory.
final class WebDavBackupStore {
  WebDavBackupStore({required this.endpoint, required this.directory, this.client});

  /// The endpoint root, for example `https://dav.jianguoyun.com/dav/`.
  final Uri endpoint;

  /// The collection under [endpoint] snapshots live in, created on first
  /// upload if missing.
  final String directory;

  /// A pre-built client for tests; otherwise one is built from the
  /// endpoint's credentials via [connect].
  final webdav.Client? client;

  webdav.Client? _ownClient;

  /// Authenticates and returns a ready store. [user]/[password] are the
  /// WebDAV account; passwords live in the credential store, never in the
  /// backup document itself.
  static Future<WebDavBackupStore> connect({
    required Uri endpoint,
    required String directory,
    required String user,
    required String password,
  }) async {
    final store = WebDavBackupStore(
      endpoint: endpoint,
      directory: directory,
      client: webdav.newClient(endpoint.toString(), user: user, password: password, debug: false),
    );
    await store._ownClient!.ping();
    return store;
  }

  String _pathFor(String name) {
    final dirPart = directory.endsWith('/') ? directory : '$directory/';
    return '$dirPart$name';
  }

  /// Uploads [document] as snapshot [name]. Overwrites an existing snapshot
  /// with the same name - that is what "save again" means.
  Future<void> upload(String name, Map<String, Object?> document) async {
    final client = _requireClient();
    final dirPath = directory.endsWith('/') ? directory.substring(0, directory.length - 1) : directory;
    try {
      await client.mkdir(dirPath);
    } catch (_) {
      // 405/301 from an existing collection is success for mkdir's purpose.
    }
    await client.write(_pathFor(name), utf8.encode(const JsonEncoder.withIndent('  ').convert(document)));
  }

  /// Downloads snapshot [name], or throws when it is absent.
  Future<Map<String, Object?>> download(String name) async {
    final client = _requireClient();
    final bytes = await client.read(_pathFor(name));
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('snapshot document is not a JSON object');
    }
    return Map<String, Object?>.from(decoded);
  }

  /// Lists the snapshots on the remote, newest first.
  Future<List<WebDavSnapshot>> list() async {
    final client = _requireClient();
    final dirPath = directory.endsWith('/') ? directory.substring(0, directory.length - 1) : directory;
    final list = await client.readDir(dirPath);
    final snapshots = <WebDavSnapshot>[
      for (final item in list)
        if ((item.name ?? '').endsWith('.json') && item.path != null)
          WebDavSnapshot(
            name: item.name!,
            sizeBytes: item.size ?? 0,
            modifiedAt: item.mTime ?? DateTime.fromMillisecondsSinceEpoch(0),
          ),
    ];
    snapshots.sort((a, b) => -a.modifiedAt.compareTo(b.modifiedAt));
    return snapshots;
  }

  /// Deletes one snapshot.
  Future<void> delete(String name) async {
    await _requireClient().remove(_pathFor(name));
  }

  webdav.Client _requireClient() => client ?? _ownClient ?? (throw StateError('WebDAV store is not connected'));
}
