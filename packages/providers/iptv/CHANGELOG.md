# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Fixed**: the XMLTV walk hard-coded `<programme start=… stop=… channel=…>` attribute order and required a
  closing tag, so a normal guide - `channel=` first, self-closing rows, no description - parsed into **zero
  programmes while reporting nothing wrong**. Attributes are now read by name and a self-closing element is an
  element.
- **Fixed**: CDATA was destroyed before it could be unwrapped (`<![CDATA[…]]>` matches the tag pattern end to
  end), so every CDATA programme description came back empty. Unwrap first, then strip tags.
- `skippedEntries` / `truncated`: bad rows are counted instead of vanishing, and a bound that stopped the parse
  says so. A parsable-but-40%-broken guide and an empty one used to look identical.
- Rows whose `stop` is not after their `start` are refused - an all-day placeholder would otherwise match every
  `between` query forever.
- `XmltvGuide` queries: `upcoming`, `onAir`, `between` and `channelFor` (id exact, then display-name matching
  with spaces/hyphens/middle dots ignored, which is how "CCTV-1综合" reaches "CCTV 1 综合").
- `IptvSource` gains `SearchCapability` (substring over name and group, list order preserved, `hasMore: false`
  with the count it actually kept) and `programmeFor` / `schedule` / `guideReport`; `nowPlaying`, `schedule` and
  the ticket's `createdAt` now read an injected `Clock`.
- Parser bounds (`maxChannels`, `maxProgrammes`) - an EPG file is untrusted input from a stranger's server.
- `pubspec.yaml`: the `pure_live_utils` leaf added for the clock.
