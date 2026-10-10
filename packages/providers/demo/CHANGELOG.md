# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- The demo source is now a reference implementation of the whole capability surface instead of a feed stub:
  `categories()` derived from its own rows, real fixed-page `browse` (clamped page size, category filter,
  honest `hasMore` and `total`), `search`, and `feed` kept in `singleShot` so one source demonstrates both
  paging shapes.
- **Fixed**: `resolve` answered any `ref.contentId` with the same stream and `detail` invented a title for any
  id. A fixture that fudges those teaches the fudge - the player starts, diagnostics say success, and the room
  the user tapped is never the room on screen. Unknown refs, unknown qualities and unknown lines now refuse,
  and a `SelectionRef` is validated and recorded rather than ignored.
- `createdAt` comes from an injected `Clock`; `DemoRoom` replaced the bare record tuple so category and host
  are data rather than text parsed out of a subtitle.
