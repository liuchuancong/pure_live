// Module: lib/src/models/live/live_restriction/live_restriction.dart
// Purpose: Why a room that is on air still cannot be opened.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/platform-models.md §11. This replaces the boolean I first put on LiveRoom
// (`requiresAuth`): 付费场、仅粉丝/本人可见、只有 App 能看、站点自己关了播放 are four different screens with four
// different ways out, and one `true` collapsed all four into a message that helps nobody.
//
// The code tables that produce these values belong to the sites (weibo's `watch_limit` 8/10/11/12, acfun's
// `paidShowUuid`, douyu's `show_status`, kugou's media status), and each site's reader maps its own codes here
// explicitly - never inferred from an empty CDN list.

/// What stands between an anonymous viewer and a room that is broadcasting.
enum LiveRestriction {
  /// Nothing: the anonymous path may open it.
  none,

  /// Paid, and the viewer has not bought it.
  paid,

  /// Restricted to a group the viewer might belong to but our session cannot prove (好友可见、粉丝团、本人).
  private,

  /// The site serves it only inside its own app; the web path can describe the room and not play it.
  appOnly,

  /// The room says it will not play (playback switched off, or no address we are allowed to open) while still
  /// describing itself as a broadcast.
  unplayable,

  /// The site said it is gated and did not say how. Reported as such instead of rounded to [paid].
  unknown,
}
