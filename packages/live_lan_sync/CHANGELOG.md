# Changelog

## 0.1.0

- Phase 1 skeleton per `docs/live-lan-sync-spec.md`:
  - `LanSyncConfig` and its per-area configuration types with validation.
  - Domain models: `SyncDevice`, `DeviceTrust`, `SyncChange`, `SyncCursor`,
    `SyncManifest`, `SyncTask`, `VersionVector`, conflict types.
  - `LanSyncError` with the stable error-category taxonomy.
  - `DeviceDiscovery`, `LanSyncDataAdapter` and `LanSyncStore` contracts.
  - Discovery dependency pinned to `bonsoir: ^7.1.6`.

- Phase 2 device discovery per `docs/live-lan-sync-spec.md`:
  - `DiscoveredDeviceDirectory`: deduplication by device id, TTL sweep for
    discovered entries, manual entries that never expire, broadcast change
    stream.
  - `DeviceDiscovery` implementation over Bonsoir (mDNS registration and
    browsing, TXT mapping with the five public facts, foreign-service
    filtering), reachable only through `createMdnsDiscovery` so Bonsoir's
    types stay internal.
  - `NetworkMonitor`: interface-address polling with self-healing browse
    restarts on Wi-Fi/VPN/dock changes.
  - Tests for the directory, the service mapping and the monitor.

- Phase 3 identity and pairing per `docs/live-lan-sync-spec.md`:
  - `LocalDeviceIdentity`: random persistent device id (never IP/MAC/serial).
  - Trust management, per-device sliding-window rate limiting,
    `KeyFingerprints` (sha256: hex), `PairingOutcome` results.
  - `SecureCredentialStore` contract (`SecureKey` namespacing) for the
    host's platform vault.

- Phase 4 secure communication per `docs/live-lan-sync-spec.md`:
  - TLS is mandatory. `TlsIdentity` carries the device's self-signed
    certificate and key; `LanSyncHttpServer` serves only over TLS and
    `LanSyncHttpClient` trusts no CA, accepting exactly the certificate
    fingerprint pinned at pairing (a mismatch is an `identityMismatch`,
    never retryable).
  - Requests are signed with HMAC-SHA256 (`RequestSigner`) over method,
    path, timestamp, single-use nonce and body hash; `ReplayGuard` closes
    the replay window. Protocol negotiation (`/hello`), device facts
    (`/device`), pluggable routes, per-sender rate limiting, body limits and
    a signed WebSocket event channel (`/events`).
  - Pairing over the wire (`/pair/challenge`, `/reveal`, `/confirm`,
    `/status`): `PairingResponder` and `PairingInitiator` implement
    Bluetooth SSP-style numeric comparison — X25519 key agreement (package
    `cryptography`), a responder commitment, a six-digit code both users
    compare, HKDF-SHA256 pairing secrets and role-bound key confirmation.
    Pairing windows, session lifetime, per-address and per-device rate
    limits, and a cap on concurrent sessions.
  - `DeviceTrustService` replaces the trust half of the Phase 3
    `PairingService`.

  Corrections to Phases 1–3, made before anything consumed them:
  - The Phase 3 ceremony derived the pairing secret from the six-digit code
    with PBKDF2. A code that short gives a secret an eavesdropper can brute
    force offline from one captured request, and the scheme was a home-grown
    handshake (spec §9.3 forbids both). It is replaced by the key agreement
    above; `PairingChallenge`, `PairingService.beginPairing/confirmPeer` and
    `pairingKdfIterations` are gone. `maxPendingPairingSessions` is new.
  - Plain HTTP is no longer possible: spec §9.1 and §20 require encryption.
  - `DeviceTrust` grants are documented from the holder's side — the record
    on device A about peer B says what B may do on A — which is how the
    server enforces them. `keyFingerprint` is the peer's TLS certificate
    fingerprint.

- Phase 5 incremental sync per `docs/live-lan-sync-spec.md`:
  - The change log lives in the `LanSyncStore`: the latest change per
    entity, ordered by one strictly increasing sequence. Deletes are
    tombstones in the log, so they propagate and an older version never
    resurrects an entity. `LoggedChange` carries an entry's sequence.
  - `SyncEngine`: `recordLocalChange` (version vector advanced for this
    device, serialized per scope), server routes `manifest/exchange`,
    `changes/pull`, `changes/push`, `changes/ack` (`attachTo`), and
    `synchronize` for pull, push or both against one peer through a
    `PeerSyncChannel` (`HttpPeerSyncChannel` over the pinned client).
  - Every received batch is validated, deduplicated by operation id,
    compared causally (newer → applied, older or equal → skipped as stale,
    concurrent → kept as a `SyncConflict`, never overwritten), applied by
    the adapter and committed with its cursor in one atomic
    `commitBatch`. A refused change stops the cursor right before it; an
    interruption resumes from the last committed batch.
  - Byte- and count-bounded batches, retries with exponential backoff for
    retryable failures, cooperative `SyncCancellation`, changes never
    echoed to their origin, relay across devices, cursor self-healing when
    a receiver lost track (rewind and resend), persisted and published
    `SyncTask`s.
  - Grants are enforced on both ends from each holder's side: data leaves a
    device only for a peer granted read and enters only from a peer granted
    write.

  Contract changes, made before anything consumed them:
  - `LanSyncStore`: the per-device outbox (`appendOutboxChange`,
    `pendingOutboxChanges`, `markOutboxConfirmed`, `pendingOutboxCount`)
    tracked "confirmed" globally, which cannot be right with more than one
    peer; it and the separate tombstone methods give way to the change log
    (`recordLocalChange`, `latestChange`, `changesAfter`,
    `latestSequence`) and the atomic `commitBatch`.
  - `LanSyncDataAdapter` keeps `applyChanges` and `resolveConflict`; the
    engine owns export and manifests, so `createManifest`, `exportChanges`
    and the misleading interface "default" `validateForSend` are gone.
  - `SyncManifest` describes what a scope offers one peer (schema version,
    log reach, read and write permission).

- Phase 6 conflict handling per `docs/live-lan-sync-spec.md`:
  - Concurrent versions with identical content (both devices made the same
    edit, or both deleted) are not conflicts: their version vectors are
    joined into a version with a deterministic id, so joins made on two
    devices at once deduplicate when they meet.
  - Real conflicts are persisted and reported, then settled by the scope's
    policy (`LanSyncOptions.scopeConflictPolicies`, falling back to
    `defaultConflictPolicy`; a policy the adapter does not honour means
    manual): `preferLocal`, `preferRemote`, `merge` and `keepBoth` (the
    latter two through `LanSyncDataAdapter.resolveConflict`).
  - Every decision — a policy's or the user's through
    `SyncEngine.resolveConflict` — is applied through the adapter and
    written as a new version that follows both conflicting versions, so it
    propagates and every device adopts it. A decision on an outdated local
    version is refused (`conflict_outdated`) with the record refreshed; a
    conflict another device settled first is dropped as superseded.
  - `LanSyncEvent` (sealed): `SyncConflictDetected`, `SyncConflictResolved`,
    `SyncConflictSuperseded` on `SyncEngine.events`.
  - Version vectors are capped by `maxVersionVectorEntries`: past it,
    entries of devices no longer trusted are dropped, which can only turn
    "newer" into "concurrent", never cause a silent overwrite.
  - `SyncConflictResolution` and its cases moved to the domain layer;
    `KeepBothResolution` gained `copyEntityId`. `LanSyncStore` gained
    `conflict` and the atomic `commitResolution`.

- Phase 7 file transfer per `docs/live-lan-sync-spec.md`:
  - `FileManifest`: one streaming pass over the source yields the size,
    whole-file SHA-256 and a SHA-256 per chunk. It validates itself on the
    wire (hash shape, chunk size 64 KiB–16 MiB, coverage) and sanitizes the
    sender's file name, which is display metadata only.
  - `LanSyncFileAdapter`: the host's per-category contract — where files
    are read, staged and finally landed; whether the content is already
    held; content validation before commit; a commit callback. The engine
    never builds a path from anything a peer sent.
  - `FileReceiver`: the server side (`attachTo` adds `files/init`,
    `files/{transferId}/chunks/{index}` (raw, binary),
    `files/{transferId}/status`, `files/{transferId}` DELETE). Each chunk
    is written through a temporary file and a rename, checked against its
    listed hash, and persisted; a resumed transfer — same session or a
    restarted app — re-verifies what is on disk and asks only for the
    missing chunks. Commit streams the chunks into one file, checks the
    whole-file hash, runs the adapter's validation, then moves the file
    into place atomically and deletes the staging. Refuses transfers when
    the peer lacks the file-receive grant, when the file or chunks exceed
    the caps, when chunk hashes are required but absent, and caps in-flight
    bytes across all incoming transfers. `purgeAbandoned` reclaims idle
    partial transfers.
  - `FileSender`: pin-and-sign client side over `PeerFileChannel`
    (`HttpPeerFileChannel`). Sends only the chunks the receiver reports
    missing, re-reads and re-hashes each chunk (a source file that changes
    mid-send stops the transfer with `source_changed` instead of shipping a
    mix), retries retryable request failures with backoff, honours a
    cooperative `SyncCancellation`, and records every outcome. `sendAll`
    transfers a batch with bounded concurrency; `cancel` abandons a
    transfer and asks the receiver to discard its partial state.
  - `FileTransferUpdated` events on both sides; `FileTransferRecord`s in
    the store (`saveFileTransfer`, `fileTransfer`, `fileTransfers`,
    `removeFileTransfer`).
  - Transport: routes gained `{name}` path parameters and raw binary
    bodies (still signature-covered), and request signatures now cover the
    query string as well, so `?protocolVersion=` cannot be swapped.

- Logging through live_log: the engine never creates sinks and never
  reaches a global. The host hands a view of its own `live_log` tree to
  `LanSyncLogger` and passes it to the discovery adapter, the sync engine,
  the transport server and client, the pairing responder and initiator, the
  trust service and the file sender and receiver; components given none log
  nowhere. Records land under per-subsystem categories
  (`<view>.sync`, `.transfer`, `.pairing`, ... and subject children such as
  `.sync.favorites`), pass live_log's emit-time redaction, and follow the
  spec's discipline (§18, §20): failures by code, category, retryability
  and device — never debug context; fingerprints abbreviated; file-system
  errors logged without their paths; no comparison codes, secrets,
  signatures, nonces or change payloads, ever.
  - `LanSyncLoggingConfig.level` now uses live_log's `LogLevel`, which the
    engine applies as its own build floor on top of the host tree's filter.

- Phase 8 PureLive integration (host side, `apps/pure_live/lib/features/lan_sync/`):
  - `SecureVaultCredentialStore` over flutter_secure_storage (Windows DPAPI /
    iOS Keychain / Android Keystore) for the TLS key and pairing secrets.
  - `DriftLanSyncStore`: the change log, cursors, idempotency ledger, tasks,
    conflicts and file transfers in `live_storage` JsonStore namespaces; the
    sequence counter recovers from the log when prefs lose it. Atomicity per
    the plan's §3.2: log first, then cursor, replay-safe.
  - `DeviceTlsIdentity`: a pointycastle-generated EC P-256 self-signed
    certificate (hand-built DER; no new dependencies). Verified against
    boringssl (`SecurityContext` accepts both files) and OpenSSL. The
    certificate is signed with RFC 6979 deterministic k and rebuilt from the
    stored key, so a rebuild is byte-identical and the pinned fingerprint
    never drifts.
  - `FavoritesSyncAdapter`: the `favorites` scope over the follow
    repository, applied through the repository (not the controller) so
    remote changes never echo into the log.
  - `lanSyncRuntimeProvider`: the composition root — settings switch drives
    store, identity, engine, TLS server, pairing responder and mDNS
    discovery; `FollowsController.add/remove` records local edits after the
    repository write.
  - Settings UI under 备份与同步 → 局域网同步 (Slang, zh/en): the switch,
    device name, certificate fingerprint with copy, nearby and paired
    device lists, sync-now, revoke, and the pairing dialog — both screens
    show the same six-digit code, each user confirms; mismatches, expiry
    and suspected tampering get explicit surfaces.

- Phase 9 stability (desktop scope):
  - `DeviceDiscovery.registerLocalService`: an empty `txt` now derives the
    standard five public facts from the implementation's device
    configuration. The first integration wiring passed a literal empty map,
    which every peer filtered out — devices could never see each other.
    Discovery-driven address learning and a debounced auto-sync
    (`LanSyncRuntime.scheduleAutoSync`, fired by the host after local
    edits) complete the loop: pair once and the favorites follow.
