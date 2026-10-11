// Module: lib/src/models/media/media_ticket.dart
// Purpose: MediaTicketRefreshInfo, split out of the file that bundled it (see package-architecture.md
// §2.1): one public type per file, and the file in a folder of its own so anything generated for
// it lands beside it.
// Author: liuchuancong
// Created: 2026-10-11

import '../../../support/json.dart';
import '../../content/content_ref/content_ref.dart';

final class MediaTicketRefreshInfo {
  const MediaTicketRefreshInfo({
    this.supported = true,
    this.expiresAt,
    this.refreshBefore,
    this.cutsConnection = false,
  });

  factory MediaTicketRefreshInfo.fromJson(Map<String, Object?> json) => MediaTicketRefreshInfo(
    supported: json['supported'] as bool? ?? true,
    expiresAt: parseUtc(json['expiresAt']),
    refreshBefore: parseDurationMs(json['refreshBeforeMs']),
    cutsConnection: json['cutsConnection'] as bool? ?? false,
  );

  /// Whether this resource can be re-fetched at all. A one-shot signed url sets this false, and asking for a
  /// replacement early would then produce a second url that nothing uses.
  final bool supported;

  /// The source's own expiry statement, which can differ from the ticket's when a protocol reports it in a
  /// second place; the ticket field stays authoritative for the deadline.
  final DateTime? expiresAt;

  /// How long before expiry a replacement should be requested (docs/media/media-contract.md section 2's
  /// `refreshBefore`, the "T-45s" in docs/media/media-ticket.md section 3).
  final Duration? refreshBefore;

  /// Whether the old stream also **dies** when its lease ends, so the replacement has to be spliced in rather
  /// than merely prefetched. Douyu's signed FLV does this; huya's does not - and a player that prefetches but
  /// never reconnects on the first is the "画面停了声音还在" report.
  ///
  /// This is the one thing a source knows about its own URLs that the platform cannot observe from the wire, so
  /// it has to be declared. Absent means the safer-for-bandwidth reading: prefetch is enough.
  final bool cutsConnection;

  /// When a replacement should be asked for, or null when there is nothing to schedule.
  ///
  /// Null comes from two different reasons and the caller should not have to re-derive them: [supported]
  /// false means a replacement does not exist (a one-shot signed url), and no deadline means the protocol
  /// never said when this one dies. [defaultLead] is the platform's fallback for a source that gives advice
  /// about expiry but not about timing, which is most of them.
  DateTime? nextRefreshAt({required DateTime? ticketExpiry, required Duration defaultLead}) {
    if (!supported) {
      return null;
    }
    final deadline = ticketExpiry ?? expiresAt;
    if (deadline == null) {
      return null;
    }
    final lead = refreshBefore ?? defaultLead;
    // A source that advises a negative or zero lead means "replace it as soon as you can", which is the
    // deadline itself rather than a moment before it; refusing to schedule would be the worse reading.
    if (lead.isNegative || lead == Duration.zero) {
      return deadline;
    }
    return deadline.subtract(lead);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    if (!supported) 'supported': false,
    if (expiresAt != null) 'expiresAt': formatUtc(expiresAt),
    if (refreshBefore != null) 'refreshBeforeMs': durationMs(refreshBefore),
    if (cutsConnection) 'cutsConnection': true,
  };

  @override
  String toString() => 'MediaTicketRefreshInfo(supported: $supported, lead: ${refreshBefore?.inSeconds}s)';
}

/// Descriptive fields for a UI or a media session. No playback state.
