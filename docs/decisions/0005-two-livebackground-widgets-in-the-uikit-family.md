# 0005 — Two `LiveBackground` widgets in the uikit family

- **Status:** Proposed — decision pending
- **Date:** 2026-10-14
- **Affects:** `live_uikit`, `live_uikit_background`, `apps/pure_live`, `tool/check_architecture.ps1`

## Context

The uikit family contains two unrelated widgets with the same public name:

- `live_uikit/lib/src/backgrounds/live_background.dart` — `LiveBackground` painting a
  `LiveBackgroundStyle`: solid, gradient, image, glass, raised. Token-driven, part of
  the theme surface, no media.
- `live_uikit_background/lib/src/rendering/live_background.dart` — `LiveBackground`
  painting a sealed `BackgroundConfig`: solid, gradient, image, **video**, plus
  `BackgroundLayerStack`, overlays, letterbox fill, a `BackgroundVideoSource` seam to
  the player kernel and `AppVisibleScope` for lifecycle-driven pausing.

Neither package depends on the other: `live_uikit_background`'s only dependency is
Flutter, and `live_uikit` depends on no UI library (§3.3, enforced by
`tool/check_architecture.ps1`).

Two facts make the collision more than cosmetic:

- **The names are not distinguishable at a call site.** `import 'package:live_uikit/live_uikit.dart'`
  and `import 'package:live_uikit_background/live_uikit_background.dart'` both export
  `LiveBackground`; a file using both needs a prefix on one of them, and nothing in the
  code says which one is intended.
- **Style adapters can compose neither.** The guard treats every `live_uikit_*` package
  as an adapter for isolation purposes, so a style adapter may not import
  `live_uikit_background` at all, and `live_uikit`'s own surface is the only background
  a language could ever reach. `live_uikit_background/README.md` now states this
  explicitly — the claim that adapters compose its background was wrong and was removed.

Adoption is currently ~zero on both sides: the only renderer of either widget in the
repository is `apps/pure_live/lib/background_demo_page.dart`. This is the moment to
settle it, and it is the only moment where settling it costs nothing.

## Decision (recommended, not yet applied)

Keep one name in one owner, and make the other name say what it is:

1. `live_uikit` keeps `LiveBackground` for the **token surface** — it is theme state,
   it participates in `LiveTheme.canBlur`, and every style can render it.
2. `live_uikit_background` renames its widget to `LiveMediaBackground` (its
   `BackgroundConfig` union keeps its names). The package's reason to exist is media,
   layers and lifecycle plumbing, and the new name says so at the call site.
3. The two stay independent packages. No dependency is introduced in either direction:
   `live_uikit` must keep its "no third-party UI library, no adapter" boundary, and the
   media pipeline must not acquire a theme dependency.

## Alternatives considered

- **Merge into `live_uikit`.** Rejected: `live_uikit` owns no player seam, no
  lifecycle observation and no layer stack, and pulling them in would put a video
  contract behind the same import every screen already takes.
- **Have `live_uikit`'s background delegate image/video cases to
  `live_uikit_background`.** Rejected on dependency direction: it inverts the layering
  (core depending on a satellite package) and would make the core untestable without the
  media path.
- **Do nothing and require a prefix at call sites.** Works, but it leaves the design
  question undeclared and the next reader to rediscover it; a name that needs a prefix
  to be unambiguous is the finding, not the fix.

## Consequences

- One rename in one package plus its README and `live-uikit-*` references. The
  repository has exactly one call site to update, and `live_uikit_background` is
  `publish_to: none` with no external consumers.
- Its example (`packages/live_uikit_background/example`) and tests move with the name,
  and the `AppVisibleScope`/`BackgroundVideoSource` surfaces are untouched.
- The core spec's "Overlap to settle" section closes, and
  `live_uikit_background/README.md` no longer needs a caveat about who may compose it —
  the name itself will say it is not a language surface.

## Conditions for reconsideration

Reopen if a background ever needs to be both token-driven and media-driven through one
call site — for example a theme setting that can be a flat colour or a looping video.
That would argue for one contract in `live_uikit` with an injected renderer seam, which
is a different design from either option here and needs its own decision record.
