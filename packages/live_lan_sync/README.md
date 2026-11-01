# live_lan_sync

LAN device discovery and data synchronization engine. Host-agnostic by
design: PureLive is the first host, not the only one.

The package answers one question — how two devices on the same network find
each other, trust each other, and exchange generic data and files safely and
reliably. It never decides *what* a host syncs:

- The host registers `LanSyncDataAdapter`s for the scopes it wants synced.
- The host provides a `LanSyncStore` for sync metadata (trust, outbox,
  cursors, idempotency, tasks) and a `SecureCredentialStore` for secrets.
- The host configures discovery, security and transfer parameters through
  `LanSyncConfig`, and provides the device's `TlsIdentity`.

Implementation status follows `docs/live-lan-sync-spec.md` (development
baseline); see `CHANGELOG.md` for what each phase delivered.

## Sync design

Each device keeps one change log in its `LanSyncStore`: the latest change
per entity, ordered by a sequence that only grows. Local edits enter it
through `SyncEngine.recordLocalChange`, right after the business write;
changes applied from a peer are appended too, so a third device can follow
them through this one.

Peers follow each other's logs with a cursor per (peer, scope): how far
this device has applied the peer's log (pulls resume there) and how far the
peer has confirmed this device's log (pushes resume there). Every received
batch is deduplicated by operation id, compared by version vector — newer
is applied, older is skipped, concurrent is kept as a conflict — and
committed together with its cursor in one atomic store call. Repeating a
sync applies nothing twice; an interrupted one resumes from its last
committed batch.

Concurrent edits are never silently overwritten. When both devices arrived
at the same content, the versions are simply joined. Otherwise the conflict
is recorded and reported, then settled by the scope's policy or by the
user; the decision is written as a new version that follows both sides, so
every device adopts it instead of conflicting again.

## File transfer

Files move in chunks over the same pinned, signed channel as the data
changes. The sender hashes the file in one streaming pass — whole file and
every chunk — and the receiver checks each chunk against its hash as it
lands, each in its own staging file written through a temporary name and a
rename, so anything on disk is complete. An interrupted transfer resumes
with exactly the missing chunks, even after an app restart. When every
chunk is there, the file is assembled, the whole-file hash is checked, the
host's file adapter validates the content, and only then is the file moved
into place atomically. Paths are always the receiver's own decision.

## Logging

The engine logs through the host's `live_log` tree, never its own: hand a
view (`appLog.forCategory('lan_sync')`) to `LanSyncLogger` and pass it to
the components you compose. Records are categorised per subsystem
(`lan_sync.sync`, `.transfer`, `.pairing`, `.discovery`, `.transport`) and
per subject beneath that, sanitised by live_log at emit time, and held to
the spec's rules: codes and devices, not payloads, secrets or paths.
Components given no logger stay completely silent.

## Security design

Only reviewed primitives are used, assembled the way published protocols
assemble them (spec §9.3: no home-grown handshake).

**Channel.** TLS is mandatory. Each device serves with a long-lived
self-signed certificate (`TlsIdentity`); its SHA-256 fingerprint is the
device's identity. Clients trust no certificate authority at all and accept
exactly the fingerprint pinned at pairing, before a byte of the request is
sent.

**Pairing** follows Bluetooth Secure Simple Pairing's *numeric comparison*,
with SHA-256/HMAC-SHA256 in place of AES-CMAC:

1. The responder's user opens a pairing window. The initiator sends its
   facts (device id, name, an ephemeral X25519 public key, its certificate
   fingerprint); the responder answers with its own facts and a commitment
   to its nonce over the transcript.
2. The initiator sends its nonce; the responder reveals its own; the
   initiator checks the commitment.
3. Both devices show a six-digit code computed over the whole transcript and
   both nonces. The users compare and confirm on both devices. A man in the
   middle must fix its keys and nonce on each leg before learning the honest
   nonce there, so the two codes match only by chance (one in a million per
   attempt, and attempts are rate-limited).
4. The pairing secret is HKDF-SHA256 over the X25519 shared secret, salted
   with the transcript and nonces. It never travels; each side proves it
   holds the same secret with a role-bound HMAC key confirmation, and stores
   it in its `SecureCredentialStore` under the other device's id.

Pairing grants nothing by default: each user chooses which scopes and file
directions the other device gets.

**Requests.** Inside the pinned channel every request is signed with
HMAC-SHA256 over method, path, timestamp, a single-use nonce and the body's
SHA-256, keyed with the pairing secret. Timestamps bound the replay window
and a per-sender nonce registry closes it. Revoking a device wipes its
secret, so every request it signs afterwards fails.

**Test material.** `test/fixtures/tls/` holds two throwaway self-signed EC
P-256 certificates generated with OpenSSL for the integration tests; they
protect nothing.
