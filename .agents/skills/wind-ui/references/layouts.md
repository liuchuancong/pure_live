# Wind 1.5: Layouts

12+ canonical layout recipes plus the Flutter constraint model that drives every overflow. Reach for this file when picking a layout pattern or recovering from RenderFlex / unbounded-height assertions.

## Contents

1. [The Flutter constraint model](#1-the-flutter-constraint-model)
2. [Assertion-to-fix mapping](#2-assertion-to-fix-mapping)
3. [Layout recipes](#3-layout-recipes)
4. [Scrolling: scrollPrimary, nested scrolls, infinite-height pitfalls](#4-scrolling-scrollprimary-nested-scrolls-infinite-height-pitfalls)
5. [Stack + absolute positioning](#5-stack--absolute-positioning)
6. [Text truncation + min-w-0](#6-text-truncation--min-w-0)
7. [items-stretch inside a scroll](#7-items-stretch-inside-a-scroll)
8. [Touch targets](#8-touch-targets)
9. [Responsive cascade examples](#9-responsive-cascade-examples)

---

## 1. The Flutter constraint model

> Constraints down. Sizes up. Parent sets position.

Every `RenderBox` receives a `BoxConstraints` (`minWidth`, `maxWidth`, `minHeight`, `maxHeight`) from its parent, lays out each child with derived constraints, then picks a `Size` that satisfies its own incoming constraints. The parent alone decides where in space each child goes.

Four consequences drive almost every Wind layout footgun:

1. **`Row` and `Column` pass UNBOUNDED constraints to non-flex children in step 1.** A child that responds with `double.infinity` (e.g. `h-full` inside a Column inside a scroll) blows up the parent's bounded layout. `flex-1` is the canonical fix because it moves the child to step 2 (bounded share of remaining space). (A bare `w-full` on a direct Row child is auto-handled: Wind wraps it in `Expanded` so it behaves as `flex-1` instead of asserting; prefer `flex-1` for clarity.)

2. **Scrollables remove the max on their axis.** A `SingleChildScrollView` (Wind's `overflow-y-auto`) passes `maxHeight: double.infinity` to its child. A child that asserts on finite height (`Column` with `Expanded` children) throws "Vertical viewport was given unbounded height".

3. **`flex flex-col` stretches `WDiv`, `WAnchor` (any child), and `WButton` children to the column width by default.** With NO explicit `items-*` token, each such child that does not control its own width is wrapped in `SizedBox(width: double.infinity)`, mirroring CSS `align-items: stretch`. For `WAnchor`: when the anchor wraps a `WDiv`, the inner `WDiv`'s className decides; when it wraps a `WText` or raw widget, it always stretches. Left untouched: children with an explicit width (`w-*` / `min-w-*` / `max-w-*` / `w-full`, in any state/breakpoint variant), children that self-wrap in `Expanded`/`Flexible` (`grow`, `flex-grow`, `flex-auto`, `flex-initial`, `shrink`, `flex-shrink`, `flex-N`), absolute children, bare `WText` leaves, and raw Flutter widgets. `shrink-0` / `flex-none` children still stretch on the cross axis: `flex-shrink` is main-axis only, matching CSS. Add any `items-*` token (e.g. `items-start`) to disable the stretch and let children size to content. This is column-only; rows are never auto-stretched on the cross axis.

4. **`justify-*` on a row wraps every child in a `Flexible` so it can shrink, UNLESS a child claims a grow share.** Flutter splits free space equally between flex children, so the shrink wrap also hands a share to a sibling that never asked for one: a `justify-between` row holding a `flex-1` title next to a 24 px icon split 400 px down the middle and rendered the title at 200 px. A grow claim (`flex-1`, `flex-{n}`, `grow`, `flex-grow`, `flex-auto`, a bare `w-full`, or a raw `Expanded` / `Flexible`) therefore turns the wrap off for the whole row: the growing child takes the remainder, its siblings keep their content width, and that matches CSS `justify-content: space-between`. `overflow-hidden` keeps the wrap unconditionally (it asks for shrinking on purpose), `shrink` / `flex-shrink` / `flex-initial` are not a grow claim, and neither is a PREFIXED grow token: `hover:flex-1` and `md:grow` are conditional, so they never speak for the row. Reach for an unprefixed `flex-1` when you want the child to own the remainder.

Memorize these and the rest follows.

---

## 2. Assertion-to-fix mapping

When Flutter throws, map the error to a Wind-shaped fix.

| Assertion | Cause | Fix |
|---|---|---|
| `A RenderFlex overflowed by N pixels` | Sum of non-flex children exceeds the Row/Column's bounded constraint. | Wrap the offending child in `WDiv(className: 'flex-1', child: ...)` (a bare `w-full` Row child is already auto-treated as `flex-1`) |
| `RenderFlex children have non-zero flex but incoming width/height constraints are unbounded` | `flex-1` or `Expanded` inside a parent that does not constrain the main axis (typically a `SingleChildScrollView`) | Either remove the `flex-1` from the child or give the parent a bounded size (`h-screen`, fixed `h-N`, or `min-h-screen`) |
| `An InputDecorator cannot have an unbounded width` | `WFormInput` / `TextField` in a Row without `flex-1` or fixed width | Wrap in `WDiv(className: 'flex-1', child: WFormInput(...))` |
| `Vertical viewport was given unbounded height` | `SingleChildScrollView` (or any vertical scrollable) inside an unbounded parent, typically a `Column` outside a `Scaffold` | Wrap the scroll's ancestor in a fixed-height container, or wrap the chain in `Scaffold(body: ...)` |
| `BoxConstraints forces an infinite width/height` | A widget requiring tight constraints (`SizedBox.expand`) received `double.infinity` from its parent | Constrain the parent (`max-w-*`, fixed `w-N`) |
| `RenderBox was not laid out` | Secondary error; look earlier in the trace for the primary constraint violation | Fix the earlier assertion; this one cascades |
| `A Positioned widget must be a descendant of a Stack` | `absolute` token without a `relative` ancestor | Wrap the parent in `WDiv(className: 'relative ...', children: [..., WDiv(className: 'absolute ...')])` |

---

## 3. Layout recipes

### Centered card

```dart
WDiv(
  className: '''
    mx-auto max-w-md p-6
    bg-white dark:bg-gray-800
    rounded-lg shadow-sm
  ''',
  child: ...,
);
```

### Vertical stack

```dart
WDiv(
  className: 'flex flex-col gap-4',
  children: [..., ..., ...],
);
```

### Horizontal stack with leading icon and trailing badge

```dart
WDiv(
  className: 'flex flex-row items-center gap-3',
  children: [
    WIcon(Icons.alarm_outlined, className: 'text-gray-500'),
    WDiv(
      className: 'flex-1 min-w-0',          // min-w-0 lets truncate work
      child: WText('Long title that may need to truncate', className: 'truncate'),
    ),
    WDiv(
      className: '''
        rounded-full px-2 py-0.5
        bg-blue-100 dark:bg-blue-900
        text-blue-700 dark:text-blue-200
        text-xs font-medium
      ''',
      child: const WText('NEW'),
    ),
  ],
);
```

### Responsive grid 1 → 2 → 3 columns

```dart
WDiv(
  className: 'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4',
  children: cards,
);
```

Note: Wind's `grid` renders as `Wrap` with computed column widths; it is NOT virtualized. For large or dynamic item counts, use Flutter's `GridView.builder` with W-widgets inside. Add `items-stretch` for equal-height rows (cells match the tallest per row via a real-layout equal-height row, NOT `IntrinsicHeight`, so cells containing a `flex flex-col`, `h-full`, or `basis-*` stretch without the intrinsic-sizing assert; #139).

### Sticky header + scrollable body

```dart
WDiv(
  className: 'flex flex-col h-full',
  children: [
    WDiv(
      className: 'flex-shrink-0 p-4 border-b border-gray-200 dark:border-gray-700',
      child: const WText('Header', className: 'text-lg font-semibold'),
    ),
    WDiv(
      className: 'flex-1 overflow-y-auto p-4',
      scrollPrimary: true,                  // iOS tap-to-top
      child: ...long content...,
    ),
  ],
);
```

The parent has `h-full` so the body's `flex-1` has bounded vertical space. Skipping the parent height triggers unbounded-height.

### Full-page scroll

```dart
WDiv(
  className: 'w-full h-full overflow-y-auto p-4',
  scrollPrimary: true,
  child: WDiv(
    className: 'flex flex-col gap-6 max-w-2xl mx-auto',
    children: [...],
  ),
);
```

### Hide on mobile, show on desktop

```dart
WDiv(className: 'hidden md:flex flex-row gap-4', children: [...]);
WDiv(className: 'md:hidden', child: ...);                    // shown only below md
```

### Gradient header banner

```dart
WDiv(
  className: '''
    bg-gradient-to-br from-indigo-600 to-purple-600
    dark:from-indigo-500 dark:to-purple-500
    p-8 rounded-2xl
  ''',
  child: WText('Welcome', className: 'text-3xl font-bold text-white'),
);
```

### Toggle / chip with selected state

```dart
WDiv(
  className: '''
    rounded-full px-4 py-2 border
    border-gray-300 dark:border-gray-600
    bg-white dark:bg-gray-800
    text-gray-700 dark:text-gray-200
    hover:bg-gray-50 dark:hover:bg-gray-700
    selected:border-blue-500 selected:bg-blue-50 selected:text-blue-700
    dark:selected:border-blue-400 dark:selected:bg-blue-950 dark:selected:text-blue-200
  ''',
  states: isSelected ? const {'selected'} : const {},
  child: WText(label),
);
```

### Disabled secondary action

```dart
WButton(
  disabled: !canProceed,
  onTap: _proceed,
  className: '''
    px-4 py-2 rounded-lg
    bg-gray-200 hover:bg-gray-300
    dark:bg-gray-700 dark:hover:bg-gray-600
    text-gray-700 dark:text-gray-200
    disabled:opacity-50 disabled:cursor-not-allowed
  ''',
  child: const Text('Continue'),
);
```

### Loading button

```dart
WButton(
  isLoading: _isSubmitting,
  onTap: _submit,
  loadingText: 'Saving...',
  className: '''
    px-6 py-3 rounded-lg
    bg-blue-600 hover:bg-blue-700
    dark:bg-blue-500 dark:hover:bg-blue-600
    loading:bg-blue-400
    text-white
  ''',
  child: const Text('Save'),
);
```

### Avatar with fallback icon

```dart
WImage(
  src: user.avatarUrl,
  className: '''
    w-12 h-12 rounded-full object-cover
    bg-gray-100 dark:bg-gray-700
  ''',
  errorBuilder: (_, __, ___) => WDiv(
    className: '''
      w-12 h-12 rounded-full
      bg-gray-100 dark:bg-gray-700
      flex items-center justify-center
    ''',
    child: WIcon(Icons.person_outlined, className: 'text-gray-400 dark:text-gray-500'),
  ),
);
```

### Popover menu

```dart
WPopover(
  alignment: PopoverAlignment.bottomRight,
  className: '''
    w-56 rounded-lg shadow-xl border
    border-gray-200 dark:border-gray-700
    bg-white dark:bg-gray-800
  ''',
  triggerBuilder: (context, isOpen, isHovering) => WButton(
    className: '''
      p-2 rounded-lg
      hover:bg-gray-100 dark:hover:bg-gray-700
    ''',
    child: const WIcon(Icons.more_horiz_outlined),
  ),
  contentBuilder: (context, close) => WDiv(
    className: 'flex flex-col py-1',
    children: [
      _menuItem('Edit', Icons.edit_outlined, () { close(); _edit(); }),
      _menuItem('Delete', Icons.delete_outline_outlined, () { close(); _delete(); }),
    ],
  ),
);
```

### Per-breakpoint widget swap

```dart
WBreakpoint(
  base: (_) => const MobileLayout(),
  md: (_) => const TabletLayout(),
  lg: (_) => const DesktopLayout(),
);
```

Use when className prefixes (`hidden md:flex`) cannot express the change (different widget hierarchies, not just different styles).

---

## 4. Scrolling: scrollPrimary, nested scrolls, infinite-height pitfalls

`overflow-y-auto` (or any scroll variant) on a `WDiv` renders a `SingleChildScrollView`. Pair it with the constructor prop `scrollPrimary: true` to enable iOS status-bar-tap-to-top:

```dart
WDiv(
  className: 'flex-1 overflow-y-auto p-4',
  scrollPrimary: true,
  child: ...,
);
```

There is no className for `scrollPrimary`. Omit it and iOS users lose tap-to-top.

If the page has multiple scroll views, only ONE should be `scrollPrimary: true` (the dominant outer scroll). `Scaffold` itself injects a `PrimaryScrollController`; the scroll view nearest the Scaffold body should be primary.

**Nested scrolls.** A vertical `WDiv(className: 'overflow-y-auto')` directly inside another vertical scroll is rarely correct (only inner needed; outer is wasted). Both being primary causes controller conflicts.

**`h-full` inside a scroll = bug.** The scrollable removes the max height; the inner widget cannot resolve `h-full` to a finite value. Use `flex-1` on the body inside a `flex flex-col h-full` parent instead (recipe: Sticky header + scrollable body, §3).

**Reverse: `flex-1` inside an unbounded parent.** Putting `WDiv(className: 'flex-1')` inside a `SingleChildScrollView` directly throws "non-zero flex but incoming constraints unbounded". Either remove `flex-1` or constrain the parent.

---

## 5. Stack + absolute positioning

`absolute` requires a `relative` ancestor on the same `WDiv` chain (translates to a Flutter `Stack` + `Positioned`).

```dart
WDiv(
  className: 'relative w-48 h-48 rounded-xl overflow-hidden',
  children: [
    WImage(src: photoUrl, className: 'w-full h-full object-cover'),
    WDiv(
      className: '''
        absolute bottom-2 right-2
        rounded-full px-2 py-0.5
        bg-black/60 text-white text-xs
      ''',
      child: const WText('NEW'),
    ),
  ],
);
```

Negative offsets work (`-top-2`, `-inset-1`). Percentage offsets (`top-[50%]`) do NOT work.

`fixed` and `sticky` position types are recognised by the parser but produce no visual effect; reach for Material `SliverAppBar` or `Scaffold(persistentFooterButtons:)` for scroll-relative positioning.

---

## 6. Text truncation + min-w-0

`truncate` (which sets `TextOverflow.ellipsis` + `maxLines: 1` + `softWrap: false`) requires a finite `maxWidth` constraint on the `Text` widget. Inside a Row, the default constraint is unbounded; ellipsis never fires.

Fix: wrap the text in a flex child.

```dart
// Wrong: overflows the Row
WDiv(
  className: 'flex flex-row gap-2',
  children: [
    WIcon(Icons.tag_outlined),
    WText('A very long title that should truncate', className: 'truncate'),
  ],
);

// Right: flex-1 gives the text bounded width
WDiv(
  className: 'flex flex-row gap-2 items-center',
  children: [
    WIcon(Icons.tag_outlined),
    WDiv(
      className: 'flex-1 min-w-0',
      child: WText('A very long title that should truncate', className: 'truncate'),
    ),
  ],
);
```

The `min-w-0` is critical when the Row also has flex parents above it. Default flex children have `minWidth` = intrinsic width, which prevents truncation in nested flex layouts. `min-w-0` lets the child shrink below intrinsic.

---

## 7. items-stretch inside a scroll

`items-stretch` (Flutter's `CrossAxisAlignment.stretch`) makes row children match the tallest. Inside a `SingleChildScrollView`, the row's intrinsic height is what the scroll exposes, and `stretch` needs a known height. Wrap in `IntrinsicHeight` from native Flutter:

```dart
WDiv(
  className: 'overflow-y-auto p-4',
  scrollPrimary: true,
  child: IntrinsicHeight(
    child: WDiv(
      className: 'flex flex-row items-stretch gap-2',
      children: [
        WDiv(className: 'flex-1 bg-blue-100 p-4'),
        WDiv(className: 'flex-1 bg-red-100 p-4'),
      ],
    ),
  ),
);
```

`IntrinsicHeight` is documented as relatively expensive (it runs a speculative layout pass). Reach for it only when this exact row height-match-inside-scroll pattern is required.

> **Column width-stretch is intrinsic-free (no `IntrinsicHeight` needed).** The reverse case, a `flex flex-col items-stretch` (equal child WIDTHS), needs no `IntrinsicHeight`: Wind's column cross-axis stretch is a real render object (`WindCrossStretch`), and `basis-*` resolves without a `LayoutBuilder`. So a `flex flex-col` (with or without `basis-*`) renders under an `IntrinsicHeight`, a `Table`, or an `items-stretch` grid cell without asserting. Only the ROW height-match above still uses `IntrinsicHeight`.

> **`h-full` is intrinsic-safe now.** It used to resolve through a Wind-internal `LayoutBuilder` and throw `LayoutBuilder does not support returning intrinsic dimensions` under an `IntrinsicHeight`; it is the `WindFullHeightBox` render object now, so it renders there, in a `Table` cell, and in an `items-stretch` grid cell without asserting, and it reports its child's intrinsic height so it matches the tallest sibling rather than the screen. The one remaining `LayoutBuilder` path is `grid`. For equal-height cards outside a scroll, `h-full` under an `IntrinsicHeight` now works; a `Stack` + `Positioned(top:0,bottom:0)` remains the cheaper shape.

---

## 8. Touch targets

Material design recommends ≥48 dp; Cupertino recommends ≥44 pt. Wind has no automatic enforcement. For icon buttons, expand the visual via padding:

```dart
// 24 dp icon, 48 dp tap target via p-3
WButton(
  onTap: _close,
  className: 'p-3 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700',
  child: const WIcon(Icons.close_outlined),
);
```

For lists of compact rows, ensure the tap area on `WAnchor` / `WDiv` includes vertical padding (`py-3` minimum).

Flutter's `MaterialTapTargetSize.padded` (default on `IconButton`) does this implicitly for Material widgets; Wind widgets do not. Expanded visual = expanded tap target.

---

## 9. Responsive cascade examples

Mobile-first means base classes apply to all sizes; responsive prefixes override at and above their breakpoint.

```dart
// Stack on mobile, side-by-side on md+, with image taking 1/3 on lg+
WDiv(
  className: 'flex flex-col md:flex-row gap-4',
  children: [
    WDiv(
      className: 'w-full md:w-1/3 lg:w-1/4',
      child: WImage(src: photo, className: 'w-full aspect-video object-cover rounded-lg'),
    ),
    WDiv(
      className: 'flex-1 flex flex-col gap-2',
      children: [
        WText(title, className: 'text-xl font-bold text-gray-900 dark:text-white'),
        WText(body, className: 'text-base text-gray-600 dark:text-gray-300'),
      ],
    ),
  ],
);

// Reading width: full on mobile, capped at prose width on md+
WDiv(
  className: 'w-full md:max-w-prose mx-auto p-4 md:p-6 lg:p-8',
  child: ...,
);

// Reveal sidebar on lg+
WDiv(
  className: 'flex flex-col lg:flex-row gap-4',
  children: [
    WDiv(className: 'flex-1', child: mainContent),
    WDiv(
      className: 'hidden lg:flex lg:w-64 flex-col gap-2',
      children: sidebarItems,
    ),
  ],
);
```

For very different mobile vs desktop layouts (not just sizing), reach for `WBreakpoint` instead of prefix-chaining.

---

## Anti-patterns

| Wrong | Why | Right |
|---|---|---|
| `WDiv(className: 'w-full')` inside a Row (works, treated as `flex-1`) | No failure, just intent clarity | `'flex-1'` (clearer) |
| `WDiv(className: 'h-full overflow-y-auto')` inside a Column | Unbounded height assertion | `'flex-1 overflow-y-auto'` + `scrollPrimary: true`, parent has `h-full` |
| `WDiv(className: 'absolute top-0')` without `relative` ancestor | No Stack to anchor | wrap parent in `'relative'` |
| `WText(..., className: 'truncate')` directly inside a Row | Unbounded width; ellipsis never fires | wrap in `WDiv(className: 'flex-1 min-w-0')` |
| `overflow-y-auto` without `scrollPrimary: true` | iOS tap-to-top broken | add the constructor prop |
| `Container(child: WDiv(...))` | Loses className surface on the outer | use `WDiv` directly |
| `Wrap(children: ...)` instead of `WDiv(className: 'wrap gap-2')` | Cannot consume className from outside | use `WDiv` |
| `Stack` + `Positioned` directly | Same; loses className | use `relative` + `absolute` tokens on `WDiv` |
| `GridView.builder` for a 6-item static grid | Overhead for nothing | `WDiv(className: 'grid grid-cols-3 gap-4', children: [...])` |
| `WDiv(className: 'grid grid-cols-3')` for 200 dynamic items | Not virtualized; renders all at once | `GridView.builder` |
