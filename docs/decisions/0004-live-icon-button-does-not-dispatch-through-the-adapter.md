# 0004 — `LiveIconButton` does not dispatch through the adapter

- **Status:** Accepted — implemented 2026-10-14
- **Date:** 2026-10-14
- **Affects:** `live_uikit`, every `live_uikit_<style>` adapter, `apps/pure_live`

## Context

`package-standards.md` §7.1 and every adapter specification (§11) rest on one
invariant: a business widget names a semantic control and the active adapter decides
how it looks. `LiveButton`, `LiveCard`, `LiveSwitch` and the rest honour it — each
builds a `Language*Spec` and calls `LiveTheme.of(context).adapter.<control>(...)`.

`LiveIconButton` does not. It paints through `LiveBox` +
`LiveTheme.resolveButton` directly (`live_uikit/lib/src/styling/widgets/live_button.dart`),
so an icon button keeps its token-rendered appearance no matter which design language
is selected. Switching to `materialUi` or `fluent` re-skins the button beside it and
leaves this one untouched. It is the only control in the family with that behaviour,
and it is recorded as an open item in `packages/live_uikit/live-uikit.md` §16.

Two spec facts block a mechanical fix:

- `LanguageButtonSpec` has no way to say "icon only". `LiveIconButton` renders a square
  `SizedBox.square(dimension: …)` around an `Icon`; every adapter builder instead calls
  `SharedLanguageAdapter.buttonLabel`, which composes `Icon` **plus** a `Text(label)`. An
  empty label would leave an empty `Text` in the layout.
- The contract has no selected/toggled state. `LiveIconButton.selected` tints the
  foreground with `theme.colors.primary`, which is real semantics ("this control shows
  whether a mode is on") with nowhere in the spec to travel.

Blast radius today is one call site
(`apps/pure_live/lib/main.dart`, a single `LiveIconButton`), which is why this is cheap
now and will not stay cheap.

## Decision

Extend the contract rather than keep the exception. Implemented as follows:

1. Add `bool iconOnly` and `bool selected` to `LanguageButtonSpec`, both defaulting to
   `false`, and have `SharedLanguageAdapter.buttonLabel` omit the `Text` when the label is
   empty while an icon is present, and apply the square `ControlSize`-derived dimension
   when `iconOnly` is set — so the shared renderer reproduces what
   `LiveIconButton` paints by hand today, and every adapter inherits it by calling the
   seam.
2. Route `LiveIconButton` through `adapter.button(...)`, mapping `selected` onto the
   resolved foreground exactly as the current hand-painted path does.
3. Each adapter documents what it does with the two fields. Where the library has an
   equivalent, map it; where it has none, state the omission in that spec's §9 the way
   the specs already do for `focusNode` on `WButton` and `showLabel` on
   `mu.LinearProgressIndicator`. A silently dropped field is the defect; an
   explicitly unmappable one is a documented limitation.

Landed state: `LanguageButtonSpec` gained `iconOnly` and `selected`;
`SharedLanguageAdapter.buttonLabel` returns the glyph alone (with the tooltip as its
`semanticLabel`) whenever `iconOnly` is set, so all seven adapters inherit textless
rendering through the seam without a change in any builder; the token base squares the
control to its `ControlSize` height step and tints a selected button with the primary
foreground; `LiveIconButton` builds a spec and calls `adapter.button`.
`test/styling/live_icon_button_test.dart` asserts the spec that reaches the adapter, the
absence of any `Text`, the square geometry, the semantics label and the selected
foreground. `selected` is honoured by the token base only, and every adapter spec's §9
now says so.

## Alternatives considered

- **Leave it.** The exception is one widget and the visual outcome in the default
  language is unchanged either way. Rejected: it is a silent exception to the
  invariant the whole family is built on, and it grows the moment a second icon button
  appears in a screen that is supposed to re-skin.
- **Rename to `LiveTokenIconButton` and declare icon buttons out of scope for style
  switching.** Honest, cheap, and no contract change. Rejected only because no product
  requirement says icon buttons must not follow the language — that would be codifying
  an implementation gap as policy.
- **Give `LanguageButtonSpec` an `iconOnly` flag but keep `selected` out**, leaving the
  toggle state to callers. Rejected: it would move the foreground tint into business
  code, which is the direction the spec boundary exists to prevent.

## Consequences

- The adapter contract gains two optional fields. Every adapter keeps compiling
  untouched (defaults preserve current behaviour); the ones that want native support for
  a toggled icon button add it in their own package.
- `LiveTheme.resolveButton` gains a selected/pressed-foreground role, so the token
  renderer and the adapters share one definition of "toggled on".
- The §16 open item in the core spec closes, and the app's single call site needed no
  change — what moved is its rendering, from a token box to whatever the active language
  draws.
- A toggled icon button still looks unselected under a third-party library. That is the
  documented remainder: mapping it needs each library's own selected affordance, not a
  hand-painted overlay on top of its button.

## Conditions for reconsideration

Decide the other way if icon-only controls turn out to need geometry no library can
express through a `LanguageButtonSpec` (for example a fixed square with internal
padding rules per platform). Then an explicit, documented sub-contract — not a private
rendering path — is the right shape.
