# Wind 1.5: Theme, dark mode, responsive, platform

Customizing `WindThemeData`, brightness control, breakpoint scale, platform prefixes. Reach for this file when adding custom colors, overriding the spacing scale, wiring a dark-mode toggle, defining a custom breakpoint, or recovering from the OverlayEntry context caveat.

## Contents

1. [Install + wire (assuming fresh project)](#1-install--wire-assuming-fresh-project)
2. [WindThemeData fields](#2-windthemedata-fields)
3. [Merge strategy](#3-merge-strategy)
4. [WindThemeController API](#4-windthemecontroller-api)
5. [Dark mode discipline](#5-dark-mode-discipline)
6. [Brightness lifecycle (system sync + manual toggle)](#6-brightness-lifecycle-system-sync--manual-toggle)
7. [Responsive breakpoints](#7-responsive-breakpoints)
8. [Platform prefixes](#8-platform-prefixes)
9. [Custom color families](#9-custom-color-families)
10. [Custom breakpoints, font families, spacing unit](#10-custom-breakpoints-font-families-spacing-unit)
11. [BuildContext extensions](#11-buildcontext-extensions)
12. [The OverlayEntry context caveat](#12-the-overlayentry-context-caveat)

---

## 1. Install + wire (assuming fresh project)

```yaml
# pubspec.yaml
dependencies:
  fluttersdk_wind: ^1.0.0
```

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:fluttersdk_wind/fluttersdk_wind.dart';

void main() {
  if (kDebugMode) {
    Wind.installDebugResolver();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WindTheme(
      data: WindThemeData(),
      builder: (context, controller) => MaterialApp(
        theme: controller.toThemeData(),
        home: const Scaffold(body: HomePage()),
      ),
    );
  }
}
```

Defaults applied automatically: 23 color families (22 Tailwind swatches plus the seeded `primary`), 5 responsive breakpoints (640 / 768 / 1024 / 1280 / 1536 px), spacing unit 4 px, font families (sans / serif / mono), 11-step shade scale (50-950), brightness syncs with OS. `WindTheme` MUST be above `MaterialApp` in Dart-level nesting via the `builder:` callback (the runtime tree inverts this).

---

## 2. WindThemeData fields

24 fields; pass only what you want to override. All are nullable except `brightness`, which defaults to `Brightness.light` rather than null, so they are not literally all nullable.

```dart
WindThemeData({
  Brightness brightness = Brightness.light,
  Map<String, MaterialColor>? colors,              // merged with default 23-family palette
  Map<String, int>? screens,                       // breakpoint name → px
  Map<String, int>? containers,                    // max-w-* size → px (13 named sizes)
  Map<String, double>? fontSizes,                  // text-* size key → px (defaults xs through 6xl)
  Map<String, FontWeight>? fontWeights,            // font-* key → FontWeight
  Map<String, double>? tracking,                   // tracking-* key → letter-spacing px
  Map<String, double>? leading,                    // leading-* key → line-height multiplier
  Map<String, double>? borderWidths,               // border-* width key → px
  Map<String, double>? borderRadius,               // rounded-* key → px
  Map<String, String>? fontFamilies,               // font-* key → fontFamily string
  Map<String, double>? ringWidths,                 // ring-* width key → px
  Map<String, double>? ringOffsets,                // ring-offset-* key → px
  bool applyDefaultFontFamily = true,              // wrap child with DefaultTextStyle(fontFamily: 'sans')
  bool syncWithSystem = true,                      // auto-sync brightness with OS
  double baseSpacingUnit = 4.0,                    // p-1 = baseSpacingUnit; p-4 = 4 × baseSpacingUnit
  Color ringColor = const Color(0xFF3B82F6),       // fallback ring color (blue-500)
  Map<String, double>? opacities,                  // opacity-* key → 0-1
  Map<String, int>? zIndices,                      // z-* key → integer
  Map<String, List<BoxShadow>>? shadows,           // shadow-* key → BoxShadow list
  Map<String, Duration>? transitionDurations,      // duration-* key → Duration
  Map<String, Curve>? transitionCurves,            // ease-* key → Curve
  Map<String, WindAnimationType>? animations,      // animate-* key → enum value
  Map<String, String>? aliases,                    // bare-token shorthand → className string, expanded before parsing
})
```

### Default key tables

**Colors** (22 families): `slate`, `gray`, `zinc`, `neutral`, `stone`, `red`, `orange`, `amber`, `yellow`, `lime`, `green`, `emerald`, `teal`, `cyan`, `sky`, `blue`, `indigo`, `violet`, `purple`, `fuchsia`, `pink`, `rose`. Plus `transparent`, `black`, `white`. Shades: 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950.

**Screens** (5): `sm: 640`, `md: 768`, `lg: 1024`, `xl: 1280`, `2xl: 1536` (px).

**Containers** (13 max-widths): `3xs: 256`, `2xs: 288`, `xs: 320`, `sm: 384`, `md: 448`, `lg: 512`, `xl: 576`, `2xl: 672`, `3xl: 768`, `4xl: 896`, `5xl: 1024`, `6xl: 1152`, `7xl: 1280`.

**Font sizes** (10): `xs: 12`, `sm: 14`, `base: 16`, `lg: 18`, `xl: 20`, `2xl: 24`, `3xl: 30`, `4xl: 36`, `5xl: 48`, `6xl: 60`. Stops at 6xl; `text-7xl` and beyond are silent no-ops.

**Font weights** (9): `thin` (100), `extralight` (200), `light` (300), `normal` (400), `medium` (500), `semibold` (600), `bold` (700), `extrabold` (800), `black` (900).

**Font families** (3): `sans`, `serif`, `mono` (default system stacks).

**Tracking** (6): `tighter` (-2), `tight` (-1), `normal` (0), `wide` (1), `wider` (2), `widest` (4).

**Leading** (5): `tight` (1.25), `snug` (1.375), `normal` (1.5), `relaxed` (1.625), `loose` (2.0).

**Border widths**: `DEFAULT: 1`, `0: 0`, `2: 2`, `4: 4`, `8: 8`.

**Border radius**: `none: 0`, `sm: 2`, `DEFAULT: 4`, `md: 6`, `lg: 8`, `xl: 12`, `2xl: 16`, `3xl: 24`, `full: 9999`.

**Ring widths**: `0: 0`, `1: 1`, `2: 2`, `DEFAULT: 3`, `4: 4`, `8: 8`.

**Opacities** (Tailwind scale): `0`, `5`, `10`, `15`, ..., `95`, `100` (every 5%).

**Z-indices**: `0`, `10`, `20`, `30`, `40`, `50`.

**Shadows**: `sm`, `DEFAULT`, `md`, `lg`, `xl`, `2xl`, `none` (each a `List<BoxShadow>`).

**Transition durations**: `75`, `100`, `150`, `200`, `300`, `500`, `700`, `1000` (ms).

**Transition curves**: `linear`, `in`, `out`, `in-out`.

**Animations**: `animate-spin`, `animate-ping`, `animate-pulse`, `animate-bounce`, `animate-none`.

---

## 3. Merge strategy

User-provided values merge into defaults via `Map.from(defaults)..addAll(userProvided ?? {})`. New defaults added in later Wind versions don't break existing themes; user overrides win.

```dart
WindThemeData(
  colors: {
    'primary': MaterialColor(0xFF6366F1, {
      50: const Color(0xFFEEF2FF),
      100: const Color(0xFFE0E7FF),
      // ... down to 950
    }),
  },
  // brightness, screens, fontSizes etc. all keep their defaults
)
```

The custom `primary` overrides the seeded default; the 22 default families remain available. `bg-primary-500` works; `bg-blue-500` still works.

`primary` is a seeded default token (aliased 1:1 to the Tailwind `blue` swatch), so `bg-primary` / `text-primary` / `border-primary` resolve out of the box even before you register a brand color. The built-in interactive widgets (`WSelect`, `WCheckbox`, `WRadio`, `WDatePicker`) route their selection colors through `primary`, so overriding it here recolors those widgets to your brand while leaving the default look (blue) unchanged when you do not.

---

## 4. WindThemeController API

Exposed via `WindTheme.of(context)` or the extension `context.windTheme`.

```dart
class WindThemeController extends ChangeNotifier {
  // Read-only
  Brightness get brightness;
  Map<String, MaterialColor> get colors;
  Map<String, int> get screens;
  Map<String, double> get fontSizes;
  Map<String, FontWeight> get fontWeights;
  Map<String, String> get fontFamilies;
  Map<String, double> get borderWidths;
  Map<String, double> get borderRadius;
  double get baseSpacingUnit;
  WindThemeData get data;

  // Mutation
  void toggleTheme();                              // flips brightness AND sets syncWithSystem = false
  void setTheme(WindThemeData newData);            // replace entire data
  void updateTheme({                                // partial copyWith
    Brightness? brightness,
    Map<String, MaterialColor>? colors,
    bool? syncWithSystem,
    // ...
  });
  void resetToSystem();                            // re-enables syncWithSystem; reads OS brightness

  // Bridge to Material
  ThemeData toThemeData();                         // for MaterialApp.theme: uses 'primary', 'secondary', 'error', 'background'
}
```

`toggleTheme()` is the user-driven dark-mode switch. It deliberately disables `syncWithSystem` so a user choice does not get overridden the next time the OS theme changes. `resetToSystem()` re-enables sync.

`WindThemeData` implements value `==` / `hashCode`, so passing a fresh default `WindThemeData()` on a rebuild no longer clobbers a `toggleTheme()` choice or forces a spurious rebuild: an equal value is a no-op.

---

## 5. Dark mode discipline

Wind's contract: every color token carries a `dark:` peer in the same className. This is a Core Law in SKILL.md (§2). Detail.

**Pair on the same line.** Group light and dark variants together so a missing pair is visible at audit:

```dart
// Wrong (audit-hostile)
className: '''
  bg-white text-gray-900 border-gray-200
  dark:bg-gray-800 dark:text-white dark:border-gray-700
'''

// Right (audit-friendly)
className: '''
  bg-white dark:bg-gray-800
  text-gray-900 dark:text-white
  border-gray-200 dark:border-gray-700
'''
```

**Tokens that need a dark: peer:** `bg-*`, `text-*`, `border-*`, `ring-*`, `shadow-*`, `fill-*`, `stroke-*`, `from-*`, `via-*`, `to-*` (gradient stops).

**Tokens that do NOT need a dark: peer:** sizing, spacing, layout, opacity, animations, transitions, border-radius, border-width. These are brightness-agnostic.

**Common dark palettes:**

| Use | Light | Dark |
|---|---|---|
| Page background | `bg-white` or `bg-gray-50` | `dark:bg-gray-900` (favor) or `dark:bg-slate-900` (avoid pure black; reduces eye strain) |
| Card background | `bg-white` | `dark:bg-gray-800` |
| Primary text | `text-gray-900` | `dark:text-white` or `dark:text-gray-100` |
| Secondary text | `text-gray-600` | `dark:text-gray-300` or `dark:text-gray-400` |
| Border | `border-gray-200` | `dark:border-gray-700` |
| Accent (primary) | `bg-blue-600` | `dark:bg-blue-500` (one shade lighter to maintain contrast) |
| Hover surface | `hover:bg-gray-50` | `dark:hover:bg-gray-700` |
| Focus ring | `focus:ring-blue-500` | `dark:focus:ring-blue-400` |

**Don't use pure black.** `bg-black` / `dark:bg-black` is visually fatiguing. `gray-900` (#111827) or `slate-900` (#0F172A) read as black but soften the contrast slightly.

**Combine prefixes freely.** `dark:md:hover:bg-blue-400` activates only on md+ AND dark AND hover. Order is arbitrary.

---

## 6. Brightness lifecycle (system sync + manual toggle)

Default behavior (`syncWithSystem: true`):
- On mount, reads `WidgetsBinding.instance.platformDispatcher.platformBrightness` and applies it.
- Listens to `WidgetsBindingObserver.didChangePlatformBrightness` and updates controller when OS changes.
- `onThemeChanged` callback fires for user-initiated changes only (system changes are flagged internally).

GOTCHA: because `syncWithSystem` is `true` by default, a declarative `WindThemeData(brightness: Brightness.dark)` is OVERRIDDEN on mount by the OS brightness, so `dark:` classes stay inert on a light OS. To force a fixed brightness, pass `WindThemeData(brightness: Brightness.dark, syncWithSystem: false)`, or drive it at runtime via `controller.toggleTheme()` / `setTheme(...)`.

Manual toggle:

```dart
WButton(
  onTap: () => context.windTheme.toggleTheme(),
  className: 'p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700',
  child: WIcon(
    context.windIsDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
  ),
);
```

`toggleTheme()` disables `syncWithSystem`. If the user wants to return to OS sync:

```dart
WButton(
  onTap: () => context.windTheme.resetToSystem(),
  child: const Text('Match system'),
);
```

For per-screen overrides (e.g., a settings preview that's always light), use a nested `WindTheme`:

```dart
WindTheme(
  data: WindThemeData(brightness: Brightness.light, syncWithSystem: false),
  builder: (innerContext, _) => MyPreview(),
);
```

---

## 7. Responsive breakpoints

Mobile-first. Base classes apply to all sizes; responsive prefixes override at and above the named width.

| Prefix | Default min-width | Custom theme key |
|---|---|---|
| `sm:` | 640 px | `screens['sm']` |
| `md:` | 768 px | `screens['md']` |
| `lg:` | 1024 px | `screens['lg']` |
| `xl:` | 1280 px | `screens['xl']` |
| `2xl:` | 1536 px | `screens['2xl']` |

Examples:

```dart
className: 'w-full md:w-1/3 lg:w-1/4'         // full mobile, 1/3 tablet, 1/4 desktop
className: 'hidden md:flex'                    // hidden on mobile, visible md+
className: 'p-4 md:p-6 lg:p-8'                 // larger padding as the viewport grows
className: 'flex-col md:flex-row'              // stack mobile, side-by-side md+
```

Prefix cascade: `md:flex-row` activates at md AND lg AND xl AND 2xl. Reach for `lg:` only when behavior should differ at lg vs md.

`WBreakpoint` is the imperative escape hatch when prefixes do not express the change (different widget hierarchies, not just style):

```dart
WBreakpoint(
  base: (_) => const MobileLayout(),
  md: (_) => const TabletLayout(),
  lg: (_) => const DesktopLayout(),
);
```

---

## 8. Platform prefixes

Resolved at runtime via `WindPlatformService` (singleton; checks `kIsWeb` first, then `Platform.*`).

| Prefix | True when |
|---|---|
| `web:` | Running on web (`kIsWeb`) |
| `ios:` | iOS native |
| `android:` | Android native |
| `macos:` | macOS native |
| `windows:` | Windows native |
| `linux:` | Linux native |
| `mobile:` | iOS OR Android |

Examples:

```dart
className: 'ios:rounded-2xl android:rounded-md'        // platform-native rounded corners
className: 'web:cursor-pointer mobile:active:opacity-70'
className: 'web:hover:bg-blue-50 ios:hover:bg-transparent'  // hover only on web
```

Combine with state and breakpoint freely:

```dart
className: 'md:hover:scale-105 mobile:active:scale-95'
```

---

## 9. Custom color families

Register custom palettes for brand colors, status colors (incident severity, monitor status), or design-system aliases.

```dart
WindThemeData(
  colors: {
    'primary': MaterialColor(0xFF6366F1, {
      50: const Color(0xFFEEF2FF),
      100: const Color(0xFFE0E7FF),
      200: const Color(0xFFC7D2FE),
      300: const Color(0xFFA5B4FC),
      400: const Color(0xFF818CF8),
      500: const Color(0xFF6366F1),     // canonical
      600: const Color(0xFF4F46E5),
      700: const Color(0xFF4338CA),
      800: const Color(0xFF3730A3),
      900: const Color(0xFF312E81),
      950: const Color(0xFF1E1B4B),
    }),
    'incident': MaterialColor(0xFFEF4444, /* ... */),
    'up': MaterialColor(0xFF10B981, /* ... */),
    'down': MaterialColor(0xFFEF4444, /* ... */),
  },
);
```

After registration, all parsers recognise the family:

```dart
className: 'bg-primary-500 hover:bg-primary-600 dark:bg-primary-400'
className: 'border-incident-500 text-incident-700 dark:text-incident-300'
className: 'shadow-primary-500/20'
```

`toThemeData()` reads `colors['primary']`, `colors['secondary']`, `colors['error']`, `colors['background']` for the Material `ColorScheme.fromSeed`. The seeded default `primary` (blue) drives Wind widgets only: it is NOT pushed into the Material `ColorScheme`, which keeps its indigo baseline until you register a brand `primary`. Register a custom `primary` if you want `MaterialApp.theme` to reflect the brand.

---

## 10. Custom breakpoints, font families, spacing unit

**Custom breakpoint:**

```dart
WindThemeData(
  screens: {
    'tablet': 900,                  // adds tablet: prefix
    'wide': 1600,                   // adds wide: prefix
  },
);
```

Default screens (sm/md/lg/xl/2xl) are preserved unless explicitly overridden:

```dart
className: 'flex-col tablet:flex-row wide:max-w-7xl'
```

**Custom font family:**

```dart
WindThemeData(
  fontFamilies: {
    'display': 'PolySans',           // adds font-display token
    'mono': 'JetBrains Mono',        // overrides default 'mono'
  },
);
```

Add the font assets to `pubspec.yaml` separately; `WindThemeData.fontFamilies` only maps token to family name.

**Custom spacing unit:**

```dart
WindThemeData(baseSpacingUnit: 8.0);   // p-1 = 8px now, p-4 = 32px
```

Reach for this only when matching an external design system. Default 4 px aligns with Tailwind muscle memory.

---

## 11. BuildContext extensions

Imported with the main barrel.

```dart
context.windTheme              // WindThemeController
context.windThemeData          // WindThemeData (read-only)
context.windColors             // Map<String, MaterialColor>
context.windScreens            // Map<String, int>
context.windBrightness         // Brightness
context.windIsDark             // bool

// Shortcut helpers (one-off lookups):
context.wColorExt('blue', 500)            // Color
context.wSpacingExt('4')                  // double (= baseSpacingUnit * 4)
context.wFontSizeExt('lg')                // double
context.wFontWeightExt('bold')            // FontWeight
context.wScreenIsExt('md')                // bool (current width >= breakpoint)
context.wActiveBreakpoint                 // String ('base', 'sm', 'md', 'lg', 'xl', '2xl')
context.wIsMobile                         // bool (iOS or Android)
context.wIsTablet                         // bool (heuristic)
context.wIsDesktop                        // bool
context.wStyleExt('p-4 bg-red-500')       // WindStyle (one-off parse)
```

Reach for `wScreenIsExt` and `wActiveBreakpoint` only when widget-tree branching (which `WBreakpoint` covers) is overkill. For styling, prefix the className (`md:...`) instead.

---

## 12. The OverlayEntry context caveat

`WindTheme` lives BELOW `MaterialApp` in the runtime widget tree because the builder pattern inverts apparent order. Consequence: contexts captured from inside `OverlayEntry.builder` cannot reach `WindTheme` via ancestor walk.

**Symptom:** Calling `WindParser.parse(className, context, ...)` inside an overlay returns a `WindStyle` based on default theme values instead of your customized theme. Custom colors do not resolve. Dark mode does not activate.

**Fix:** Capture the outer State's `context` BEFORE creating the OverlayEntry; pass it down.

```dart
class _MyMenuState extends State<MyMenu> {
  OverlayEntry? _entry;

  void _show() {
    final outerContext = context;        // capture State's context now
    _entry = OverlayEntry(
      builder: (overlayContext) {
        // overlayContext does NOT see WindTheme.
        // Use outerContext for any Wind lookup.
        return WDiv(
          className: 'bg-white dark:bg-gray-800 ...',
          child: ...,
        )
        // NOTE: passing className to a W-widget that lives in the overlay is
        // safe ONLY because the W-widget itself calls WindParser.parse(className, outerContext)
        // internally if it has the right context. For custom overlay content
        // that calls WindParser.parse directly, pass `outerContext` explicitly.
        ;
      },
    );
    Overlay.of(context).insert(_entry!);
  }
}
```

`WPopover` and `WSelect` already handle this internally. The caveat surfaces when you build a custom overlay (showing a tooltip via `OverlayEntry`, a custom popup, a tour overlay).

The safe pattern in practice: don't call `WindParser.parse` directly from inside `OverlayEntry.builder`. Instead, build W-widgets inside the overlay; they parse with the right context themselves.

**A second, separate decision: WHICH overlay hosts the entry.** `Overlay.of(context)` returns the nearest one, which is right for an entry positioned against surrounding content (a menu anchored to its trigger). An entry positioned in SCREEN terms needs `Overlay.of(context, rootOverlay: true)`, because a nested overlay is measured in its own box rather than the screen's. `WKeyboardActions` is the worked example: its toolbar sits at `bottom: viewInsets.bottom` so it lands on the keyboard, and in an app whose page host owned an `Overlay` inside a scroll view the nearest overlay was as tall as the scrolled content, so the toolbar rendered roughly 1300pt below the viewport. It was in the semantics tree the whole time, which is the worst shape this bug takes: a tree assertion passes and the user still has nothing to press.
