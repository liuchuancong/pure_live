# live_preferences

Typed, versioned user preferences: one JSON document per group, persisted through
`live_storage`, with a single service that loads them once and streams changes.

## Purpose

Every package that wants a user choice needs three things that are easy to get
wrong separately: a typed shape, a stable on-disk key, and a rule for what happens
when the stored document is older, newer or damaged than the code reading it. This
package owns all three so no feature has to invent its own settings reader.

## Responsibilities

- One immutable model per group: playback, danmaku, library, TV, floating window,
  appearance, IPTV, and `DesktopPreferences` (close button, tray, sign-in launch,
  start-hidden, idle reclaim, the two rendering escape hatches, notifications).
- `PreferencesService` — load, debounced write-through, `flush`, `reset`, `dispose`,
  and a `changes` stream that is the single source of truth for re-skinning and for
  pushing live settings changes.
- `PreferencesLoadReport` — which group keys failed to read or decode, so a damaged
  document is observable instead of silently replaced.
- `DesktopPreferencesAsShell` — the projection into `live_shell`'s `ShellSettings` and
  `RenderFallbacks`, plus `desktopFieldConsumers`, the table that pairs every persisted
  field with the code that acts on it.

## Explicitly not owned

- Decisions. The desktop group stores what the viewer *wants*; `live_shell` decides
  what that means on a platform (a `hideToTray` request with no tray quits, and the
  shell is what applies that).
- Storage mechanics: box names, adapters and paths belong to `live_storage`; this
  package only names its keys through `PreferencesKeys`.
- UI. `apps/pure_live` renders the editors.

## Dependency direction

Depends on `live_storage` and `live_shell` — deliberately, so the close-action
vocabulary has one owner rather than a copy per package. Nothing in `live_shell`
knows about storage, so the graph stays acyclic. Consumers read preferences through
`AppServices`, never by opening the box themselves.

## Public entry point

`package:live_preferences/live_preferences.dart`.

## Code generation

Models are Freezed + `json_serializable`; the `.freezed.dart` and `.g.dart` outputs
are **not committed** (repository-wide policy), so any clean checkout must generate
before analysing or testing:

```powershell
melos run gen
# or, for this package alone:
dart run build_runner build --delete-conflicting-outputs
```

Never edit generated files by hand.

## Testing

```powershell
dart test
```

Serialization is pinned deliberately: the stored document outlives the build that
wrote it, so the suite asserts the exact on-disk shape, that an unrecognised enum
value or a mistyped field **resets rather than throwing** (a settings file must
never be able to prevent start-up), and that every persisted field appears in
`desktopFieldConsumers` — which is what turns "added a switch nobody reads" into a
failing test.

## Known limitations

- A corrupt field is reset silently; nothing surfaces which one.
- `WindowPreferences` (the playback float) predates the consumer table and is not
  covered by it.
- No migration framework: a renamed key reads as absent and falls back to its default.
