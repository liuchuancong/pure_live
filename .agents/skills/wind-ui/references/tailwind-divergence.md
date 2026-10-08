# Wind 1.5: Wind ≠ Tailwind divergence catalog

Comprehensive map of where Wind diverges from Tailwind CSS v3 and v4. Reach for this file when migrating a className from web, recovering from a "this token does not seem to do anything" stall, or auditing a Tailwind-trained codebase.

The base rule: Wind aims for syntactic familiarity, not semantic equivalence. Most utility tokens behave as expected, but Flutter's layout model, Wind's narrower scope, and v4's CSS-only additions all produce gaps.

## Contents

1. [Mental-model differences (read first)](#1-mental-model-differences-read-first)
2. [Tokens that exist in both but behave differently](#2-tokens-that-exist-in-both-but-behave-differently)
3. [Tokens that Tailwind has, Wind does not](#3-tokens-that-tailwind-has-wind-does-not)
4. [Tokens that Wind has, Tailwind does not](#4-tokens-that-wind-has-tailwind-does-not)
5. [Tailwind v3 → v4 changes Wind has not adopted](#5-tailwind-v3--v4-changes-wind-has-not-adopted)
6. [Migration playbook (Tailwind className → Wind className)](#6-migration-playbook-tailwind-classname--wind-classname)

---

## 1. Mental-model differences (read first)

| Concept | Tailwind | Wind |
|---|---|---|
| Output target | CSS classes injected at build time, applied to DOM | `WindStyle` value object cached in memory, consumed by W-widgets at build time |
| Spacing unit | `0.25rem` (depends on root font-size) | Logical pixels (4 px per step by default; `WindThemeData.baseSpacingUnit`) |
| Wrapping | `flex-wrap` (CSS flex-wrap property) | `wrap` (Flutter `Wrap` widget is structurally separate from `flex`) |
| Container layout | `flex` works on any element | `flex` requires `WDiv`; raw `Container` does not parse className |
| `dark:` opt-in | Optional (use only when needed) | Required for every color token; missing peer is a bug |
| Unknown tokens | Build-time warning OR ignored depending on config | No-op at runtime (dropped). A one-time `kDebugMode` `debugPrint` names the token only when NO parser recognizes it (its prefix matches no parser); a recognized family with an unsupported value (e.g. `text-7xl`, claimed by `text-*`) drops silently with no hint. Valid tokens handled outside the parser map (widget-consumed `object-*`, the `inline-flex`/`inline-block`/`inline` display keywords, inert compat tokens like `transition-colors` / `antialiased` / `sr-only` / `tabular-nums`) are exempt, so the hint targets genuine unknown-family typos |
| Important modifier | `!flex` (v3) or `flex!` (v4) | Not implemented |
| Container queries | `@container`, `@sm:`, `@max-md:` | Not implemented; viewport-only |
| Group / peer state | `group-hover:`, `peer-focus:` | Not implemented; use `states: Set<String>` |
| Configuration | `tailwind.config.js` (v3) or `@theme` CSS (v4) | `WindThemeData` constructor parameter |
| Source of truth | `.css` build output | Runtime `WindStyle` object + `WindContext` resolution |

---

## 2. Tokens that exist in both but behave differently

| Token | Tailwind | Wind |
|---|---|---|
| `flex-wrap` | Enables wrapping on a flex container | Aliased directly to `wrap` (the canonical token); emits a one-time `kDebugMode` hint pointing at `wrap` |
| `text-{xs..6xl}` | Sizes go to `9xl` (128 px) | Stops at `6xl` (60 px). `7xl` / `8xl` / `9xl` silently no-op |
| `text-7xl`+ | Larger sizes available | No-op |
| `text-{color}` | Pure font color | Overloaded across color / alignment / size / weight; resolves in order |
| `w-full` inside a flex Row | Works (max-width: 100%) | A bare `w-full` row child is treated as `flex-1` (wrapped in `Expanded`) and fills the row; `flex-1` is the clearer, idiomatic choice. `md:w-full` is not auto-expanded. |
| `h-full` inside a vertical scroll | Works (max-height: 100%) | Raises an actionable dev assert ("use `flex-1` inside a `flex flex-col` instead of `h-full` inside a vertical scroll"); the scrollable parent threads a vertical-unbounded flag so the child can fail fast. Stripped in release. |
| `overflow-x-auto` + `w-full min-w-[Npx]` (shadcn Table pattern) | Fills container, scrolls when content exceeds it | Same behavior, composed from existing tokens (no new token). `w-full` inside a horizontal scroll is sized to `max(viewport, min-w-*)` via the threaded viewport width instead of asserting on the scroll's unbounded width: fills on wide, scrolls on narrow. |
| `IntrinsicHeight` / `IntrinsicWidth` (Flutter widget, not a token) | N/A | Wind's own flex is intrinsic-safe, and so is `h-full` (the `WindFullHeightBox` render object): a `flex flex-col` (smart stretch, explicit `items-stretch`, or `basis-*`) uses NO `LayoutBuilder` (column stretch is the `WindCrossStretch` render object; `basis-*` resolves against the flex extent via `WindMainExtentProvider`), so it renders under an `IntrinsicHeight`/`Table`/grid cell without asserting. Still avoid wrapping ARBITRARY subtrees in `IntrinsicHeight`/`IntrinsicWidth` inside sheet/route open animations (they can raise `RenderBox was not laid out`); for a connector or rail prefer a `Stack` + `Positioned(top: 0, bottom: 0)` line or wind's `items-stretch` column. Wind itself uses no `IntrinsicHeight` or `IntrinsicWidth`. |
| `overflow-y-auto` | Native browser scrollbar | Renders Flutter scroll view; needs constructor `scrollPrimary: true` for iOS tap-to-top |
| `bg-red-500/50` | Color with 50% opacity (v3.x+) | Same syntax, same semantics |
| `dark:bg-gray-900` | Active only when dark mode is enabled | Active only when `WindThemeData.brightness == Brightness.dark`; required to pair every color |
| `divide-x-N` | Inserts borders between children | Not implemented; use explicit borders on children |
| Spacing scale | 0, 0.5, 1, 1.5, ..., 96 with gaps; `0.25rem` per step | Same scale, but unit is 4 px (`baseSpacingUnit`); arbitrary values do NOT support percentages for padding / margin / positioning |
| Color shade scale | 50, 100, 200, ..., 950 (11 steps) | Same (50 through 950) |
| Default breakpoints | sm 640, md 768, lg 1024, xl 1280, 2xl 1536 (px) | Identical |
| `transition` / `transition-all` | Implicit transitions on all properties | Bare `transition` not wired; pair `duration-N` + `ease-*` instead |
| `animate-spin` / `pulse` / `bounce` / `ping` | CSS keyframes; finite or infinite | All infinite loops in Wind |
| `rounded-{sm|md|lg|...}` | Match Tailwind v3 scale | Identical to v3; Wind has NOT adopted the v4 rename shift |
| `shadow-{sm|md|lg|...}` | Match Tailwind v3 scale | Identical to v3 |
| `ring` (bare) | v3 default 3 px; v4 default 1 px | Wind matches v3 (default 3 px) |
| `tracking-{tighter..widest}` | em fractions (`tracking-wide` = 0.025em, scales with font size) | Fixed px (`tighter` -2, `tight` -1, `wide` 1, `wider` 2, `widest` 4) because `TextStyle.letterSpacing` is pixel-based; NOT proportional across font sizes |
| `max-w-prose` | `65ch`, font-relative (≈ 520-624 px depending on font) | Fixed `512 px`; a divergence, not an equivalent |

---

## 3. Tokens that Tailwind has, Wind does not

When a className inherited from a web project includes any of these, expect silent no-ops. Strip them, or find a Wind-shaped substitute.

### Layout / flex
- `flex-nowrap` (default; omit `wrap`)
- `flex-wrap-reverse`

### Spacing
- `ps-N` / `pe-N` / `ms-N` / `me-N` (logical inline-start/end); use `pl-` / `pr-` / `ml-` / `mr-` (physical) instead
- `-m-N` / `-mt-N` etc. (negative margins); restructure layout
- `p-[10%]` or any `%` arbitrary for padding / margin

### Sizing
- `w-auto` / `h-auto` (omit; Flutter defaults to intrinsic)
- `max-w-none` (use `max-w-full`)
- `w-min` / `w-max` / `w-fit`

### Position
- `fixed` / `sticky` (recognised, no visual effect; use Material `SliverAppBar` for sticky behavior)
- `%` for offsets (`left-[50%]`)

### Border
- `border-dashed` / `border-dotted` (recognised, not rendered)
- `divide-x-N` / `divide-y-N` (use explicit borders)

### Effects (entire families absent)
- `blur-*` / `backdrop-blur-*`
- `brightness-*` / `contrast-*` / `grayscale-*` / `hue-rotate-*` / `invert-*` / `saturate-*` / `sepia-*`
- `drop-shadow-*`
- `mix-blend-*` / `bg-blend-*`
- `filter` / `backdrop-filter`

### Interactivity
- `cursor-*` IS supported (`cursor-pointer`, `cursor-not-allowed`, resize/zoom/grab, etc.) via a `MouseRegion` `WDiv` adds; see `tokens.md` §16. `WAnchor` also exposes a `mouseCursor:` constructor prop for imperative control.
- `pointer-events-none`: wrap in `IgnorePointer`
- `select-none` / `select-text`
- `scroll-smooth`
- `snap-*` (scroll snap)
- `touch-*`
- `appearance-none`
- `will-change-*`
- `caret-*`
- `accent-*`

### Typography
- `text-7xl` / `-8xl` / `-9xl` (cap is 6xl)
- `whitespace-pre` / `-pre-line` / `-pre-wrap` / `-break-spaces` (only `whitespace-normal` and `whitespace-nowrap` wired)
- `hyphens-*`
- `indent-*`
- `list-disc` / `list-decimal` / `list-none`
- `align-baseline` / `-top` / `-middle` / `-bottom` (use `crossAxisAlignment` instead)

### Transitions / animations
- Bare `transition` / `transition-all` / `transition-colors` / `transition-opacity` / `transition-transform` (only `duration-*` + `ease-*` wire)
- `delay-N`
- `motion-safe:` / `motion-reduce:`

### Transforms (entire family absent)
- `scale-N` / `scale-x-*` / `scale-y-*`
- `rotate-N` / `rotate-x-*` / `rotate-y-*` / `rotate-z-*`
- `translate-x-*` / `translate-y-*` / `translate-z-*`
- `skew-x-*` / `skew-y-*`
- `origin-*`
- `transform-gpu` / `transform-none`
- `perspective-*` (v4 3D transforms)

### State variants
- `group-*` / `peer-*` (no group / peer concept; use `states: Set<String>`)
- `first:` / `last:` / `odd:` / `even:` / `first-of-type:` / `empty:` / `open:`
- `before:` / `after:` (no pseudo-elements)
- `selection:` / `placeholder:` / `marker:` / `file:`
- `motion-safe:` / `motion-reduce:` / `print:`
- `focus-within:` / `focus-visible:`
- `active:` (reserved, NOT wired; WAnchor tracks hover and focus only)

### Container queries
- `@container`, `@sm:`, `@md:`, `@lg:`, `@max-md:`, named containers (`@sm/sidebar:`): viewport-only in Wind

### CSS-only constructs
- `@apply` / `@layer` / `@variant` / `@theme` directives: Wind has no CSS layer
- `!important` modifier (`!flex` v3, `flex!` v4)
- `bg-opacity-N` / `text-opacity-N` / `border-opacity-N` (v3 legacy): use slash modifier `/N`

---

## 4. Tokens that Wind has, Tailwind does not

Wind adds a small set of tokens for Flutter-specific scenarios.

### Platform prefixes (Flutter targets multiple platforms)
- `ios:` / `android:` / `macos:` / `windows:` / `linux:` (specific platform)
- `mobile:` (iOS OR Android)
- `web:` (web build)

### Order scale starts at zero
- `order-0`: Wind supports `order-0` through `order-12`; Tailwind's default scale starts at `order-1` (`order-0` is a Wind addition)

### Main-axis size (Flutter `MainAxisSize`)
- `axis-min`: sets `MainAxisSize.min` on the parent flex
- `axis-max`: sets `MainAxisSize.max`

### Inline color escape hatches (bypass cache key for runtime-dynamic colors)
- `WDiv(backgroundColor: Color)`: Dart prop, overrides className `bg-*`
- `WText(foregroundColor: Color)`: Dart prop, overrides className `text-*`
- `WIcon(foregroundColor: Color)` (Dart prop) overrides className `text-*`

### Per-breakpoint widget builders
- `WBreakpoint(base: ..., sm: ..., md: ...)`: when className prefixes cannot express the change

### Server-driven UI
- `WDynamic(json: ...)`: renders a JSON node tree into Wind widgets

### SVG fill preservation
- `preserve-colors`: disables Wind's color filter; renders embedded SVG colors unchanged (QR codes, logos, multi-color illustrations)

### className aliases (runtime shorthand expansion)
- `WindThemeData.aliases` (`Map<String, String>`) maps bare-token keys to className strings, expanded recursively by `WindParser.parse` before any parser runs. Closest Tailwind analogue: `@layer components` / UnoCSS shortcuts; unlike those, there is no CSS cascade and expansion is a pure string substitution at runtime. Keys are bare tokens only (no prefix, no colon). An alias that shadows a real token wins and emits a debug warning. Empty by default; works in every widget and in `WDynamic` without additional wiring.

### Debug instrumentation
- `debug` token: triggers `WindLogger` to log composition tree + final styles
- `Wind.installDebugResolver()` (Dart API): exposes 7 fields per widget to external tooling

---

## 5. Tailwind v3 → v4 changes Wind has not adopted

Wind 1.0 is anchored to Tailwind v3 semantics for shadow / radius / blur / ring naming. If you're migrating from a Tailwind v4 project, watch these renames.

| v4 name | v3 name (Wind keeps this) |
|---|---|
| `shadow-xs` | `shadow-sm` |
| `shadow-sm` | `shadow` |
| `blur-xs` | `blur-sm` (Wind has no `blur-*` anyway) |
| `blur-sm` | `blur` (Wind has no `blur-*` anyway) |
| `rounded-xs` | `rounded-sm` |
| `rounded-sm` | `rounded` |
| `bg-linear-*` | `bg-gradient-*` |
| `bg-linear-to-r` | `bg-gradient-to-r` |
| `bg-conic-*` | not implemented |
| `bg-radial-*` | not implemented |
| `shrink-*` | both `shrink-*` and `flex-shrink-*` work |
| `grow-*` | both `grow-*` and `flex-grow-*` work |
| `outline-hidden` | not implemented (use `outline-none` if you need it; not wired either) |
| `ring-3` (explicit width to get the v3 default) | `ring` produces 3 px (matches v3) |
| `bg-black/50` (opacity modifier) | Same; `bg-opacity-50` removed in v4, also not in Wind |
| Spacing multiplier (any whole number works in v4) | Wind uses explicit theme scale; `p-13` is not in the default scale (use arbitrary `p-[13]` instead) |
| Important suffix `bg-red-500!` | Not implemented |
| 3D transforms | Not implemented |

---

## 6. Migration playbook (Tailwind className → Wind className)

When porting a className from a web project:

**Step 1: strip the unwired.** Run the className through these substitutions (paste / search-replace, or do it mentally):

```
group-hover:*          → drop, or replace with states: + custom state string
peer-focus:*           → drop
@container, @sm:*      → drop
first:* / last:* /     → drop
  odd:* / even:* /
  before:* / after:*
focus-within:* /       → drop
  focus-visible:*
print:* /              → drop
  motion-safe:* /
  motion-reduce:*
cursor-*               → SUPPORTED (WDiv adds MouseRegion; tokens.md §16)
pointer-events-none    → wrap in IgnorePointer
select-none            → drop (set selectable: false on WText)
scroll-smooth /        → drop
  snap-* /
  touch-*
appearance-none /      → drop
  caret-* / accent-*
will-change-*          → drop
list-disc / list-none  → drop (use explicit bullet widgets if needed)
align-baseline etc.    → drop (use crossAxisAlignment)
hyphens-* / indent-*   → drop
filter / backdrop-* /  → drop (Flutter Compositing or BackdropFilter for blur)
  blur-* / brightness-*
  / contrast-* / etc.
scale-* / rotate-* /   → drop (use AnimatedContainer / Transform.scale / Transform.rotate)
  translate-* / skew-*
divide-x-* / divide-y-*→ drop (add explicit borders on children)
text-7xl / -8xl / -9xl → cap at text-6xl
flex-wrap              → wrap
flex-nowrap            → drop (omit `wrap`)
ps-*                   → pl-* (or skip if RTL-aware text-start / text-end suffices)
pe-*                   → pr-*
ms-* / me-*            → ml-* / mr-*
-m-N (negative margin) → restructure (Wind does not support)
w-auto / h-auto        → drop
fixed / sticky         → drop (use Material SliverAppBar / FAB / Drawer)
top-[50%] (% offset)   → use a fractional positioned wrapper or restructure
shadow-2xl / -xl /     → same name, same semantics (v3 scale)
  -lg / -md / -sm
rounded-*              → same name, same semantics (v3 scale)
bg-opacity-N           → bg-{color}-{shade}/N (slash modifier)
```

**Step 2: pair every color with `dark:`.** Wind contract; not optional.

**Step 3: re-express conditional styling via `states:`.** Where the original Tailwind used `group-hover:` or `peer-focus:` or imperative DOM class flips, route through `states: Set<String>?` plus prefixed classes.

**Step 4: verify layout assumptions.** `w-full` inside a Row becomes `flex-1`. `h-full` inside a scrollable becomes `flex-1`. `absolute` needs a `relative` parent. `truncate` needs a bounded width (wrap in `flex-1 min-w-0`).

**Step 5: add `scrollPrimary: true`** to the outermost scrollable on every page.

**Step 6: re-test in both brightness modes.** Toggle via `context.windTheme.toggleTheme()`. A missing dark peer reveals itself instantly.

**Step 7: for any remaining gaps** (transform, blur, drop shadow, container queries, custom animations): reach for native Flutter (`Transform`, `BackdropFilter`, `AnimatedContainer`, `LayoutBuilder`, `TweenAnimationBuilder`). Wind composes freely with all of these; the W-widget remains the child.

Example port:

```html
<!-- Tailwind v4 -->
<div class="flex flex-row items-center gap-3 p-4 rounded-lg
            bg-white dark:bg-gray-800 shadow-sm hover:shadow-md
            group">
  <img class="w-10 h-10 rounded-full" src="...">
  <p class="flex-1 truncate text-gray-900 dark:text-white">
    <span class="font-semibold group-hover:text-blue-600">Title</span>
  </p>
</div>
```

```dart
// Wind
WDiv(
  className: '''
    flex flex-row items-center gap-3 p-4 rounded-lg
    bg-white dark:bg-gray-800
    shadow-sm hover:shadow-md
  ''',
  child: WDiv(
    className: 'flex flex-row items-center gap-3 flex-1 min-w-0',
    children: [
      WImage(src: avatarUrl, className: 'w-10 h-10 rounded-full'),
      WDiv(
        className: 'flex-1 min-w-0',
        child: WText(
          'Title',
          className: '''
            truncate font-semibold
            text-gray-900 dark:text-white
            hover:text-blue-600 dark:hover:text-blue-400
          ''',
        ),
      ),
    ],
  ),
);
```

Notes on the port:
- `group-hover:text-blue-600` (parent-state-driven child styling) became `hover:text-blue-600` on the text directly. If genuine parent-driven hover is needed, build it via `WAnchor` on the outer `WDiv`, capture state in the consumer, and pass `states: {'hovered'}` to the inner WText with a custom prefix.
- `truncate` on the `<p>` became `truncate` inside a `flex-1 min-w-0` wrapper.
- Every color paired with `dark:`.
- Outer `shadow-sm hover:shadow-md` kept; would auto-wrap in `WAnchor` because of the `hover:` prefix.

## Unsupported Tailwind classes (use the wind equivalent)

These canonical Tailwind classes are silently ignored by wind (unknown tokens are dropped). Use the listed equivalent:

| Tailwind | Status | wind equivalent |
|----------|--------|-----------------|
| `inline-flex` | unsupported (Flutter has no inline layout) | `flex` + `self-start` |
| `rounded-s-*` / `rounded-e-*` | unsupported (logical start/end radius) | `rounded-l-*` / `rounded-r-*` |
| `ms-*` / `me-*` | unsupported (logical inline margin) | `ml-*` / `mr-*` |
| `start-*` / `end-*` | unsupported (logical inset) | `left-*` / `right-*` |
| `-space-x-*` / `-space-y-*` | unsupported (negative gap; no overlap primitive) | none |
| `self-*` | supported (alias of `align-self-*`) | `self-center` etc. work directly |
| `shrink-0` | supported (preserves intrinsic size, no Flexible wrap) | works directly |
| `flex-none` | supported as CSS `flex: 0 0 auto` (no grow AND no shrink; keeps intrinsic size) | works directly |
| `basis-*` | supported as a MAIN-axis initial size (`basis-1/2`, `basis-full`, `basis-[Npx]`); ignores grow/shrink interplay | works directly |
| `text-7xl` / `8xl` / `9xl` | silently capped (max is `text-6xl`) | `text-6xl` or arbitrary `text-[96px]` |

Note: `WText` is self-contained regarding its baseline rendering. When no Material/Scaffold ancestor supplies a `DefaultTextStyle` color, `WText` applies a brightness-aware fallback (`Colors.white` on dark platforms, `Colors.black` on light, read from `MediaQuery.platformBrightness`) instead of Flutter's debug yellow-underline; it also injects a `Directionality(ltr)` wrapper when no `Directionality` is inherited. Resolution precedence over that fallback (highest first): an explicit `text-*` className color, the `foregroundColor` / `textStyle` props, then an inherited ancestor `DefaultTextStyle` color. The brightness fallback applies only when none of those supply a color.

Note: Wind's smart column cross-axis stretch now covers clickable container rows (`WAnchor` and `WButton`) in addition to plain `WDiv` children, narrowing the divergence from CSS `align-items: stretch` (where element type is irrelevant). A `WAnchor`-wrapped nav row in a `flex flex-col` fills the column width by default without an explicit `items-stretch` or `w-full`.

State-shadowing edge: a disabled outer `WAnchor` does NOT suppress a `hover:` class that a nested `WDiv` carries on itself. `WDiv` auto-wraps in its own non-disabled `WAnchor` whose state provider shadows the ancestor's `isDisabled`, so the inner `hover:` still fires. This is an edge case (a disabled control wrapping a separately-hover-styled child); style the disabled state on the same element that owns the `hover:` class, or drive `disabled:` on the inner `WDiv` directly.
