// Module: lib/src/models/live/danmaku_kind/danmaku_kind.dart
// Purpose: What kind of message a live-room row is.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/capability-contract.md section 1 (`DanmakuCapability`). The distinction drives the
// overlay: a gift is a banner that expires, a chat line scrolls, an entry notice must not linger as though
// someone spoke it. Existence evidence is in docs/sources/live/*.md (bilibili's msgtypes, huya's bullet types).

/// The kind of one live-room message.
enum DanmakuKind {
  /// Something a viewer said.
  text,

  /// A paid item sent to the anchor.
  gift,

  /// A highlighted paid message (bilibili 醒目留言 and equivalents).
  superChat,

  /// A viewer entered the room. Transient by nature: a surface that keeps these on screen buries the chat.
  entry,

  /// A membership/guard announcement.
  guard,

  /// Platform notice that is not any of the above. Anything the source carries that this list cannot say goes
  /// into `DanmakuMessage.extra` rather than forcing a new value into the public contract.
  system,
}
