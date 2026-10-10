// Module: lib/src/domain/live_session.dart
// Purpose: The live-room session model: which line and quality are active,
// and the rule that a switch commits only after the new stream opens.
// Author: liuchuancong
// Created: 2026-10-10
//
// Spec: docs/sources/live/source-contract.md - quality and line switching
// commit at the moment the player actually opens the new source; a failed
// switch keeps the old source and the old selection. This model encodes that
// rule so every caller gets it the same way.

import 'package:pure_live_platform/pure_live_platform.dart';

/// One selectable stream variant inside a source's own vocabulary.
final class StreamVariant {
  const StreamVariant({required this.id, required this.label, this.kind = StreamVariantKind.quality});

  final String id;
  final String label;
  final StreamVariantKind kind;

  bool get isLine => kind == StreamVariantKind.line;
}

/// The two axes a live source can vary on.
enum StreamVariantKind { quality, line }

/// The committed state of a live session plus a pending switch.
final class LiveSession {
  LiveSession({required this.roomRef, required this.currentTicket});

  final ContentRef roomRef;
  MediaTicket currentTicket;

  /// The variant labels the current ticket serves, in source order.
  final List<StreamVariant> variants = <StreamVariant>[];

  /// The variant currently committed. Null when the source did not name its
  /// variants.
  StreamVariant? active;

  /// A switch that was requested but not yet committed. Null when the session
  /// is stable.
  StreamVariant? pending;

  bool get hasPendingSwitch => pending != null;

  /// Announces the variants a resolve answer carries. Variants replace the
  /// previous table wholesale: the source said what exists now.
  void offerVariants(Iterable<StreamVariant> offered) {
    variants
      ..clear()
      ..addAll(offered);
    if (active != null && !variants.any((variant) => variant.id == active!.id)) {
      active = null;
    }
  }

  /// Marks [variant] as requested. Returns false when the session has no
  /// ticket yet - a switch without a playing session is not a switch.
  bool requestSwitch(StreamVariant variant) {
    if (currentTicket.uri.toString().isEmpty) {
      return false;
    }
    pending = variant;
    return true;
  }

  /// Commits the pending switch: the player opened the new stream, so the
  /// selection becomes the active one and the pending marker clears.
  void commitSwitch() {
    final requested = pending;
    if (requested == null) {
      return;
    }
    pending = null;
    active = requested;
  }

  /// Rolls the pending switch back: the player kept the old stream, so the
  /// selection returns to the committed one.
  void rollbackSwitch() {
    pending = null;
  }
}
