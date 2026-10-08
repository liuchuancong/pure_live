# Wind 1.5: Token catalog

Exhaustive per-parser token reference. Reach for this file when verifying a className token exists, picking the right family, looking up an arbitrary-value pattern, or auditing className for unsupported syntax.

20 parsers run first-match-wins. Order within className matters: last class within the same property wins (including duplicate tokens; `top-8 top-4 top-8` resolves to `top-8`). Unknown tokens are dropped from output, and a one-time `kDebugMode` hint names each (release builds stay silent).

## Contents

1. [Cache key + resolution rules](#1-cache-key--resolution-rules)
2. [Layout (flexbox + grid + display)](#2-layout-flexbox--grid--display)
3. [Spacing (padding + margin + gap)](#3-spacing-padding--margin--gap)
4. [Sizing (width + height + min/max)](#4-sizing-width--height--minmax)
5. [Positioning (relative + absolute + inset)](#5-positioning-relative--absolute--inset)
6. [Background (colors + gradients + images)](#6-background-colors--gradients--images)
7. [Border + ring + radius](#7-border--ring--radius)
8. [Shadow + opacity](#8-shadow--opacity)
9. [Overflow + aspect-ratio + z-index + order](#9-overflow--aspect-ratio--z-index--order)
10. [Typography](#10-typography)
11. [Transitions + animations](#11-transitions--animations)
12. [SVG](#12-svg)
13. [Debug token](#13-debug-token)
14. [Prefixes](#14-prefixes)
15. [Arbitrary values](#15-arbitrary-values)
16. [Cursor (web / desktop)](#16-cursor-web--desktop)
17. [Tokens that look real but are not wired](#17-tokens-that-look-real-but-are-not-wired)

---

## 1. Cache key + resolution rules

`WindParser.parse(className, context)` produces an immutable `WindStyle`. Cache key:

```
className + activeBreakpoint + brightness + platform + sorted(activeStates).join(',')
```

Cache hit-rate is near-100% in production; the cache survives hot reload. Cleared via `WindParser.clearCache()` (test-only; required in `setUp()` for parser AND widget tests that pump Wind widgets).

Resolution:
- Each token is matched against parsers in registration order; the first parser whose `canParse()` returns `true` claims it.
- Unknown tokens are dropped from output; a one-time `kDebugMode` hint names each (release builds stay silent, no exception is thrown).
- Within a parser, last-class-wins via reverse iteration: `p-4 p-8` resolves to `p-8`.
- Across parsers, conflicts coexist by targeting different `WindStyle` fields: `text-red-500` (color) and `text-center` (alignment) both apply.
- Prefix resolution: every `:` segment must be active for the class to apply. `md:hover:dark:bg-blue-500` requires breakpoint ≥ md AND hover state AND dark brightness. Prefix order is arbitrary.

Inline color escape hatches that bypass the cache key:
- `WDiv(backgroundColor: Color)` overrides any `bg-*` / `dark:bg-*`.
- `WText(foregroundColor: Color)` overrides any `text-*` / `dark:text-*`.
- `WIcon(foregroundColor: Color)` overrides any `text-*` / `dark:text-*`.

`WindThemeData.aliases` shorthand expansion: if the active theme has `aliases` set, `WindParser.parse` expands matching bare tokens to their full className strings before the 20-parser pipeline runs. Aliases are not tokens themselves and do not appear in the catalog below; they are transparent to every parser. See `references/theme.md` and `references/tailwind-divergence.md` for details.

---

## 2. Layout (flexbox + grid + display)

| Token | Effect |
|---|---|
| `flex` | Sets `displayType = flex` (renders `Row` or `Column` based on `flex-row` / `flex-col`) |
| `grid` | Sets `displayType = grid` (renders `Wrap`, NOT virtualized; for that use `GridView.builder`) |
| `wrap` | Sets `displayType = wrap` (renders `Wrap`) |
| `block` | Default block layout |
| `hidden` | Renders `SizedBox.shrink()` |
| `flex-row` / `flex-col` | Flex direction |
| `flex-row-reverse` / `flex-col-reverse` | Reverse main-axis order |
| `flex-1` | `Expanded(flex: 1)` participation |
| `flex-N` | Numeric flex (any integer) |
| `flex-auto` | `Flexible(fit: loose, flex: 1)` |
| `flex-initial` | `Flexible(fit: loose, flex: 0)` |
| `flex-none` | CSS `flex: 0 0 auto`: no grow AND no shrink. Keeps intrinsic size (no `Flexible` wrap), like `shrink-0` |
| `flex-grow` / `grow` | `flex: 1` (Expanded). Both Tailwind v3 + v4 names supported |
| `grow-0` | No grow (intrinsic main size) |
| `flex-shrink` / `shrink` | Both supported |
| `shrink-0` | No shrink |
| `basis-1/2` / `-1/3` / `-1/4` / `-full` | Fractional flex-basis: initial MAIN-axis size (width in a row, height in a column). Approximates CSS `flex-basis`, ignores grow/shrink interplay |
| `basis-[Npx]` | Fixed flex-basis: a fixed MAIN-axis size in logical pixels |
| `justify-start` / `-end` / `-center` / `-between` / `-around` / `-evenly` | `MainAxisAlignment` |
| `items-start` / `-end` / `-center` / `-baseline` / `-stretch` | `CrossAxisAlignment` |
| `align-content-start` / `-end` / `-center` / `-between` / `-around` / `-evenly` / `-stretch` | Wrap-only, `WrapAlignment` for runs |
| `align-self-start` / `-end` / `-center` / `-stretch` / `-auto` (or the `self-*` shorthand) | Per-child cross-axis override |
| `axis-min` / `axis-max` | Wind-only: `MainAxisSize.min` / `.max` on the parent flex |
| `grid-cols-N` | N columns (any integer); renders as `Wrap` with computed column widths. Add `items-stretch` for equal-height rows: each row is a real-layout equal-height row (measures each cell, re-lays to at least the tallest via a MIN height, never a tight squeeze), NOT `IntrinsicHeight`, so cells containing a `flex flex-col`, `h-full`, or `basis-*` stretch without asserting or overflowing (#139, #141); none of those three carries a `LayoutBuilder` any more |
| `order-0` through `order-12` | Child order index |
| `order-first` / `order-last` / `order-none` | Sentinel order (first=-9999, last=9999, none=0) |
| `order-[N]` | Arbitrary signed integer (e.g. `order-[-5]`) |

Gap tokens (inside `flex` / `wrap` / `grid`):

| Token | Effect |
|---|---|
| `gap-N` | Both-axis gap |
| `gap-x-N` / `gap-y-N` | Axis-specific |
| `space-x-N` / `space-y-N` | Margin-based child spacing (distinct from `gap-*`) |

Arbitrary: `gap-[10px]`, `gap-x-[3.5]`, `space-y-[12px]`. The `px` suffix is optional.

---

## 3. Spacing (padding + margin + gap)

Base unit: `4 px` per step (`WindThemeData.baseSpacingUnit`). `p-4` = 16 px.

| Token | Effect |
|---|---|
| `p-N` / `px-N` / `py-N` / `pt-N` / `pr-N` / `pb-N` / `pl-N` | Padding (all four / horizontal / vertical / one side) |
| `m-N` / `mx-N` / `my-N` / `mt-N` / `mr-N` / `mb-N` / `ml-N` | Margin |
| `mx-auto` | Horizontal centering |

Numeric `N` accepts the theme spacing scale (`0`, `0.5`, `1`, `1.5`, ..., `96`, plus fractions `1/2` / `1/3` / `2/3` / `1/4` / `3/4` and special `full`).

Arbitrary: `p-[18px]`, `m-[3.5]`, `pt-[5]`. Suffix `px` optional. **No `%` for padding or margin.**

NOT supported (silently no-op):
- `ps-*` / `pe-*` / `ms-*` / `me-*` (logical inline-start/end)
- Negative margins (`-m-N`, `-mt-N`, etc.)
- Percentage padding / margin

---

## 4. Sizing (width + height + min/max)

| Token | Effect |
|---|---|
| `w-N` / `h-N` | Theme scale (4 px per unit) |
| `size-N` / `size-full` / `size-1/2` / `size-screen` / `size-[20px]` / `size-[50%]` | Sets BOTH width and height in one token (Tailwind v3.4+). Works on a childless `WDiv` (e.g. a `size-2 rounded-full` status dot). A later same-mode `w-*` / `h-*` overrides the matching axis (`size-2 w-8` -> width 32, height 8); mixing an absolute and a fractional value on one axis retains both, exactly as `w-*` / `h-*` already do. |
| `w-1/2` / `w-1/3` / `w-2/3` / `w-1/4` / `w-3/4` | Fractional (any numerator/denominator) |
| `w-full` / `h-full` | `widthFactor: 1.0` / `heightFactor: 1.0` |
| `w-screen` / `h-screen` | Viewport dimensions |
| `w-[300px]` / `h-[50%]` | Arbitrary (px OR % both supported for sizing; unique among parsers) |
| `min-w-0` / `min-w-full` / `min-w-screen` | Min width |
| `max-w-xs` / `max-w-sm` / `max-w-md` / `max-w-lg` / `max-w-xl` / `max-w-2xl` ... `max-w-7xl` | Named max-widths (320 / 384 / 448 / 512 / 576 / 672 / ... 1280 px) |
| `max-w-prose` | 512 px |
| `max-w-full` / `max-w-screen` | No max OR viewport-wide |
| `min-h-0` / `min-h-full` / `min-h-screen` | Min height |
| `max-h-full` / `max-h-screen` | Max height |
| `min-w-[100px]` / `max-h-[200%]` | Arbitrary min/max |

NOT supported:
- `w-auto` / `h-auto` (silently skip; omit the token, Flutter defaults to intrinsic sizing)
- `max-w-none` (use `max-w-full` instead)

---

## 5. Positioning (relative + absolute + inset)

Wind translates `relative` + child `absolute` into a Flutter `Stack` + `Positioned` tree.

| Token | Effect |
|---|---|
| `relative` | Marks parent as Stack-host |
| `absolute` | Removes child from flow; participates as `Positioned`. REQUIRES `relative` parent. |
| `top-N` / `right-N` / `bottom-N` / `left-N` | Directional offsets, theme scale |
| `inset-N` | All four sides |
| `inset-x-N` / `inset-y-N` | Axis pair |
| `-top-N` / `-right-N` / `-bottom-N` / `-left-N` / `-inset-N` / `-inset-x-N` / `-inset-y-N` | Negative offsets (overhang) |
| `top-[24px]` / `left-[12px]` / `-inset-[10px]` | Arbitrary px |

NOT supported:
- `fixed` / `sticky` (parser recognises but no visual effect; reserved for future versions)
- `%` arbitrary for offsets (`left-[50%]` silently ignored)

---

## 6. Background (colors + gradients + images)

Color tokens always need a `dark:` peer.

| Token | Effect |
|---|---|
| `bg-{family}-{shade}` | Theme color (`bg-red-500`, `bg-blue-300`) |
| `bg-{family}` | Defaults to shade 500 (`bg-red` = `bg-red-500`) |
| `bg-[#hex]` | Arbitrary hex (3, 4, 6, or 8 chars; `#`-prefixed inside brackets). Alpha LEADS in the 4- and 8-char forms: Flutter packs `AARRGGBB` where CSS writes `RRGGBBAA`, so 50%-alpha red is `bg-[#80ff0000]`, never `bg-[#ff000080]`. Nothing between those lengths: a 5- or 7-char value is a typo and drops silently. |
| `bg-{family}-{shade}/{N}` | Opacity modifier (`bg-red-500/50` = 50% opacity) |
| `bg-transparent` / `bg-white` / `bg-black` | Specials |
| `bg-current` / `bg-inherit` | Inherit from `DefaultTextStyle.color` |
| `bg-cover` / `bg-contain` | Image fit modes |
| `bg-center` / `-top` / `-bottom` / `-left` / `-right` / `-top-left` / `-top-right` / `-bottom-left` / `-bottom-right` | Image alignment |
| `bg-no-repeat` / `bg-repeat` / `bg-repeat-x` / `bg-repeat-y` | Image repeat |
| `bg-[url(...)]` | Background image (http://, https://, file paths, asset paths) |
| `bg-gradient-to-{t|tr|r|br|b|bl|l|tl}` | Gradient direction (8 cardinal + diagonal) |
| `from-{family}-{shade}` / `from-[#hex]` / `from-{family}-{shade}/{N}` | Gradient start color |
| `via-{family}-{shade}` etc. | Gradient mid color |
| `to-{family}-{shade}` etc. | Gradient end color |

Default color families (23): `primary`, `slate`, `gray`, `zinc`, `neutral`, `stone`, `red`, `orange`, `amber`, `yellow`, `lime`, `green`, `emerald`, `teal`, `cyan`, `sky`, `blue`, `indigo`, `violet`, `purple`, `fuchsia`, `pink`, `rose`. Plus `white`, `black`, `transparent`.

Default shade scale: `50`, `100`, `200`, `300`, `400`, `500`, `600`, `700`, `800`, `900`, `950` (11 steps).

`primary` is seeded (aliased 1:1 to the `blue` swatch), so `bg-primary`, `text-primary`, and `border-primary` resolve with no registration. It is also the token the interactive widgets (`WSelect`, `WCheckbox`, `WRadio`, `WDatePicker`) route their selection colors through, so overriding it in `WindThemeData.colors: {'primary': <brand swatch>}` rebrands them in one place.

Custom families via `WindThemeData.colors`: `{'brand': MaterialColor(...)}` makes `bg-brand-500` available.

---

## 7. Border + ring + radius

| Token | Effect |
|---|---|
| `border` | Default uniform width (theme `DEFAULT` = 1 px) |
| `border-N` | Numeric width (`border-2`, `border-4`, `border-8`) |
| `border-[3px]` | Arbitrary width |
| `border-t` / `border-r` / `border-b` / `border-l` | Directional default-width |
| `border-t-N` / `border-r-N` / `border-b-N` / `border-l-N` | Directional with width |
| `border-{family}-{shade}` / `border-[#hex]` / `border-{family}-{shade}/{N}` | Color (with `dark:` peer required) |
| `border-solid` / `border-none` | Border style (only these two wired; `border-dashed` / `border-dotted` recognised but not rendered) |

Border radius:

| Token | Effect |
|---|---|
| `rounded` | Default radius (4 px) |
| `rounded-{none|sm|md|lg|xl|2xl|3xl|full}` | Preset (none=0, sm=2, md=6, lg=8, xl=12, 2xl=16, 3xl=24, full=9999) |
| `rounded-{t|r|b|l}` | Directional pair (`rounded-t-lg` rounds top corners) |
| `rounded-{tl|tr|bl|br}` | Single corner |
| `rounded-{t|r|b|l|tl|tr|bl|br}-{size}` | Directional/corner + size combos |
| `rounded-[8px]` | Arbitrary |

Ring (Tailwind-style focus ring, implemented as `BoxShadow` with spread only):

| Token | Effect |
|---|---|
| `ring` | Default width (3 px) |
| `ring-N` / `ring-[3px]` | Custom width |
| `ring-{family}-{shade}` / `ring-[#hex]` / `ring-{family}-{shade}/{N}` | Ring color (defaults to blue-500) |
| `ring-offset-N` / `ring-offset-[2px]` | Offset between element and ring |
| `ring-inset` | Inset ring (negative spread) |

---

## 8. Shadow + opacity

Shadow:

| Token | Effect |
|---|---|
| `shadow` | Default preset |
| `shadow-{none|sm|md|lg|xl|2xl}` | Preset elevations |
| `shadow-inner` | Inner shadow |
| `shadow-{family}-{shade}` / `shadow-[#hex]` / `shadow-{family}-{shade}/{N}` | Colored shadow (remaps the preset's BoxShadow color; keeps blur + spread + offset) |

Opacity:

| Token | Effect |
|---|---|
| `opacity-{0|5|10|15|...|95|100}` | Preset percentages (`opacity-50` = 50%) |
| `opacity-[0.5]` / `opacity-[0.75]` | Arbitrary decimal (clamped to 0-1) |

The slash-syntax `/N` modifier applies only to colors, not as a standalone token.

---

## 9. Overflow + aspect-ratio + z-index + order

Overflow:

| Token | Effect |
|---|---|
| `overflow-hidden` / `overflow-visible` / `overflow-scroll` / `overflow-auto` | Uniform |
| `overflow-x-hidden` / `-visible` / `-scroll` / `-auto` | Horizontal |
| `overflow-y-hidden` / `-visible` / `-scroll` / `-auto` | Vertical |

`overflow-hidden` on a box with a border clips at the padding box with the inner radius (each corner's outer radius minus the widths of the two borders that meet there), as CSS does: children never paint over the border, and the box's own `shadow-*` is not clipped.

When `overflow-y-auto` (or any scroll variant) appears, also pass the constructor prop `scrollPrimary: true` on the `WDiv` to enable iOS tap-to-top. No className covers this.

Aspect ratio:

| Token | Effect |
|---|---|
| `aspect-auto` | No constraint |
| `aspect-square` | 1:1 |
| `aspect-video` | 16:9 |
| `aspect-[4/3]` / `aspect-[21/9]` | Arbitrary ratio |

Z-index:

| Token | Effect |
|---|---|
| `z-0` / `z-10` / `z-20` / `z-30` / `z-40` / `z-50` | Preset levels |
| `z-[N]` | Arbitrary signed integer |
| `z-auto` | Clears z-index |

Order: covered in §2.

---

## 10. Typography

`text-*` is overloaded across five property families. Order of resolution: color → align → size → weight → style. Multiple `text-*` tokens coexist if they target different properties.

**Size** (stops at 6xl; `7xl` / `8xl` / `9xl` silently no-op):

| Token | Size |
|---|---|
| `text-xs` | 12 px |
| `text-sm` | 14 px |
| `text-base` | 16 px |
| `text-lg` | 18 px |
| `text-xl` | 20 px |
| `text-2xl` | 24 px |
| `text-3xl` | 30 px |
| `text-4xl` | 36 px |
| `text-5xl` | 48 px |
| `text-6xl` | 60 px |
| `text-[18px]` | Arbitrary |
| `text-[18px]/[24px]` | Arbitrary size AND line-height (slash-separated, both bracketed) |
| `text-xl/8` | Preset size + numeric line-height |

**Color**: `text-{family}-{shade}`, `text-[#hex]` (3, 4, 6 or 8 chars, alpha leading as above), `text-{family}-{shade}/{N}`, `text-transparent`, `text-current` (inherits), `text-inherit`. Needs `dark:` peer.

**Alignment**: `text-left` `text-center` `text-right` `text-justify` `text-start` `text-end` (last two are RTL-aware via `Directionality`).

**Weight**: `font-thin` (100) `font-extralight` (200) `font-light` (300) `font-normal` (400) `font-medium` (500) `font-semibold` (600) `font-bold` (700) `font-extrabold` (800) `font-black` (900). Arbitrary: `font-[100]` through `font-[900]`.

**Style**: `italic` / `not-italic`.

**Decoration**: `underline` / `overline` / `line-through` / `no-underline`. Color: `decoration-{family}-{shade}` / `decoration-[#hex]`. Style: `decoration-solid` / `-double` / `-dotted` / `-dashed` / `-wavy`. Thickness: `decoration-N` / `decoration-[3px]`.

**Transform**: `uppercase` / `lowercase` / `capitalize` / `normal-case`. `capitalize` raises the first letter of EVERY word and leaves the rest as typed (`the HTTP client` -> `The HTTP Client`), matching CSS `text-transform: capitalize`. A word runs through letters, digits, underscores and apostrophes, plus any combining mark or invisible format character attached to them (so decomposed NFD text does not capitalise mid-word, while `U+200B` still breaks the word), and anything else opens a new one: `"quoted words"` -> `"Quoted Words"`, `well-known` -> `Well-Known`, `read/write` -> `Read/Write`, while `3rd party` -> `3rd Party` and `l'orange` -> `L'orange` keep theirs. Casing follows the AMBIENT LOCALE (`Localizations.maybeLocaleOf`), so Turkish and Azerbaijani get the dotted/dotless `i` right: under `Locale('tr')`, `uppercase` on `izleyiciler` is `İZLEYİCİLER` and on `kullanılan` is `KULLANILAN`. With NO `Localizations` ancestor (a bare widget test, or a subtree outside a `MaterialApp`) it falls back to Dart's locale-independent casing.

**Tracking (letter-spacing)**: `tracking-tighter` (-2) / `-tight` (-1) / `-normal` (0) / `-wide` (1) / `-wider` (2) / `-widest` (4). Arbitrary `tracking-[0.5]`.

**Leading (line-height)**: `leading-tight` (1.25) / `-snug` (1.375) / `-normal` (1.5) / `-relaxed` (1.625) / `-loose` (2.0). Arbitrary `leading-[24px]`, numeric `leading-6` (6 × 4 px).

**Overflow**: `truncate` (sets `TextOverflow.ellipsis` + `maxLines: 1` + `softWrap: false`) / `text-ellipsis` (ellipsis only) / `text-clip` (no ellipsis). `line-clamp-N` for multi-line ellipsis. `line-clamp-none` to reset.

**Whitespace / wrap**: `whitespace-normal` / `whitespace-nowrap` / `text-wrap` / `text-nowrap` / `text-balance`.

**Family**: `font-sans` / `font-serif` / `font-mono`. Custom via `WindThemeData.fontFamilies`: `font-{customKey}`. Arbitrary: `font-[CustomName]`.

---

## 11. Transitions + animations

Transition:

| Token | Effect |
|---|---|
| `duration-{75|100|150|200|300|500|700|1000}` | Theme preset (ms) |
| `duration-[500ms]` | Arbitrary |
| `ease-linear` / `ease-in` / `ease-out` / `ease-in-out` | Curve |

**Note**: bare `transition` / `transition-all` / `transition-colors` / `transition-opacity` / `transition-transform` tokens are documented but NOT wired in the parser regex. Pair `duration-N` + `ease-*` to enable transitions on `opacity`, `color`, and `decoration` changes. Wind widgets internally consume `transitionDuration` for `AnimatedOpacity` and similar.

Animation (all infinite loops):

| Token | Effect |
|---|---|
| `animate-spin` | 360° rotation |
| `animate-pulse` | Opacity fade in/out |
| `animate-bounce` | Vertical bounce |
| `animate-ping` | Scale + fade ripple |
| `animate-none` | Reset |

For one-shot or state-driven animations, reach for Flutter's `AnimatedContainer` / `AnimatedOpacity` / `AnimatedSwitcher` directly.

---

## 12. SVG

For `WSvg(src:)` / `WSvg.string(...)`:

| Token | Effect |
|---|---|
| `fill-{family}-{shade}` / `fill-[#hex]` / `fill-{family}-{shade}/{N}` | Apply `ColorFilter(mode: srcIn)` to recolor |
| `fill-none` | Transparent fill |
| `fill-current` | Inherit from `DefaultTextStyle.color` |
| `stroke-{family}-{shade}` / `stroke-[#hex]` / `stroke-{family}-{shade}/{N}` | Stroke color |
| `stroke-none` / `stroke-current` | As above |
| `preserve-colors` | Disable ALL color filtering; render embedded colors unchanged. Use for QR codes, multi-color logos, illustrations. |

`stroke-N` width tokens are reserved but not yet implemented.

For sizing: `w-N` / `h-N` work on `WSvg` and apply via the underlying `SvgPicture`.

---

## 13. Debug token

| Token | Effect |
|---|---|
| `debug` | Sets `WindStyle.debug = true`. Triggers `WindLogger` to log the resolved composition tree + final styles + build time (µs) via `debugPrint`. Visual debug borders are NOT drawn. |

Remove before production. The debug bridge for external tooling (Dusk, Telescope) uses `Wind.installDebugResolver()` instead; see `debug.md`.

---

## 14. Prefixes

All prefixes stack freely with `:`. Prefix order is arbitrary; all stacked prefixes must match for the class to apply.

**Responsive (mobile-first, min-width):**

| Prefix | Default width |
|---|---|
| `sm:` | ≥ 640 px |
| `md:` | ≥ 768 px |
| `lg:` | ≥ 1024 px |
| `xl:` | ≥ 1280 px |
| `2xl:` | ≥ 1536 px |

Custom breakpoints via `WindThemeData.screens`: `{'tablet': 900}` enables `tablet:` prefix.

**Dark mode:** `dark:` activates when `WindThemeData.brightness == Brightness.dark`.

**Platform:** `ios:` `android:` `macos:` `windows:` `linux:` `web:` (specific platform). `mobile:` (true on iOS or Android).

**State (built-in):** `hover:` `focus:` `disabled:` `loading:` `checked:` `error:`. The first two come from `WAnchor`; the others from the widget itself.

**State (custom):** `selected:` `highlighted:` `new:` `pressed:` `expanded:`, or any string. Pass via `states: Set<String>?`. No registration required.

NOT supported as prefixes:
- `active:` (reserved, not wired; WAnchor tracks hover and focus only)
- `group-hover:` / `peer-focus:` / `first:` / `last:` / `odd:` / `even:` / `before:` / `after:` / `focus-within:` / `focus-visible:`
- `@container` / `@sm:` (container queries), viewport-only

---

## 15. Arbitrary values

Bracket syntax `[VALUE]` for one-off pixel-exact values where the theme scale does not fit.

| Family | Bracket syntax | Examples |
|---|---|---|
| Padding | `p-[N]` `pt-[N]` `px-[N]` | `p-[18px]`, `pt-[5]`, `px-[3.5]`. NO `%`. |
| Margin | `m-[N]` `mt-[N]` `mx-[N]` | Same shape. NO `%`. No negatives. |
| Gap | `gap-[N]` `gap-x-[N]` `space-y-[N]` | Same shape. |
| Sizing | `w-[N]` `h-[N]` `min-w-[N]` `max-h-[N]` | `w-[300px]`, `h-[50%]`. BOTH `px` AND `%` supported. |
| Position offsets | `top-[N]` `left-[N]` `-inset-[N]` | `top-[24px]`. NO `%`. Negative prefix `-` works. |
| Aspect ratio | `aspect-[N/M]` | `aspect-[4/3]`, `aspect-[21/9]` |
| Colors | `bg-[#hex]` `text-[#hex]` `border-[#hex]` `shadow-[#hex]` `ring-[#hex]` `fill-[#hex]` `stroke-[#hex]` | 3, 4, 6, or 8 hex digits with `#` |
| Color opacity | `{token}/{N}` | `bg-red-500/50`, `text-blue-300/75`. N is 0-100. |
| Border width | `border-[N]` | `border-[3px]` |
| Border radius | `rounded-[N]` | `rounded-[8px]` |
| Ring width | `ring-[N]` | `ring-[3px]` |
| Ring offset | `ring-offset-[N]` | `ring-offset-[2px]` |
| Font size | `text-[N]` / `text-[N]/[M]` | `text-[18px]`, `text-[18px]/[24px]` |
| Font weight | `font-[N]` | `font-[450]` |
| Tracking | `tracking-[N]` | `tracking-[0.5]` |
| Leading | `leading-[N]` | `leading-[24px]`, `leading-6` |
| Decoration thickness | `decoration-[N]` | `decoration-[3px]` |
| Duration | `duration-[Nms]` | `duration-[450ms]` |
| Z-index | `z-[N]` | `z-[100]`, `z-[-1]` |
| Order | `order-[N]` | `order-[-5]` |
| Opacity | `opacity-[N]` | `opacity-[0.5]` (0-1 decimal) |

Arbitrary values bypass theme lookup (matched BEFORE theme resolution). They are pixel-exact; theme keys are nominal.

---

## 16. Cursor (web / desktop)

`cursor-*` sets the mouse cursor over an element via a `MouseRegion` that `WDiv` adds when a cursor token is present. Pointer-only: inert on touch platforms. Last token wins; an unknown `cursor-*` name is a silent no-op.

| Token | Flutter `SystemMouseCursors` |
|-------|------------------------------|
| `cursor-auto` / `cursor-default` | `basic` (no "auto" cursor in Flutter) |
| `cursor-pointer` | `click` |
| `cursor-wait` / `cursor-progress` | `wait` / `progress` |
| `cursor-text` / `cursor-vertical-text` | `text` / `verticalText` |
| `cursor-move` / `cursor-all-scroll` | `move` / `allScroll` |
| `cursor-help` / `cursor-context-menu` | `help` / `contextMenu` |
| `cursor-not-allowed` / `cursor-no-drop` | `forbidden` / `noDrop` |
| `cursor-none` | `none` |
| `cursor-cell` / `cursor-crosshair` | `cell` / `precise` |
| `cursor-alias` / `cursor-copy` | `alias` / `copy` |
| `cursor-grab` / `cursor-grabbing` | `grab` / `grabbing` |
| `cursor-zoom-in` / `cursor-zoom-out` | `zoomIn` / `zoomOut` |
| `cursor-col-resize` / `cursor-row-resize` | `resizeColumn` / `resizeRow` |
| `cursor-ew-resize` / `cursor-ns-resize` | `resizeLeftRight` / `resizeUpDown` |
| `cursor-nesw-resize` / `cursor-nwse-resize` | `resizeUpRightDownLeft` / `resizeUpLeftDownRight` |
| `cursor-{n,e,s,w}-resize` | `resize{Up,Right,Down,Left}` |
| `cursor-{ne,nw,se,sw}-resize` | `resize{UpRight,UpLeft,DownRight,DownLeft}` |

On a `WDiv` that also carries `hover:` / `focus:` / `active:` (so it auto-wraps in `WAnchor`, whose `MouseRegion` uses `click` only when the anchor has gesture callbacks, otherwise `basic`), the `cursor-*` `MouseRegion` is deeper in the tree and wins regardless of the anchor's default.

## 17. Tokens that look real but are not wired

If a token from Tailwind v3 / v4 muscle memory does not seem to do anything, it is probably in this list. Wind drops them silently.

**Layout / flex:**
- `flex-nowrap` (default; omit `wrap`)
- `flex-wrap-reverse`

(`flex-wrap` is NOT in this list: it is aliased to `wrap` and resolves, printing a one-time `kDebugMode` hint that points at the canonical `wrap`.)

**Spacing:**
- `ps-N` / `pe-N` / `ms-N` / `me-N` (logical inline-start/end)
- `-m-N` / `-mt-N` etc. (negative margins)
- `p-[10%]` or any `%` for padding / margin

**Sizing:**
- `w-auto` / `h-auto`
- `max-w-none`
- `w-min` / `w-max` / `w-fit`

**Position:**
- `fixed` / `sticky` (parser recognises but no visual effect)
- `top-[50%]` and any `%` for positioning

**Border:**
- `border-x` / `border-y` (axis shortcuts NOT wired; only `border-t` / `border-r` / `border-b` / `border-l` directional, plus bare `border` uniform). Set the two physical sides explicitly.
- `border-dashed` / `border-dotted` (parser recognises, no visual)
- `divide-x-N` / `divide-y-N` (use explicit spacing instead)

**Effects:**
- `filter` / `blur-*` / `brightness-*` / `contrast-*` / `grayscale-*` / `hue-rotate-*` / `invert-*` / `saturate-*` / `sepia-*` / `drop-shadow-*` / `backdrop-blur-*` / `backdrop-*`
- `mix-blend-*` / `bg-blend-*`

**Interactivity:**
- `pointer-events-none`
- `select-none` / `select-text`
- `scroll-smooth`
- `snap-*` (scroll snap)
- `touch-*`
- `appearance-none`
- `will-change-*`
- `caret-*`
- `accent-*`

**Typography (Wind size cap is 6xl):**
- `text-7xl` / `text-8xl` / `text-9xl`
- `whitespace-pre` / `-pre-line` / `-pre-wrap` / `-break-spaces` (only `whitespace-normal` and `whitespace-nowrap` wired)
- `hyphens-*`
- `indent-*`
- `list-disc` / `list-decimal` / `list-none`
- `align-baseline` / `-top` / `-middle` / `-bottom` (use Flutter `crossAxisAlignment` instead)

**Transitions / animations:**
- Bare `transition` / `transition-all` / `transition-colors` / `transition-opacity` / `transition-transform` (only `duration-*` + `ease-*` wire)
- `delay-N` (recognised but not wired)
- `motion-safe:` / `motion-reduce:`

**Transforms:**
- `scale-N` / `scale-x-*` / `scale-y-*`
- `rotate-N` / `rotate-x-*` / `rotate-y-*`
- `translate-x-*` / `translate-y-*`
- `skew-x-*` / `skew-y-*`
- `origin-*`
- `transform-gpu` / `transform-none`
- `perspective-*`

**State variants:**
- `group-*` / `peer-*`
- `first:` / `last:` / `odd:` / `even:` / `first-of-type:` / `empty:` / `open:`
- `before:` / `after:` (no pseudo-elements)
- `selection:` / `placeholder:` / `marker:` / `file:`
- `motion-safe:` / `motion-reduce:` / `print:`
- `focus-within:` / `focus-visible:`
- `active:` (reserved, no wiring)

**Container queries:** `@container`, `@sm:`, `@md:`, `@lg:`, `@max-md:`, named containers like `@sm/sidebar:`.

**Important modifier:** `!flex` (v3 prefix), `flex!` (v4 suffix); neither parsed.

**Tailwind CSS-only:**
- `@apply` / `@layer` / `@variant` / `@theme` directives
- `bg-opacity-N` / `text-opacity-N` / `border-opacity-N` (v3 legacy; use `/N` slash modifier)

When a token from this list appears in a className, no error fires; it is dropped, the build continues, and missing styling is the only signal. Audit by hand.

### Recognised as deliberate no-ops (no debug hint)

Everything above is dropped AND, when no parser claims its family, named by the one-time `kDebugMode` hint. The tokens below are dropped too, but the parser knows them and stays silent: they exist in Tailwind muscle memory or in Wind's own widget docstrings, so warning about them would train the agent to ignore the hint.

- `transition` / `transition-all` / `transition-colors` / `transition-transform` / `transition-opacity` / `transition-shadow` / `transition-none`
- `antialiased` / `subpixel-antialiased` (font smoothing has no Flutter equivalent)
- `sr-only` / `not-sr-only` (use `Semantics` / `ExcludeSemantics` instead)
- `normal-nums`, `ordinal`, `slashed-zero`, `lining-nums`, `oldstyle-nums`, `proportional-nums`, `tabular-nums`, `diagonal-fractions`, `stacked-fractions` (font-variant-numeric)
- `inline` / `inline-flex` / `inline-block` (inline display has no layout meaning in Flutter; `WBadge` emits `inline-flex` in its default className)

One family is silent for the opposite reason: `object-cover`, `object-contain`, `object-fill`, `object-none`, and `object-scale-down` never reach `WindStyle`, but `WImage` reads them straight off the className, so they DO change rendering (`object-cover` is the default). Write them on `WImage` and nowhere else.
