// Module: lib/src/models/media/stream_option_kind/stream_option_kind.dart
// Purpose: Which axis a listed stream choice belongs to.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/capability-contract.md section 1 names these two menus separately (`quality`, `line`),
// and docs/sources/live/source-contract.md keeps them separate for the same reason as `resolve`: a quality is
// "what the stream looks like", a line is "which server gives it", and the viewer's complaint is always about
// one of the two.

/// The axis a [StreamOption] sits on.
enum StreamOptionKind {
  /// Bitrate / resolution, e.g. 1080p, 源, flac24bit.
  quality,

  /// A delivery path carrying the same content, e.g. one of huya's CDN entries.
  line,
}
