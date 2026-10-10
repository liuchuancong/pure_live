// Module: lib/src/storage_locations.dart
// Purpose: What each storage location is for, and which hosts can offer it at all.
// Author: liuchuancong
// Created: 2026-10-11
//
// This package cannot import pure_live_platform_info: both are L0, and section 3 of the dependency rules
// forbids foundation-to-foundation edges (the leaves are utils and logging only). So the host taxonomy is
// repeated here on purpose - four values, not a capability matrix - and the two stay aligned by the test that
// asserts each name exists. Inventing a shared enum in a third place would be worse than the duplication.

/// The operating environment a path is being resolved for.
enum HostPlatform { android, ios, macos, windows, linux, web }

/// One kind of file the application writes, named for what it is *for* rather than for a directory.
///
/// Naming by purpose is what makes a portable build, an MSIX build and an Android build agree: each host
/// maps a purpose to its own convention, and no caller has to know that Windows says `%APPDATA%` while Linux
/// says `$XDG_STATE_HOME`.
enum StorageKind {
  /// Settings, credentials index, watch history, favourites. Survives an update; lost on uninstall.
  userData,

  /// The relational or key-value database files, kept separate from loose documents so a backup can be taken
  /// of one without the other.
  database,

  /// Diagnostics and crash logs. Bounded by the guard, never by the caller's memory.
  logs,

  /// Thumbnails, stream segments, spider scripts. The system may evict this at any time, and the app must
  /// survive that - so nothing here may be the only copy of anything.
  cache,

  /// Short-lived scratch space: a temp file mid-download, an archive being assembled.
  temp,

  /// Files the user asked to keep and expects to find with a file manager: recordings, exported playlists.
  downloads,

  /// Read-write documents the user chose, on hosts that expose such a directory at all.
  documents,

  /// Shared media the user can see in their gallery or music app.
  media,

  /// Backup archives the app writes and may read back.
  backups,

  /// Extracted plugin and extension bundles, each in its own namespace.
  plugins,
}

/// A host that has no file system at all: every location answers "unavailable" with the same reason, so a web
/// build degrades to memory instead of throwing on the first settings write.
bool hostHasFileSystem(HostPlatform platform) => platform != HostPlatform.web;

/// Whether a location may be evicted by the operating system without the app being asked.
///
/// True for [StorageKind.cache] and [StorageKind.temp] on every host. A caller that puts something evictable
/// here has to be able to rebuild it, which is the property a "clear cache" button depends on.
bool isEvictable(StorageKind kind) => switch (kind) {
  StorageKind.cache => true,
  StorageKind.temp => true,
  _ => false,
};

/// Whether a location is user-visible - something the user may open in a file manager and expect to find.
///
/// User-visible locations are never cleaned up automatically: deleting a recording to reclaim space is a
/// decision that belongs to the user, not to a cache policy.
bool isUserVisible(StorageKind kind) => switch (kind) {
  StorageKind.downloads => true,
  StorageKind.documents => true,
  StorageKind.media => true,
  StorageKind.backups => true,
  _ => false,
};

/// Whether a location must be kept out of cloud backup and of any sync document.
///
/// Caches and scratch space are rebuilt, so shipping them costs the user bandwidth and storage for nothing;
/// logs may carry urls with signed tokens in the query string.
bool isExcludedFromBackup(StorageKind kind) => switch (kind) {
  StorageKind.cache => true,
  StorageKind.temp => true,
  StorageKind.logs => true,
  _ => false,
};

/// The subdirectory a kind occupies inside its parent, so two hosts that share a convention agree on the name.
///
/// Overridable per host: Windows wants `Cache`, Linux wants `cache`, and an app that hard-codes either one
/// looks wrong on the other.
String subdirectoryFor(StorageKind kind, HostPlatform platform) => switch (kind) {
  StorageKind.userData => '',
  StorageKind.database => platform == HostPlatform.windows ? 'Database' : 'database',
  StorageKind.logs => platform == HostPlatform.windows ? 'Logs' : 'logs',
  StorageKind.cache => platform == HostPlatform.windows ? 'Cache' : 'cache',
  StorageKind.temp => platform == HostPlatform.windows ? 'Temp' : 'tmp',
  StorageKind.downloads => platform == HostPlatform.windows ? 'Downloads' : 'downloads',
  StorageKind.documents => platform == HostPlatform.windows ? 'Documents' : 'documents',
  StorageKind.media => platform == HostPlatform.windows ? 'Media' : 'media',
  StorageKind.backups => platform == HostPlatform.windows ? 'Backups' : 'backups',
  StorageKind.plugins => platform == HostPlatform.windows ? 'Plugins' : 'plugins',
};
