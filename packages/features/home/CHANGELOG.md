# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- The layout row is now a typed preference of `pure_live_storage` (`PreferenceKey<HomeLayout>`, codec
  `homeLayout`) instead of a hand-rolled `{v, order, hidden}` string written straight into the key-value
  store. The hand-rolling had a layering reason that no longer exists: the mechanism used to live in
  `features/settings`, a sibling section 3 forbids importing, and it now lives in this package's own
  dependency. Envelope, namespace, codec gating, rejection accounting and the change stream come from one
  place; the package keeps the rule that is *about layouts* — a document version carried inside the value, so
  a row from a newer build is refused rather than half-read, and an absent `hidden` list means "never hid a
  tab", not "corrupt".
- Rows already on disk in the older shape keep working through `PreferenceKey.upgrade`, and reading them does
  not rewrite them: displaying the user's arrangement must not be the event that migrates storage.
- Added `dispose()`, closing the change stream of the store this repository now creates.
- Tests 18 to 20: the envelope assertion, a legacy-string row read back unchanged, and a save-then-reload
  landing in the new shape.

- **Breaking**: `HomeTab.visible` became `defaultVisible`, and the user's choice moved into a separate
  persisted set. A single flag was overwritten by the organizer's hidden set, so a tab shipped hidden by
  default came back visible the first time the organizer ran.
- **Breaking**: `HomeTabOrganizer.organize({savedOrder, hidden})` became `arrange(HomeLayout)` returning
  `ArrangedHomeTab` (tab + computed visibility + whether the position was user-chosen). The old signature
  could not express "ordered but hidden", and callers re-derived it differently.
- Added `HomeLayout` as the persisted value, with content equality so two devices holding the same choice
  compare equal.
- Added `HomeLayoutRepository` and `StoredHomeLayout`: an envelope `{"v":1,"order":[...],"hidden":[...]}`
  under `<namespace>.home_layout`, namespaced per app because the four apps share one database and their
  tab sets differ. A row missing `hidden` is treated as a migration, not as damage.
- Added `HomeLayoutService` for the two user intents - move to front, hide without losing the row - and
  `staleSavedIds` for the startup diagnostic.
- An unreadable row now reports through `onReadFailure` and falls back to the declared defaults. It used to
  be indistinguishable from "this user has never arranged anything".
- Declared the dependencies this package imports (`storage`, `utils`); the pubspec had none.
