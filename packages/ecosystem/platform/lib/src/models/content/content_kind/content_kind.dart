// Module: lib/src/lib/src/models/content/content_kind/content_kind.dart
// Purpose: What kind of content a reference points at.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/platform-models.md. Split out of the file that bundled it: one public
// type per file, and the file lives in a folder of its own (§2.1) so a model and anything generated
// for it are found in one place.

enum ContentKind {
  liveChannel,
  liveRoom,

  /// 主播本人 - the person, not their room. `AnchorSearchCapability` returns these and a follow list stores
  /// them, so a ref that pointed at [liveRoom] instead would open whoever is streaming right now rather than
  /// the account the viewer chose.
  anchor,
  vod,
  movie,
  series,
  episode,
  music,
  album,
  artist,
  playlist,
  stream,
  epgProgram,
  localMedia,
}

/// Extra descriptive fields. Only fields that are stable and widely consumed belong here.
