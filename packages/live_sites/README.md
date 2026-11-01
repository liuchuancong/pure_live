# live_sites

Site domain and adaptation contracts for Pure Live: unified room, play and
danmaku models; the `LiveSite` contract that takes `LiveRoom` first; the site
registry with metadata; and per-platform adapters. Pure Dart — players,
renderers, HTTP transports and persistence live above or beside it.

## Purpose

Every streaming platform is its own dialect: different login surfaces,
different room models, different ways of saying "this stream is HLS with a
30-second token". The app would rot if each screen had to know a dialect.
This package is where a dialect is translated once — into capability
contracts the app codes against — and where the per-platform adapters live
with their parsers, authenticated transports and their own tests.

## Responsibilities

- The capability contracts (`capabilities/`) — what a site may be asked to
  do, each a small interface: rooms, playback plans and qualities, search
  and suggestions, discovery and hot lists, areas and anchors, danmaku
  receive/send, link resolution, play leases and recovery, status checks,
  auth, web search, super-chat and cookie-refusal feeds.
- The site registry — which platforms exist, their metadata and ids, and how
  the app picks an adapter for a room id or a link.
- Per-platform adapters (`platforms/`) — one subtree per site: endpoints,
  signed/authenticated HTTP where the site demands it, parsers for rooms and
  play answers, the danmaku socket, and the capability implementations.
  Reflow/short-link handling (e.g. Douyin's `v.douyin.com` → canonical room
  URL) belongs to the resolver of the site that owns the domain.
- Shared machinery (`common/`) — the pieces several adapters reuse: HLS
  master-playlist reading, danmaku message filters (block lists, similarity,
  repetition, throttles), codec helpers, crypto primitives (AES-CBC),
  brotli, HTML entity normalisation.

## What lives where

- `lib/live_sites.dart` — the public surface.
- `lib/src/capabilities/` — the contracts; the app never reaches past them.
- `lib/src/platforms/<site>/` — adapters, one subtree per platform.
- `lib/src/common/` — adapter-shared machinery.

Pure Dart: no Flutter, no player, no persistence. Transports arrive from
`live_net`, storage from the host — the adapters decide *what* to ask for,
not *where it is kept*.
