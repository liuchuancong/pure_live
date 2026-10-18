# pure_live

Pure Live: cross-platform live streaming client.

## Adaptive main layout

The four main branches share one responsive frame:

| Width | Navigation | Page chrome |
| --- | --- | --- |
| `< 768` | Fluent drawer / phone bottom strip | `PureAppBar`, page tabs under it |
| `768–1023` | 260px branded `FluentNavDrawer` | workspace search strip + in-page title |
| `>= 1024` | 260px branded `FluentNavDrawer` | workspace search strip + in-page title |

- `MainWorkspaceHost` / `MainWorkspaceBar` (`lib/app/shell/main_workspace.dart`)
  host the search/action strip and tell pages whether it is present.
- `MainPageFrame` (`lib/app/shell/main_page_frame.dart`) draws the in-content
  title and tab strip on wide layouts, or hands the same data to `PureAppBar`
  on a phone. Content stops at 1440px and is centered.
- `MainSidebarBrand` (`lib/app/shell/main_sidebar.dart`) draws the full brand
  lockup in the drawer.
- `shellRailDestinations` (`lib/app/shell/shell_destinations.dart`) adds the
  utility pages (history, IPTV, multiview, toolbox) to the branch tabs.

`PureAppShell` uses Fluent's own `FluentNavDrawer` at both tablet and desktop
widths; the app keeps the other design languages' native navigation untouched.

## Getting Started

```bash
flutter run -d windows
```

The workspace resolves dependencies from the repository root; run
`flutter pub get` there when the lock file changes.
