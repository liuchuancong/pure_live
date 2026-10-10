# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `codec.dart`: an archive is bytes now, not an in-memory bundle. `encodeBundle` writes
  `{format, container, manifest, payload, digest, manifestDigest}`; `decodeBundle` measures the payload before
  parsing it (`kBackupMaxBytes`), refuses a foreign `format`, a newer container, a bad schema version, a missing
  domain, a key-count lie, and any alteration to either the payload or the manifest - each as a named
  `BackupCodecFailure` rather than as a silent empty restore.
- The payload digest is taken over **canonical JSON** (keys sorted). Dart's map order is insertion order, so a
  digest over the raw encoding would fail for identical content that travelled through a different device,
  which turns an integrity check into a coin flip.
- `archiver.dart`: `BackupArchiveStore` (byte-oriented), `InMemoryArchiveStore`, `BackupArchiver` (build →
  encode → write → prune in one call, reporting what it pruned), `backupArchiveName` (sortable UTC name) and
  `archivesToPrune` with a count **and** an age bound.
- `RestoreEngine.plan`: the summary-before-confirmation step docs/services/backup.md requires. A summary
  produced by writing is not a summary - cancelling halfway leaves the state the plan warned about.
- `RestoreEngine.supportedSchemaVersions` is now a parameter; it was a hardcoded `{1}` inside `apply`.
- `BackupEngine.maxKeysPerDomain` refuses an absurdly large domain instead of building an archive no transport
  carries and no restore finishes.
- `_sizeOf` counted a list by its element *count*, understating a playlist by an order of magnitude; it now
  recurses.
- `pubspec.yaml`: `crypto ^3.0.0` added for SHA-256.
