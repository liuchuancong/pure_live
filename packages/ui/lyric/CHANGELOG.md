# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Fixed**: switching songs applied the new lyric and the new position in the wrong order - the progress
  push only happened when `progress` itself had changed, so on a frame where text and position changed
  together (the normal case for a resumed episode or a lyric tab swipe) the previous song's position was
  applied to the freshly parsed line list and the wrong line was highlighted until the next tick.
  `didUpdateWidget` now reparses when needed and pushes the current progress afterwards, unconditionally.
- The initial progress is applied in `initState`: this surface is often opened *from* a running player, and
  a controller with no position paints every line unhighlighted until the next progress event arrives.

- Skeleton created for layer ui as `pure_live_lyric`: no dependencies and no implementation yet.
