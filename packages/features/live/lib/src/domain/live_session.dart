// Module: lib/src/domain/live_session.dart
// Purpose: The committed line and quality of one live room, with switches that only land if they won the race.
// Author: liuchuancong
// Created: 2026-10-10
//
// Spec: docs/sources/live/source-contract.md gives LiveCapability `resolve(room, {quality, line})` and the
// degrade-on-failure rule for multiple lines. What it leaves to this layer is when a *user* switch becomes
// the session's selection: the answer is "when the player opened that stream", because until then the switch
// is a request that may still fail, and a failed switch must keep both the old stream and the old selection.
//
// Two defects in the version this replaces both came from treating a switch as a flag rather than an
// attempt. One `pending` slot meant a second switch overwrote the first, and `commitSwitch()` then committed
// whatever happened to be pending - so the late "opened successfully" callback of the line the user had
// already abandoned rewrote the selection to a stream nobody was playing. And a switch could name a variant
// the source never offered.
//
// So a switch is an attempt keyed by axis, carrying an identity that committing requires, and the two axes
// are separate values: a source legitimately serves "line 3 at 1080p", which one `active` field cannot hold.

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

/// The two axes a live source can vary on.
enum StreamVariantKind { quality, line }

/// One selectable variant inside a source's own vocabulary.
final class StreamVariant with ValueEquality {
  const StreamVariant({required this.id, required this.label, required this.kind, this.isDefault = false});

  /// The id the source expects back in `resolve`; unique within its [kind], not across kinds.
  final String id;

  /// The label the source showed, e.g. `原画` or `线路2`.
  final String label;

  final StreamVariantKind kind;

  /// The variant the source chose for this axis, used when the user has said nothing about it.
  final bool isDefault;

  bool get isLine => kind == StreamVariantKind.line;

  @override
  List<Object?> get equalityFields => <Object?>[kind, id];

  @override
  String toString() => 'StreamVariant(${kind.name}: $id "$label")';
}

/// The committed selection, one value per axis.
final class LiveSelection with ValueEquality {
  const LiveSelection({this.quality, this.line});

  final StreamVariant? quality;
  final StreamVariant? line;

  StreamVariant? of(StreamVariantKind kind) => switch (kind) {
    StreamVariantKind.quality => quality,
    StreamVariantKind.line => line,
  };

  LiveSelection withVariant(StreamVariant variant) => switch (variant.kind) {
    StreamVariantKind.quality => LiveSelection(quality: variant, line: line),
    StreamVariantKind.line => LiveSelection(quality: quality, line: variant),
  };

  @override
  List<Object?> get equalityFields => <Object?>[quality, line];
}

/// A switch the player was told to perform and has not reported back on.
final class SwitchAttempt {
  const SwitchAttempt({required this.id, required this.target});

  /// Unique per session lifetime; two attempts never share one, which is what makes a late callback safe to
  /// recognise as late.
  final int id;
  final StreamVariant target;

  StreamVariantKind get kind => target.kind;

  @override
  String toString() => 'SwitchAttempt#$id(${target.kind.name}:${target.id})';
}

/// Why a switch could not be requested, or could not be committed.
final class SwitchFailure extends DomainFailure {
  const SwitchFailure(super.reason, {super.cause});
}

/// What asking for a switch produced.
sealed class SwitchRequest {
  const SwitchRequest();
}

/// The player must open [attempt]'s stream, and only that attempt may commit it.
final class SwitchAccepted extends SwitchRequest {
  const SwitchAccepted(this.attempt);

  final SwitchAttempt attempt;
}

/// Nothing to do, because that variant is already the committed one.
///
/// A case of its own rather than a failure: a remote's repeat event landing on the current line is normal,
/// and showing it as an error would teach the user that the button is broken.
final class SwitchNoop extends SwitchRequest {
  const SwitchNoop(this.reason);

  final String reason;
}

/// The switch was refused, with the reason named.
final class SwitchRefused extends SwitchRequest {
  const SwitchRefused(this.failure);

  final SwitchFailure failure;
}

/// The state of one live room's stream selection.
///
/// Immutable: every transition returns the state that follows. The version this replaces exposed `active`,
/// `pending`, `currentTicket` and a mutable `variants` list as public fields, so "commit only after the
/// player opened it" could be bypassed by any caller assigning directly - and a rule anyone can skip is not
/// a rule.
final class LiveSession {
  LiveSession({
    required this.roomRef,
    required this.ticket,
    this.variants = const <StreamVariant>[],
    this.selection = const LiveSelection(),
    Map<StreamVariantKind, SwitchAttempt> pending = const <StreamVariantKind, SwitchAttempt>{},
    int nextAttemptId = 1,
  }) : _pending = Map<StreamVariantKind, SwitchAttempt>.of(pending),
       _nextAttemptId = nextAttemptId;

  /// The state a fresh `resolve` answer leaves behind: a ticket, and the source's own defaults committed.
  factory LiveSession.opened({
    required ContentRef roomRef,
    required MediaTicket ticket,
    Iterable<StreamVariant> variants = const <StreamVariant>[],
  }) {
    final table = List<StreamVariant>.unmodifiable(variants);
    return LiveSession(
      roomRef: roomRef,
      ticket: ticket,
      variants: table,
      selection: LiveSelection(
        quality: _defaultFor(table, StreamVariantKind.quality),
        line: _defaultFor(table, StreamVariantKind.line),
      ),
    );
  }

  final ContentRef roomRef;
  final MediaTicket ticket;

  /// What the source offered for this ticket, in source order.
  final List<StreamVariant> variants;

  final LiveSelection selection;

  final Map<StreamVariantKind, SwitchAttempt> _pending;

  int _nextAttemptId;

  /// True while any axis is waiting on the player.
  bool get hasPendingSwitch => _pending.isNotEmpty;

  /// The attempt in flight for one axis, or null.
  SwitchAttempt? pending(StreamVariantKind kind) => _pending[kind];

  /// The variants offered for one axis, in source order.
  List<StreamVariant> offered(StreamVariantKind kind) =>
      variants.where((variant) => variant.kind == kind).toList(growable: false);

  /// Replaces the offered table with what the source says exists now.
  ///
  /// A committed selection or an in-flight attempt whose variant vanished is released: keeping it would let
  /// the UI highlight a line that cannot be resolved.
  LiveSession withVariants(Iterable<StreamVariant> offered) {
    final table = List<StreamVariant>.unmodifiable(offered);
    final pending = <StreamVariantKind, SwitchAttempt>{
      for (final attempt in _pending.values)
        if (_find(table, attempt.target) != null) attempt.kind: attempt,
    };
    return LiveSession(
      roomRef: roomRef,
      ticket: ticket,
      variants: table,
      selection: LiveSelection(quality: _find(table, selection.quality), line: _find(table, selection.line)),
      pending: pending,
      nextAttemptId: _nextAttemptId,
    );
  }

  /// The state after the player was told to open [variant]'s stream.
  ///
  /// Refused when the source never offered that variant or nothing is playing; a no-op when it is already
  /// committed.
  (LiveSession, SwitchRequest) requestSwitch(StreamVariant variant) {
    if (ticket.uri.toString().isEmpty) {
      return (
        this,
        SwitchRefused(SwitchFailure('no stream is playing in ${roomRef.contentId}, so there is nothing to switch')),
      );
    }
    if (_find(variants, variant) == null) {
      return (
        this,
        SwitchRefused(SwitchFailure('the source does not offer ${variant.kind.name} "${variant.id}" for this ticket')),
      );
    }
    if (selection.of(variant.kind)?.id == variant.id) {
      return (this, SwitchNoop('${variant.kind.name} "${variant.label}" is already selected'));
    }

    final attempt = SwitchAttempt(id: _nextAttemptId++, target: variant);
    // Superseding is per axis: the abandoned quality attempt cannot commit later, while an in-flight line
    // switch is untouched, because the two are different questions about the same stream.
    final pending = Map<StreamVariantKind, SwitchAttempt>.of(_pending)..[variant.kind] = attempt;
    return (
      LiveSession(
        roomRef: roomRef,
        ticket: ticket,
        variants: variants,
        selection: selection,
        pending: pending,
        nextAttemptId: _nextAttemptId,
      ),
      SwitchAccepted(attempt),
    );
  }

  /// The state after the player reported that [attempt]'s stream opened.
  ///
  /// Throws for an attempt that is not the one in flight: a stale "opened" callback - superseded, or from a
  /// ticket that has since been replaced - must not move the selection.
  LiveSession commitSwitch(SwitchAttempt attempt) {
    final inFlight = _pending[attempt.kind];
    if (inFlight == null || inFlight.id != attempt.id) {
      throw SwitchFailure(
        'switch attempt #${attempt.id} is no longer pending'
        '${inFlight == null ? '' : ' (superseded by #${inFlight.id})'}, so its result cannot be committed',
      );
    }
    final pending = Map<StreamVariantKind, SwitchAttempt>.of(_pending)..remove(attempt.kind);
    return LiveSession(
      roomRef: roomRef,
      ticket: ticket,
      variants: variants,
      selection: selection.withVariant(attempt.target),
      pending: pending,
      nextAttemptId: _nextAttemptId,
    );
  }

  /// The state after the player reported that [attempt] failed. The committed selection does not move, and
  /// neither does an attempt that has already been superseded - its outcome no longer describes anything.
  LiveSession abandonSwitch(SwitchAttempt attempt) {
    final inFlight = _pending[attempt.kind];
    if (inFlight == null || inFlight.id != attempt.id) {
      return this;
    }
    final pending = Map<StreamVariantKind, SwitchAttempt>.of(_pending)..remove(attempt.kind);
    return LiveSession(
      roomRef: roomRef,
      ticket: ticket,
      variants: variants,
      selection: selection,
      pending: pending,
      nextAttemptId: _nextAttemptId,
    );
  }

  /// The state for a freshly resolved ticket in the same room. Selections survive a refresh; in-flight
  /// switches do not, because the new stream is what it is and an old callback belongs to an old url.
  LiveSession withTicket(MediaTicket ticket, {Iterable<StreamVariant>? variants}) {
    final table = List<StreamVariant>.unmodifiable(variants ?? this.variants);
    return LiveSession(
      roomRef: roomRef,
      ticket: ticket,
      variants: table,
      selection: LiveSelection(quality: _find(table, selection.quality), line: _find(table, selection.line)),
      nextAttemptId: _nextAttemptId,
    );
  }

  static StreamVariant? _find(List<StreamVariant> table, StreamVariant? variant) {
    if (variant == null) {
      return null;
    }
    return table.where((candidate) => candidate.kind == variant.kind && candidate.id == variant.id).head;
  }

  static StreamVariant? _defaultFor(List<StreamVariant> table, StreamVariantKind kind) =>
      table.where((variant) => variant.kind == kind && variant.isDefault).head;
}
