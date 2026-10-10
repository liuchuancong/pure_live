# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Fixed**:`showPlayerOptionSheet` opened a fixed-height bottom sheet, so a source with forty lines or six
  qualities rendered a list that could not be scrolled and the last options existed only to the caller that
  built them. Its sibling `showPlayerEpisodePanel` had already been given `isScrollControlled` plus a
  `DraggableScrollableSheet`; the sheet now does the same (short lists open small, long ones pull up to 85%
  and scroll).
- An empty option list no longer opens a titled sheet with nothing in it: that reads as a broken button
  rather than as "this content has no variants", and the caller's fact is better returned than displayed.
- The selected row's check mark and the playing episode's icon carry semantic labels, and the row number is
  laid out to a fixed width so the titles line up: without a label a screen reader reads a list of
  identical rows and the marker is invisible to the one user who cannot see it.
- Sheet paddings come from `PureLiveSpacing` instead of the literals 24/8/24/12, so the two panels move
  together when the tokens change. New dependency: `ui/design` (the ui layer's leaf).

- Skeleton created for layer ui as `pure_live_player_ui`: no dependencies and no implementation yet.
