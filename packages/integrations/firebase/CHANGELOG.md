# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `firestore_remote.dart`: `FirestoreSyncRemote` binds the sync engine's `RemoteStore` port to one Firestore
  collection. The cursor is the highest `updatedAt` seen rather than a Firestore page token (a token expires and
  cannot be compared, and `SyncCursor` has to advance monotonically); pushes are split at the database's 500
  writes-per-commit, records past `maxPushRecords` stay pending locally, and tombstones carry no value so a
  deletion does not leave the deleted content in the cloud. Credential keys are refused here as well as in the
  engine.
- `crash_reporting.dart`: `CrashGate` + `CrashConsentStore`/`CrashReporter` ports + `CrashLogSink`. Nothing
  leaves the device before consent; reports raised while the answer is unresolved are held in a bounded buffer
  (a first-launch crash happens before the dialog has an answer and is the only evidence of itself), a **decline
  destroys the buffer**, and a buffered report older than `maxAge` is dropped instead of sent as if it were now.
  A throwing uploader is recorded, never rethrown.
- The vendor crash/analytics SDKs are deliberately not depended on: they need build-time gradle plugins, so this
  layer ships the gate and the port and the plugin binding belongs to whichever build carries them.
- `pubspec.yaml`: `cloud_firestore ^6.10.0` (the version `apps/pure_live` already pins), `pure_live_sync`,
  `pure_live_logging`, `pure_live_utils`.
