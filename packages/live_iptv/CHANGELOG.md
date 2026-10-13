# Changelog

## Unreleased

### Added

- Channel numbers as viewer state: `IptvChannel.number` and `IptvZapSequence`, the
  wrap-around walk the up/down keys take. A typed number and a channel's position in a
  file are different facts, and conflating them is what made remote navigation lose
  places after a re-import.
- Line liveness over the `IptvLineProbe` seam: `IptvLineProber` ranks a channel's
  candidate addresses and the library stores the verdicts, so the player is handed an
  ordered list rather than picking the first string in the playlist.
- `live_net_line_probe.dart` — the only file in this package that knows a transport
  exists, adapting `live_net`'s `MediaProbe` to the seam.
- Programme guide: XMLTV and JSON parsing, matching and lookup, plus EPG import.
- `IptvImporter` and `IptvImportResult` for file and URL imports, reporting what was
  added, merged or rejected.
- `LibraryIptvChannelSource`, exposing the library through the `live_sites` IPTV site so
  library channels take the ordinary playback path.

### Changed

- Re-import reconciles by URL, so favourites, numbers, hidden flags and group ordering
  survive a playlist update instead of resetting to the file's order.
- Source layout restructured to one unit per directory (`guide/`, `import/`, `library/`,
  `model/`, `order/`, `playlist/`, `probe/`, `sync/`, `catchup/`), each with its own
  barrel, so a consumer imports a unit instead of reaching into implementation files.
- Persistence goes through the `IptvStore` seam with an in-memory implementation
  alongside the Hivez box, which is what makes the reconciliation rules testable.

### Breaking Changes

- Initial development release; no stability commitment yet.
