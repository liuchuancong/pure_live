import 'package:live_uikit/live_uikit.dart';

/// The structural surfaces `live_uikit_macos` owns with `macos_ui`'s own widgets
/// (§ surfaces).
///
/// Both of them. `MacosApp` is the application host, and the shell is the
/// library's own navigation list — `SidebarItems` of `SidebarItem` rows, the
/// selected one painted with the system-accent chip — mounted in a column the
/// shell draws beside the page.
///
/// An earlier note here claimed a macOS shell meant first deciding who owns the
/// window frame, because `Sidebar` is "a child of `MacosWindow`". That premise was
/// measured and is wrong twice over: `SidebarItems` builds with no `MacosWindow`
/// and no `MacosScaffold` ancestor (it reads only `MacosTheme` and two process-wide
/// listeners that no-op off macOS), and `Sidebar` itself is not a widget at all in
/// `macos_ui` 2.2.2 — a plain descriptor whose only reader is `MacosWindow`. So the
/// question was never the shell's to answer: the page frame stays with this
/// language's `scaffold` (`MacosScaffold`), and the shell contributes exactly one
/// sidebar. What the descriptor does own — drag-resizing, the window breakpoint,
/// its `top`/`bottom` slots — is `MacosWindow`'s behaviour, so the shell's column is
/// a fixed-width sidebar whose footer it pins itself.
///
/// The bottom-strip form has no macOS widget behind it, so that request goes back
/// through this language's `navBar`, which is the library's own `MacosTab` cell.
const LiveUiSurfaceCapabilities macosSurfaces = LiveUiSurfaceCapabilities(<LiveUiSurface>{
  LiveUiSurface.appHost,
  LiveUiSurface.appShell,
});
