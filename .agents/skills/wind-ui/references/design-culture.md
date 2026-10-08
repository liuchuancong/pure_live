# Wind 1.5: Design culture

Taste, expressed as className tokens. Every other reference file answers "does this token exist and what does it do"; this one answers "which token should this be". Reach for it when the task is a screen or a component with no design spec attached, when a layout renders correctly and still looks wrong, or when a reviewer says "it works but it feels off".

The rules below are the iOS Human Interface Guidelines and common product-design practice, translated into Wind tokens. They are defaults with reasons, not laws: a deliberate departure with a reason is fine, an accidental one is what this file prevents.

## Contents

1. [Before the first widget](#1-before-the-first-widget)
2. [Visual hierarchy](#2-visual-hierarchy)
3. [Color](#3-color)
4. [Typography](#4-typography)
5. [Spacing and layout](#5-spacing-and-layout)
6. [Depth](#6-depth)
7. [Mobile patterns](#7-mobile-patterns)
8. [Navigation](#8-navigation)
9. [Anti-patterns](#9-anti-patterns)

## 1. Before the first widget

Three HIG pillars carry most of the weight:

1. **Clarity.** Readable text at every size. Hierarchy comes from spacing, color, and weight. Decoration is the last resort.
2. **Deference.** Content fills the screen, chrome gets out of the way. No decorative shadows.
3. **Depth.** Layered surfaces and motion that reinforces spatial relationships.

Four questions, answered before writing markup:

| Question | What it settles |
|:---------|:----------------|
| Purpose | What problem does this screen solve, and for whom? |
| Tone | One direction, committed to fully (table below) |
| Constraints | Framework limits, performance budget, accessibility floor |
| Differentiation | The ONE memorable thing about this interface |

| Tone | Character |
|:-----|:----------|
| Brutally minimal | Maximum whitespace, a single accent, stark contrast |
| Luxury / refined | Generous spacing, muted palette, thin typography |
| Playful | Rounded corners, bright accents, bouncy motion |
| Editorial | Strong type hierarchy, grid discipline, dramatic imagery |
| Soft / pastel | Low saturation, gentle gradients, warm neutrals |

Work in this order: core functionality before the shell, grayscale until the hierarchy reads, systems before details. A screen that works in grayscale works in color; the reverse is not true.

## 2. Visual hierarchy

Every element sits at one of three levels.

| Level | Weight | Color | Usage |
|:------|:-------|:------|:------|
| Primary | 600-700 | Darkest neutral | Headlines, key values. One per section. |
| Secondary | 400-500 | Mid grey | Supporting text, descriptions |
| Tertiary | 400 | Light grey | Metadata, timestamps, legal |

The type scale that implements it:

| Role | className |
|:-----|:----------|
| Page title | `text-2xl font-bold text-gray-900 dark:text-white` |
| Screen heading | `text-xl font-semibold text-gray-800 dark:text-gray-100` |
| Section heading | `text-lg font-semibold text-gray-800 dark:text-gray-100` |
| Body | `text-base text-gray-700 dark:text-gray-300` |
| Secondary / caption | `text-sm text-gray-500 dark:text-gray-400` |
| Form label | `text-sm font-medium text-gray-700 dark:text-gray-300` |
| Uppercase section label | `text-xs font-bold uppercase tracking-wide text-gray-500 dark:text-gray-400` |
| Metadata / timestamp | `text-xs text-gray-400 dark:text-gray-500` |
| Inline link | `text-sm text-primary hover:underline` |
| Error text | `text-sm text-red-600 dark:text-red-400` |

Four habits that separate a designed screen from a styled one:

- **Reach for weight and color before size.** Size is the last lever, not the first.
- **Emphasize by de-emphasizing.** Soften what competes instead of shouting louder.
- **Give icons softer colors than their neighbouring text.** A glyph is visually heavier than a word at the same size: `text-gray-400` for decorative, `text-primary` for active.
- **Avoid a second primary.** Exactly one element per section carries `text-gray-900 dark:text-white font-bold`.

Labels are a last resort; fold them into the value. "12 left in stock" beats "Stock: 12".

| Button level | Style | Rule |
|:-------------|:------|:-----|
| Primary | Solid, high-contrast fill | One per section, maximum |
| Secondary | Outline or low-contrast fill | Visible, not competing |
| Tertiary | Reads like a link | Discoverable, unobtrusive |

Destructive actions are big and red on a confirmation dialog only. On a regular screen they take tertiary styling, with Cancel beside them.

## 3. Color

`primary` is a seeded Wind token (aliased to the blue swatch), so `bg-primary` / `text-primary` / `border-primary` resolve with no registration and re-brand in one place through `WindThemeData.colors`. Prefer it over a literal `blue-600` for anything brand-carrying.

| Meaning | Background | Text | Border |
|:--------|:-----------|:-----|:-------|
| Primary / brand | `bg-primary` | `text-primary` | `border-primary` |
| Success | `bg-green-500` | `text-green-600 dark:text-green-400` | `border-green-500` |
| Warning | `bg-yellow-500` | `text-yellow-600 dark:text-yellow-400` | `border-yellow-500` |
| Error | `bg-red-500` | `text-red-600 dark:text-red-400` | `border-red-500` |
| Info | `bg-blue-500` | `text-blue-600 dark:text-blue-400` | `border-blue-500` |
| Neutral | `bg-gray-500` | `text-gray-500 dark:text-gray-400` | `border-gray-300` |

Mapped from the iOS system palette:

| Role | iOS color (light / dark) | Wind token |
|:-----|:-------------------------|:-----------|
| Primary | systemBlue #007AFF / #0A84FF | `bg-primary`, `text-primary` |
| Success | systemGreen #34C759 / #30D158 | `bg-green-500`, `text-green-600` |
| Error | systemRed #FF3B30 / #FF453A | `bg-red-500`, `text-red-600` |
| Warning | systemOrange #FF9500 / #FF9F0A | `bg-yellow-500`, `text-yellow-600` (this file's warning tone; reach for `bg-orange-500` when you want the literal iOS hue) |
| Premium | systemPurple #AF52DE / #BF5AF2 | `bg-purple-500`, `text-purple-600` |
| Info | systemTeal #5AC8FA / #64D2FF | `bg-blue-500`, `text-blue-600` |

Status pills, the tinted-background pattern:

| Status | className |
|:-------|:----------|
| Active / online | `bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400` |
| Degraded | `bg-yellow-100 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-400` |
| Down | `bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400` |
| Paused | `bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400` |
| Pending | `bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-400` |

Surface pairs, so a dark-mode peer is never invented on the spot:

| Light | Dark | Use case |
|:------|:-----|:---------|
| `bg-white` | `dark:bg-gray-900` | App background |
| `bg-gray-50` | `dark:bg-gray-800` | Card / surface |
| `bg-gray-100` | `dark:bg-gray-700` | Hover state |
| `bg-gray-200` | `dark:bg-gray-600` | Disabled / skeleton |
| `text-gray-900` | `dark:text-white` | Primary text |
| `text-gray-600` | `dark:text-gray-300` | Body text |
| `text-gray-500` | `dark:text-gray-400` | Secondary text |
| `text-gray-400` | `dark:text-gray-500` | Placeholder / muted |
| `border-gray-200` | `dark:border-gray-700` | Standard border |
| `border-gray-300` | `dark:border-gray-600` | Input border |

In dark mode, lighter means higher: `gray-900` base, `gray-800` surface, `gray-700` elevated. That is the inverse of the light-mode instinct and the most common dark-mode mistake.

**Building a custom family.** Decide in HSL; hex is storage, not a design tool. Pick 500 first (it has to work as a button background), then the edges (900 for dark text on light fills, 100 for tinted backgrounds), then fill 700 and 300, then the rest. Increase saturation as lightness moves away from 50%. Lighten by rotating hue toward 60 / 180 / 300 degrees, darken by rotating toward 0 / 120 / 240, never more than 20 to 30 degrees. For greys, saturate toward blue for cool and toward yellow for warm; true black reads unnatural, so use a very dark grey.

**Contrast floor.** 4.5:1 for body text, 3:1 for large text (bold 18sp+ or regular 24sp+). Color is never the only channel: pair it with an icon, a label, or a shape.

## 4. Typography

| iOS style | Size | Weight | Wind equivalent |
|:----------|:-----|:-------|:----------------|
| Large Title | 34pt | Bold | `text-2xl font-bold` |
| Title 1 | 28pt | Regular | `text-xl` |
| Title 2 | 22pt | Regular | `text-lg` |
| Headline | 17pt | Semibold | `text-base font-semibold` |
| Body | 17pt | Regular | `text-base` |
| Subheadline | 15pt | Regular | `text-sm` |
| Caption | 12pt | Regular | `text-xs` |

`text-xs` (12px) is the floor. Nothing goes below it, including timestamps and legal text.

Line height rises as text gets smaller and as measure gets wider: `leading-relaxed` for small print, `leading-tight` for headlines. Letter spacing tightens for headlines (`tracking-tight`) and opens for all-caps labels (`tracking-wide`). Align left by default; centre only headlines and blocks under three lines; right-align numbers in a column so digits line up.

## 5. Spacing and layout

| Step | Token | Use case |
|:-----|:------|:---------|
| Micro | `gap-1` / `p-1` (4px) | Icon to text, badge padding |
| XSmall | `gap-2` / `p-2` (8px) | Tightly related items |
| Small | `gap-3` / `p-3` (12px) | Button padding, the touch-target floor |
| Base | `gap-4` / `p-4` (16px) | Standard screen padding, item spacing |
| Medium | `gap-5` / `p-5` (20px) | Card padding |
| Large | `gap-6` / `p-6` (24px) | Between sections |
| XLarge | `gap-8` / `p-8` (32px) | Major separation |
| 2XLarge | `gap-12` / `p-12` (48px) | Page-level separation |

Touch targets, the rule most often broken:

| Element | Minimum | Recommended | Why |
|:--------|:--------|:------------|:----|
| Text button | `py-3 px-4` | `py-3.5 px-5` | Lands near the 44dp iOS floor |
| Icon-only button | `p-3` | `p-3.5` | 12px padding + 24px glyph = 48dp |
| List row | `py-3 px-4` | `py-4 px-4` | 48dp tap area |
| Toggle / checkbox | `p-2` | `p-3` | Keeps it above 40dp |
| FAB | `p-4` | `p-4` | 56dp |

Never `p-1` or `py-1` on anything interactive.

Four spacing habits:

- **Start with too much whitespace and remove.** "A little too much" in isolation reads as "just enough" in context.
- **Do not fill the screen.** If the content needs 300dp, give it 300dp and let the rest breathe.
- **More space between groups than within them.** `gap-6` between sections, `gap-2` inside one. Ambiguous grouping is a hierarchy bug.
- **Large elements shrink faster than small ones** across breakpoints. Scale a hero, not a caption.

iOS layout values worth memorising: 16pt standard margin on compact (`p-4`), 20pt on regular (`p-5`), 8pt intra-group (`gap-2`), 20pt section (`gap-5`), 44x44pt minimum touch area.

**Concentric radii.** A nested corner follows `inner = parent - padding`: a `rounded-2xl` card with `p-4` needs a visibly smaller radius inside, not the same one. Use `rounded-full` for elements that sit against an iPhone's rounded edge. Centre optically rather than mathematically when a shape has visual weight on one side.

**Fewer borders.** A screen full of borders reads busy. Prefer a background shift, a shadow, or more space:

| Effect | When | className |
|:-------|:-----|:----------|
| Border only | Flat design, dividers | `border border-gray-200 dark:border-gray-700` |
| Background shift | Subtle elevation | `bg-white dark:bg-gray-800` on a `bg-gray-50 dark:bg-gray-900` base |
| Shadow + border | Cards, interactive surfaces | `shadow-sm border border-gray-100 dark:border-gray-700` |
| Shadow only | Overlays, floating elements | `shadow-lg` |

## 6. Depth

| Token | Use case |
|:------|:---------|
| `shadow-sm` | Subtle card lift, input fields |
| `shadow` | Standard cards and buttons |
| `shadow-md` | Raised cards, dropdowns, hover states |
| `shadow-lg` | Modals, popovers |
| `shadow-xl` | Dialogs, highest-emphasis surfaces |
| `shadow-none` | Reset |

Colored shadow for brand emphasis: `shadow-lg shadow-primary/20`.

Light comes from above. A raised element gets a lighter top edge and a shadow below; an inset element gets a lighter bottom edge and a shadow above. Dragging increases the shadow, pressing decreases it. Depth also works with no shadow at all: lighter than the background reads raised, darker reads inset.

The iOS register is restrained: soft shadows, blur, minimal elevation. For a premium feel, combine one large soft shadow (direct light) with one tight dark shadow (ambient occlusion).

## 7. Mobile patterns

**Forms.** Full-width inputs with horizontal padding, label above or floating, helper text below, error as a colored border plus a message, primary action full-width at the bottom. Wiring and validation live in `references/forms.md`.

**Loading and empty.** Skeletons over spinners, always: a shimmering placeholder of the real layout reads as fast, a spinner reads as stalled. Pull to refresh on lists. An empty state is a first impression, so it earns an illustration, a title, a description, and one CTA, with irrelevant chrome hidden.

**Feedback.** Match the weight of the interruption to the weight of the message:

| Surface | Use case |
|:--------|:---------|
| Snackbar | Transient confirmation, optional undo |
| Dialog | A decision is genuinely required |
| Bottom sheet | Several options to pick from |

**Lists.** Plain (`flex flex-col` with dividers), grouped (section headers on a tinted background), or inset grouped (`mx-4 rounded-xl` on a card surface). Row height stays at or above 44pt. Support pull-to-refresh and swipe-to-delete where the data allows it.

## 8. Navigation

| Pattern | When | Rules |
|:--------|:-----|:------|
| Tab bar | 3 to 5 top-level sections | Persists everywhere, never hidden mid-flow, never switched programmatically |
| Hierarchical push | Parent to detail | Back button names the previous screen, tab bar stays visible, a chevron promises a push |
| Modal sheet | A focused task | Presents from the bottom, always has an explicit dismiss (Cancel / Done / swipe) |

Stack at most one modal. Disable swipe-to-dismiss while there is unsaved data. In a modal nav bar: title centred, the action right and phrased as a bold verb, Cancel left, and the action disabled until the required fields are filled.

App bars come in three shapes: standard (title plus actions), search (an integrated field), and collapsing (a hero that shrinks into a title). The leading icon carries a promise: hamburger opens a drawer, back arrow pops, X dismisses a modal.

| Gesture | Expected behavior |
|:--------|:------------------|
| Tap | Activate a control, select an item |
| Horizontal swipe | Navigate back, reveal a destructive action |
| Long press | Context menu, reorder mode |
| Drag | Move an element, scroll content |

Never override a system gesture (the bottom and top screen edges). A shortcut gesture supplements a visible control, it never replaces one.

## 9. Anti-patterns

| Mistake | Fix |
|:--------|:----|
| Touch target under 44dp | `py-3 px-4` minimum on anything interactive |
| Status conveyed by color alone | Add an icon or a text label |
| Hardcoded hex in UI chrome | `bg-primary`, `text-gray-900`, and the surface pairs above |
| Missing dark peer | `bg-white dark:bg-gray-900`, on the same line (Core Law 2) |
| Modal with no dismiss | Cancel / Done plus swipe-to-dismiss |
| Horizontal scroll on a primary screen | Fit the layout to the viewport |
| Type below 12px | `text-xs` is the floor |
| Tab bar hidden mid-navigation | Keep it visible across pushed screens |
| Destructive action styled as the primary button | Red with a Cancel beside it, on a confirmation surface only |
| Grey text on a colored background | Hand-pick a hue-matched tint instead |
| Sparse content stretched to fill the screen | Constrain the width, let it breathe |
| Group spacing that reads ambiguously | `gap-6` between groups, `gap-2` within |
| Safe area ignored | Respect the notch and the home indicator |
| Two primaries in one section | One `font-bold` darkest-neutral element, soften the rest |
