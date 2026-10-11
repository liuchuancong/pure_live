// Module: lib/src/models/live/live_audience_metric/live_audience_metric.dart
// Purpose: Which number a platform's audience figure actually is.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/platform-models.md §11 (a source's unit is its own). The reference product carries the
// same distinction, because the platforms do not mean one thing by "the number": huya's `totalCount` and
// acfun's `onlineCount` are concurrent viewers, douyu's `room_biz_all.hot` and kugou's `hot` are heat scores,
// and some sites report total visits since the broadcast began.
//
// Folding all of them into one field is what lets a room page print "9.8万人" for a ranking number nobody counted.

/// What a reported audience figure measures.
enum LiveAudienceMetric {
  /// Viewers watching right now: huya `totalCount`, acfun `onlineCount`, douyu `room_online`.
  onlineViewers,

  /// Total visits since the broadcast began. It grows monotonically and is not a headcount of who is watching.
  totalViewers,

  /// A computed heat score (douyu `hot`, kugou `hot`) - a ranking number, not people.
  popularity,

  /// The site showed a figure and never said which of the above it is. Reported as itself: a surface then keeps
  /// the platform's wording instead of guessing.
  unknown,
}
