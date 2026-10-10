# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Fixed**:`_parsePublicKey`'s SPKI branch descended into the AlgorithmIdentifier's own contents and read the
  object identifier as if it were the key, so a genuine `BEGIN PUBLIC KEY` failed - the comment claimed both PEM
  forms were supported and only PKCS#1 actually worked. The walk now skips the identifier by reading past it in
  the outer reader, expects a BIT STRING, drops its unused-bits byte and enters the PKCS#1 sequence.
- **Fixed**: every DER read was unguarded index arithmetic, so a truncated or forged key string - which arrives
  from a **user-imported script** - escaped as a bare `RangeError` naming neither the key nor the offset. Bad
  input is now a `FormatException` that says where it stopped.
- **Fixed**:`aes-<bits>-<mode>` ignored the bits in its own name. Asking for `aes-128-cbc` with a 32-byte key
  produced AES-256 output, while Node - reading the same request as 128-bit - would never reproduce it. The key
  length has to match the mode name now.
- `crypto.randomBytes` refuses a request over `kMaxRandomBytes` (64 KiB) instead of silently clamping it. Half
  the random material a script asked for is not a smaller answer; it is a wrong one that surfaces far away.
- The announcement a script makes with `lx.send('inited')` is now enforced: `musicUrl` / `lyric` / `pic` refuse a
  source that never listed that action (or that quality), naming what it did announce. `MusicSourceInfo.serves`
  existed for this and nothing called it, so an unannounced action went into the script, where it either never
  answered or failed in script space with a message about an unknown action.
- `awaitInited` disposes the host when the deadline passes. A script that never announced left its JS context,
  timers and registrations alive with no handle left to the caller, and a settings page lets a user import
  sources one after another.
- `musicUrl` rejects an answer that is not a url (`no scheme://`), so a script's "not found" word cannot reach
  the player as a stream; a whitespace-only lyric reads as no lyric.
- `MusicSourceInfo` tolerates `actions` / `qualitys` arriving as a list, a single value or absent; throwing while
  parsing the announcement used to cost the entire source over one field's shape.
- `attach`'s doc comment contradicted itself about when attaching is valid; it now states the condition (the
  loading host must have evaluated this package's prelude) and why.
- README and CHANGELOG replaced the scaffold text: 模块表, the announcement/quality contract, the crypto rules,
  the platform matrix (`dart:io` zlib means no web), and what was actually executed versus inferred.
- Earlier: skeleton created for layer providers as `pure_live_music`, then the lx host, prelude and crypto bridge.

