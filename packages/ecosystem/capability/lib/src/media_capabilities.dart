// Module: lib/src/media_capabilities.dart
// Purpose: The capability interfaces around a stream: menus, live status, danmaku, lyrics and engagement.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/capability-contract.md section 1 names 21 capability kinds; until this file, only four had
// a method set (Browse / Search / Resolve / Feed), which is why no provider could be a *complete* package - the
// ceiling on what it could express was four methods. The interfaces here close the part of that gap that real
// platforms demonstrably need, and nothing more: every one of them is grounded in at least two sources whose
// shapes differ (the ledger's warning against inventing a `QualityLine` from one platform's dialect is why
// `StreamOption`'s physical fields are optional rather than a bitrate-everywhere model).
//
// Rules that hold for the whole file, and that a contract test can pin:
// - an unimplemented capability is **not implemented**, not implemented-and-empty: a source that has no anchor
//   search does not implement `AnchorSearchCapability`, and the discovery layer then does not offer the tab.
//   `BrowseCapability.categories()` returning an empty list is allowed because "no category table" is a real
//   shape; a stub `Future.value([])` behind an interface the source cannot serve is not.
// - a list method must not fabricate. No qualities known means an empty `StreamOptions`, and the surface then
//   offers only the source's own default rather than a menu of guesses.
// - everything here takes the same `ContentRef` vocabulary as the four originals, so a resolver, a danmaku
//   client and a lyric panel are all keyed by the same identity.

import 'dart:async';

import 'package:pure_live_platform/pure_live_platform.dart';

/// A source that can say which **qualities** a stream comes in.
abstract interface class QualityCapability {
  /// The quality menu for [ref], in the source's own order. Empty means the source serves one stream and says
  /// nothing about it - the bilibili guest path - and the surface must then hide the picker rather than grey out
  /// a list of one.
  Future<List<StreamOption>> qualities(ContentRef ref);
}

/// A source that can say which delivery **lines** (CDNs) a stream is available on.
abstract interface class LineCapability {
  /// The lines for [ref], in the source's own priority order. The first entry is what a resolve with no line
  /// selection gets, which is why the order is the source's and not the platform's.
  Future<List<StreamOption>> lines(ContentRef ref);
}

/// A source that can describe one of its rooms fully.
///
/// This is the live domain's own return shape: [LiveRoom] carries the anchor, the 分区, the audience figure, the
/// paywall flag and the start time **as fields**. A live source that can only hand back a [ContentSummary] with
/// those facts under `metadata.extra` string keys is the thing this interface exists to stop - every site then
/// invents its own spelling and every consumer re-guesses it.
abstract interface class LiveRoomCapability {
  /// The room in full. A source that has to make one request for this and a cheaper one for [liveStatus] should
  /// say so in its README: the two are deliberately separate because the poll is the hot path.
  Future<LiveRoom> room(ContentRef ref);
}

/// A source that can answer whether a room is on air right now, cheaply enough to poll.
abstract interface class LiveStatusCapability {
  /// The current state of [ref]. [LiveRoomState.unknown] on a failed poll: a follow list that reads unknown as
  /// ended stops watching a live stream in silence.
  Future<LiveRoomStatus> liveStatus(ContentRef ref);
}

/// A source whose rooms carry bullet comments.
abstract interface class DanmakuCapability {
  /// The message stream for one room. The returned subscription owns its transport: closing the stream or
  /// disposing of the room must stop the socket, because a leaked danmaku connection keeps billing a room the
  /// viewer left.
  ///
  /// [replay] asks for the recorded buffer where the platform has one (bilibili's history fetch) instead of
  /// only live messages from now on.
  Stream<DanmakuMessage> danmaku(ContentRef ref, {bool replay = false});
}

/// A source that accepts a bullet comment from the viewer. Separate from [DanmakuCapability] because reading
/// danmaku and writing it have different rights: reading is anonymous on most platforms, writing requires an
/// account and a room-level ban check, and a plugin that can only watch must not be able to post.
abstract interface class DanmakuSendCapability {
  /// Posts [text] to [ref]. A source that needs an account the host has not granted signals it with the failure
  /// shape of its own layer carrying `PlatformErrorCodes.authRequired` - the code is the contract, the exception
  /// class is the provider's (this package deliberately has no exception type to force). The text a viewer typed
  /// must never be echoed back into the failure message.
  Future<void> sendDanmaku(ContentRef ref, String text);
}

/// A source you can search for **people** as well as content.
abstract interface class AnchorSearchCapability {
  /// Anchor results for [query.keyword]. Rooms and anchors are separate queries on every platform that has both
  /// (douyu, huya, bilibili), because the endpoint, the paging and the result shape differ - a combined search
  /// would return rooms in the anchor tab.
  Future<PageResult<AnchorSummary>> searchAnchors(SearchQuery query);
}

/// A source that serves comments for an item.
abstract interface class CommentCapability {
  /// One page of top-level comments. Replies are a second call ([repliesTo]), never a flattening of this one:
  /// a list that mixed them would let a two-level thread look like a hundred top-level rows.
  Future<PageResult<ContentComment>> comments(ContentRef ref, PageRequest page);

  /// The replies under one comment, for a thread the viewer opened.
  Future<PageResult<ContentComment>> replies(ContentRef ref, String commentId, PageRequest page);
}

/// A source that serves lyric text.
abstract interface class LyricCapability {
  /// The lyric for [ref]. A source with no lyric returns a document whose [LyricDocument.isEmpty] is true; a
  /// failure is a throw, because "no lyric" and "lyric lookup failed" render differently.
  Future<LyricDocument> lyrics(ContentRef ref);
}

/// A source that serves subtitle tracks.
abstract interface class SubtitleCapability {
  /// Empty when there are none, which is the common case and not an error.
  Future<List<SubtitleTrack>> subtitles(ContentRef ref);
}

/// A source that marks chapters inside an item.
abstract interface class ChapterCapability {
  /// Chapters in [ContentChapter.at] order; a source that reports them unsorted is corrected here rather than
  /// trusting the wire, because a seek bar built from unsorted marks is unusable, not merely ugly.
  Future<List<ContentChapter>> chapters(ContentRef ref);
}

/// A source that can suggest more of what you are looking at.
abstract interface class RelatedCapability {
  /// Related items for [ref] - "up next" for a stream, "相关视频" for a VOD. Paging exists because the platforms
  /// page it; a surface that only wants a strip takes the first page.
  Future<PageResult<ContentSummary>> related(ContentRef ref, PageRequest page);
}

/// What a source knows about the account the host gave it.
abstract interface class AccountCapability {
  /// The signed-in identity, or null for anonymous. Separate from login *flow* (which is a UI wave and needs a
  /// consent surface this layer cannot see) - this is the read half every feature needs: follow lists and
  /// history belong to an account, and "whose" has an answer or the feature must say it is offline.
  Future<AnchorSummary?> account();
}
