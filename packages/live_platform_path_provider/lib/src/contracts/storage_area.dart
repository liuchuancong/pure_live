/// Which kind of data a directory holds. The area decides persistence,
/// fallback and cleanup rules — never mix a cache area into a data
/// location "because it is writable".
enum StorageArea {
  /// Settings, databases, history, accounts: persistent, migrated with
  /// care, never auto-cleaned.
  data,

  /// Configuration files: persistent and user-editable.
  config,

  /// Covers, thumbnails, re-fetchable parse results: clearable, size-capped,
  /// never the only copy of anything.
  cache,

  /// Imported scripts, plugin configs, per-plugin runtime data: isolated
  /// per plugin id underneath one root.
  extensions,

  /// User-initiated imports (M3U, TVBox configs): reached through the
  /// file-access service, not assumed inside app storage.
  imports,

  /// User-initiated exports and backups: written where the user chose.
  exports,

  /// Finished downloads the user will open outside the app: persistent and
  /// user-visible by construction — when the only available directory is
  /// app-private, the caller is told through `StorageLocation.isPrivate`
  /// and must offer the user a choice before writing.
  downloads,

  /// Download intermediates, migration scratch space: clearable at any
  /// time, never persistent.
  temporary,
}
