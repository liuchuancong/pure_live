// Module: lib/src/ticket_swap.dart
// Purpose: Do the ticket replacement the watchdog asks for: get the new row, reopen it, land where the user was.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/media/media-ticket.md section 4 (换链要保住会话与进度) and docs/adr/0020-media-core-owns-recovery.md:
// the kernel decides *when* to recover, and this is the piece that physically swaps the source when the platform
// side has to fetch a new ticket to make that happen.
//
// The replacement arrives as a callback rather than as a resolver: resolving lives at L1 (pure_live_resolver)
// and this package is L0.5, so pointing the dependency the other way would be an upward edge. The composition
// root wires CapabilityTicketRefresher in here.

import 'package:media_core/media_core.dart' as core;
import 'package:pure_live_platform/pure_live_platform.dart' as platform;

import 'ticket_source.dart';

/// Produces the replacement ticket for the one this swapper holds.
typedef TicketReplacement = Future<platform.MediaTicket> Function(platform.RefreshReason reason);

/// Replaces the ticket a handle is playing, keeping position and the user's play/pause choice.
///
/// What it guarantees is the order - fetch, reopen, seek back, resume - and that a failed fetch opens
/// nothing. It does not claim an seamless seam: reopening a source is audible on some engines, and
/// `MediaTicketPolicy.seamlessRefresh` has no counterpart in the kernel to ask for a gapless handover.
final class TicketSwapper {
  TicketSwapper({required core.PlayerHandle handle, required TicketReplacement replace, platform.MediaTicket? ticket})
    : _handle = handle,
      _replace = replace,
      _current = ticket;

  final core.PlayerHandle _handle;
  final TicketReplacement _replace;

  platform.MediaTicket? _current;
  Future<platform.MediaTicket>? _inFlight;

  /// The row the handle is on right now, which is what the watchdog must judge expiry against after a swap.
  platform.MediaTicket? get currentTicket => _current;

  /// True while a replacement is being fetched or opened. The watchdog keeps its own guard; this one exists
  /// because a user-triggered refresh and a prefetch can otherwise race each other into two opens.
  bool get isSwapping => _inFlight != null;

  /// Runs one swap, or joins the one already running.
  ///
  /// Coalescing rather than queueing: a second caller wants the same new ticket, and a queued second swap
  /// would immediately replace the row the first one just installed.
  Future<platform.MediaTicket> swap(platform.RefreshReason reason) {
    final running = _inFlight;
    if (running != null) {
      return running;
    }
    final started = _perform(reason);
    _inFlight = started;
    return started.whenComplete(() => _inFlight = null);
  }

  Future<platform.MediaTicket> _perform(platform.RefreshReason reason) async {
    final position = _handle.position;
    final wasPlaying = _handle.isPlaying;

    // Fetching first is the whole ordering: until the new row exists, the handle keeps playing the old one,
    // so a refresh that fails costs nothing the viewer can see.
    final ticket = await _replace(reason);

    await _handle.openMedia(toCoreSource(ticket), autoPlay: false);

    // A live edge sits at zero, and seeking a live stream back to zero rewinds it or stalls it; the
    // reposition is for the viewer who was mid-programme, not for a stream that has no position concept.
    if (position > Duration.zero) {
      await _handle.seek(position);
    }
    if (wasPlaying) {
      await _handle.play();
    }

    _current = ticket;
    return ticket;
  }
}
