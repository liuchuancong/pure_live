# live_uikit_forui

The ForUI design-language adapter for PureLive's unified UI system (`live_uikit`).
It implements the whole core contract with `forui` widgets
(`FButton`, `FCard`, `FTextField`, `FSwitch`, `FCheckbox`, `FSlider`, `FDeterminateProgress`,
`FProgress`, `FSelect`, `FTabs`, `FScaffold`, `FHeader`, `FTile`, `FBottomNavigationBar`,
`FToast`, `FDialog`), composes the controls the library has no widget for out of its own
parts, owns both structural surfaces, and installs the forui theme variant the resolved
design token can decide.

See `live-uikit-forui.md` in this directory for the full architecture and
integration specification.

## Purpose

`live_uikit` defines the design-language-agnostic contracts, tokens and runtime
dispatch. This package supplies the **ForUI** implementation of that contract so an
application can select `forui` at runtime and have every control, the page frame and the
application host drawn by `forui`, without any business page importing `forui` directly.

## Responsibilities

- Implement `LanguageAdapter` for `LiveDesignLanguage.forui` (stable id `forui`). The
  contract is an `abstract interface class`; this adapter implements it directly, and
  implements all of it — every control and both surfaces.
- Map the resolved `DesignToken` into forui's `FThemeData` and install it through an
  `FTheme` scope (never a second application widget inside the host). The library's private
  `FThemeData` constructor caps the mapping at the light/dark neutral variant (§8.1);
  the ceiling is pinned by test rather than faked.
- Build native ForUI widgets for all seventeen: **button, card, text field, switch,
  checkbox, slider, segmented, progress, select, tab bar, scaffold, app bar, list
  row, nav bar, toast, dialog, tab view**. Fourteen of those are one-for-one mappings
  onto a `forui` widget. Three are not, and each builder says why: `segmented` is composed
  as a row of ghost `FButton`s taking `FButton.selected`, because the library's only
  single-choice row is `FTabs`, which is a tab *view* and is spent on the tab bar; `tab bar`
  is `FTabs` itself with an empty content panel per entry, since that widget always paints a
  body area while this contract's body belongs to the caller; and `tab view` is the mirror
  image of that gap — the library's only page switcher is the same `FTabs`, whose panels hang
  off labels a page switcher is never given, so the view is the widgets-layer `PageView` over
  the caller's pages. `dialog` is `FDialog`'s frame, with the inside composed because
  0.27.5's frame carries no content padding and no action area; the route, the barrier and
  the fade stay in the core's `showLiveDialog`.
- Declare the whole contract in `foruiCapabilities` and both structural surfaces in
  `foruiSurfaces`, and keep each set in step with the methods the adapter overrides (§17).
  A control or surface declared without an override is a `LiveUiCapabilityException`; a
  language this build did not register is a `LiveUiResolutionException`.
- Own both structural surfaces (§ surfaces). The app host: the library ships no
  application widget, so the host is Flutter's `WidgetsApp` with `FTheme` above the
  routed tree — which is what takes the page transition and the scroll physics out of
  Material's hands. The app shell: `FSidebar` needs nothing above that same `FTheme`
  and paints only the navigation column, so the shell draws
  `Row[FSidebar, Expanded(page)]` itself, hands the bottom form to the library's own
  `FBottomNavigationBar` through `navBar`, and refuses disabled destinations in place
  because the library's item has no disabled state to map onto.
- Expose `foruiLocalizationsDelegates` for the composition root to install.

## What this package must not own

- Global theme preferences or their persistence, and the style-selector UI.
- Shared design-token definitions or global configuration storage.
- Any state management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters, or on `forui` leaking into
  business packages.

Every one of the seventeen controls and both structural surfaces is drawn by this package,
in `forui`'s own widgets where the library has one and out of its own parts where it does
not. What is left is narrower and documented per builder: a few spec fields the library has
no slot for (`LanguageProgressSpec.showLabel`, `LanguageSliderSpec.focusNode`,
`LanguageTabsSpec.spacing`, `FSidebarItem`'s missing disabled state,
`LanguageDialogSpec.dismissible` which the core's barrier answers), and
the theme ceiling described above (spec §18).

## Public entry point

`package:live_uikit_forui/live_uikit_forui.dart` — exports only the registration
API (§6). Do not import `src/` from another package.

## Installation and usage

PureLive uses a single Pub workspace; this package is already a workspace member.
Business packages depend only on `live_uikit`. The **application composition root**
registers the adapter:

```dart
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_forui/live_uikit_forui.dart';

const registry = LanguageRegistry(adapters: {LiveDesignLanguage.forui: foruiAdapter});

// Append forui's delegate to the core's and hand the result to the host, which
// forwards it to this adapter's `appHost`:
//   LiveApp(
//     routerConfig: router,
//     localizationsDelegates: [
//       ...liveLocalizationsDelegates,
//       ...foruiLocalizationsDelegates,
//     ],
//   )
```

Selecting the style at runtime is `UiConfig.language = LiveDesignLanguage.forui`, which
the configuration requires; a `LiveButton` then draws through this adapter with no change
to the page, and the window itself is hosted by this adapter's `appHost`. A language the
build did not register is a `LiveUiResolutionException`, not another language's skin.

## Dependencies

- `live_uikit` (the contracts and runtime dispatch)
- `forui` ^0.27.5 (the native forui widgets and theme)
- Flutter SDK

## Testing

```powershell
dart format --output=none --set-exit-if-changed packages/live_uikit_forui
flutter analyze packages/live_uikit_forui
flutter test packages/live_uikit_forui
```

Run from the workspace root; `tool/check_architecture.ps1` additionally asserts the
library boundary, the `as forui` import prefix, the registration-only barrel, and the
README/capability match.
