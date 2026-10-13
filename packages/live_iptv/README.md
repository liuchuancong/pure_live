# live_iptv

IPTV for Pure Live: playlist parsing, a persistent channel library, programme guide
matching, and line liveness — the parts that decide *which* channel a viewer gets,
not how it is decoded.

## Purpose

A playlist is not a data source; it is a text file that several generators wrote in
slightly different dialects, and the interesting work happens after parsing: keeping
a viewer's favourites and numbers through a re-import, deciding which of a channel's
several addresses is worth playing, and putting a programme title against a stream
that carries no metadata. Those decisions have consequences the UI cannot fix after
the fact, so they belong in one package with tests.

## Responsibilities

- `parsePlaylist` — M3U (`EXTINF` attributes, `EXTGRP`, `EXTVLCOPT`/`KODIPROP`
  options, `url|headers` tails, `tvg-chno`) and TXT (`name,url`, `group,#genre#`,
  `#` alternatives), parsed tolerantly: a playlist that half-satisfies a dialect
  still yields the channels it can.
- `IptvLibrary` over the `IptvStore` seam — persists channels, playlists, group
  arrangement and probe verdicts; the production store is a Hivez box, and the seam
  exists so the reconciliation rules are testable without one.
- Re-import reconciliation **by URL** — favourites, typed numbers, hidden flags and
  ordering survive a playlist update, because a viewer's intent is not re-derivable
  from the file that changed it.
- `IptvZapSequence` and `IptvChannel.number` — the wrap-around walk the up/down keys
  take, and the number a viewer types. These belong to the viewer, not to the source,
  so they are modelled apart from the playlist.
- `IptvLineProber` over the `IptvLineProbe` seam — asks a channel's addresses how alive
  they are, and the library turns the answers into the candidate order a player receives.
- `guide/` — EPG parsing (XMLTV and JSON), matching and lookup.
- `import/` — importing from a file or a URL, with `IptvImportResult` describing what
  was added, merged or rejected.
- `catchup/`, `sync/`, `order/`, `playlist/` — catch-up metadata, synchronisation,
  ordering rules and the playlist file model.
- `LibraryIptvChannelSource` — exposes the library through the `live_sites` IPTV site,
  so library channels play through the ordinary playback stack rather than a special path.

## Explicitly not owned

Decoding and playback (`live_playback`), transport (`live_net`), site scraping for
other sources (`live_sites`), and any widget. Only
`lib/src/probe/live_net_line_probe.dart` knows a transport exists: it adapts
`live_net`'s `MediaProbe` to the `IptvLineProbe` seam, and everything above the seam
is testable without a network.

## Public entry point

`package:live_iptv/live_iptv.dart`.

## Dependencies

`live_net`, `live_sites`, `live_storage`, `xml`, `equatable`, `freezed_annotation`,
`json_annotation`, `meta`. Pure Dart.

## Code generation

Models are Freezed + `json_serializable`; generated `.freezed.dart` / `.g.dart` files
are not committed (repository policy, `docs/decisions/0001`), so generate first:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

## Testing

```powershell
dart test
```

Eight suites cover the parts whose mistakes are silent: `playlist_channel_number_test`,
`channel_ordering_test`, `zap_sequence_test`, `line_prober_test`,
`live_net_line_probe_test`, `guide_lookup_test`, `iptv_sync_coordinator_test`,
`live_net_fetch_test`.

## Known limitations

- Tolerant parsing means a malformed playlist yields fewer channels rather than an
  error; `IptvImportResult` is the only place the loss becomes visible.
- A line verdict is a statement about a moment: probing again can disagree, and the
  library keeps the last verdict rather than a history.
- The model directory is `lib/src/model/` (singular); entities are already one per
  subdirectory, but the canonical path in `dart-model-and-codegen-standards.md` §15 is
  `lib/src/models/<entity>/`, so a rename is still owed.
- EPG matching is title/time based against streams that carry no programme metadata,
  so a schedule that drifts from the broadcaster's clock mismatches.
