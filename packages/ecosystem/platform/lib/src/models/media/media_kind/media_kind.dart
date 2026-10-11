// Module: lib/src/models/media/media_kind/media_kind.dart
// Purpose: MediaKind, split out of the file that bundled it (see package-architecture.md
// §2.1): one public type per file, and the file in a folder of its own so anything generated for
// it lands beside it.
// Author: liuchuancong
// Created: 2026-10-11

/// What the resource semantically is. Kept separate from [MediaProtocol], which is how it is transported
/// (docs/contracts/platform-models.md section 11 forbids merging the two).
enum MediaKind { live, vod, music, file }
