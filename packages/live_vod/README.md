# live_vod

Video-on-demand sources for Pure Live — the ids, search hits and play
addresses of a platform's videos, independent of any player.

## Purpose

A VOD platform answers three questions and the app should never parse any of
them inline: *what can I watch* (the play queue: episodes, parts, their
titles and ordering), *which one is this* (a video id and the metadata a
card shows), and *where do I play it from* (the resolved addresses per
quality, whose URLs expire and must be re-resolved rather than cached). This
package owns those answers for the platforms it carries, behind one model
set.

## Responsibilities

- `vod_models.dart` — the unified VOD model set: search hits, video
  metadata, play queues (episodes/parts) and play answers. One shape, so the
  UI renders any platform the same way.
- `play_queue.dart` — queue semantics: episode ordering, "next" and
  "resume" decisions that the player page should not re-derive.
- `bilibili_vod_client.dart` + `bilibili_wbi.dart` — the Bilibili VOD
  adapter: search, video metadata and play-address resolution, including the
  WBI signature the web API requires before it answers at all.
- `lyric_lookup.dart` + `lyric_query.dart` — lyric lookup for the music
  side: query by title/artist, tolerant matching, and the model the player
  overlays.

## What lives where

- `lib/live_vod.dart` — the public surface.
- Everything else sits under `lib/src/`: one file per concern, no deeper
  tree — the package is deliberately flat.

Pure Dart and player-agnostic: it resolves *addresses*, it does not open
them. Expired play URLs are the caller's signal to ask again.
