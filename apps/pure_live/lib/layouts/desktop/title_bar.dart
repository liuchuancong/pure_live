import 'dart:async' show unawaited;

// Every import stays on one line with no `show` clause: the save-time
// import organizer used to tear wrapped imports apart, so nothing here
// may wrap. Do not add a wrapped import to this file.
import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// The height of the title bar: the drag band and the caption row.
const double kTitleBarHeight = 44;

/// The strip above every route: at its left corner the app icon that
/// hovers into the sidebar toggle, the back and forward arrows, then the
/// drag band and the caption controls. The corner tooltips open downward
/// — the window's top edge clips anything above.
final class WindowTitleBar extends ConsumerWidget {
  /// The strip over [onToggleSidebar], [onBack], [onForward] and the
  /// window's own controls.
  const WindowTitleBar({
    required this.expanded,
    required this.onToggleSidebar,
    required this.canBack,
    required this.canForward,
    required this.onBack,
    required this.onForward,
    this.onSearch,
    super.key,
  });

  /// Whether the sidebar is out, for the toggle's hovered icon.
  final bool expanded;

  /// Fired when the toggle is pressed.
  final VoidCallback onToggleSidebar;

  /// Whether the back arrow may move.
  final bool canBack;

  /// Whether the forward arrow may move.
  final bool canForward;

  /// Fired when the back arrow is pressed.
  final VoidCallback onBack;

  /// Fired when the forward arrow is pressed.
  final VoidCallback onForward;

  /// Opens the global search — the toolbar field takes focus on desktop,
  /// the search page opens on the phone. Null leaves the magnifier out,
  /// for a host without a search.
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final t = context.t;
    final host = ref.watch(desktopWindowHostProvider);
    final mac = DsTheme.of(context).platform == TargetPlatform.macOS;
    final wallpaper = BackgroundActiveScope.isActiveOf(context);
    return ColoredBox(
      color: wallpaper ? colors.surface.withValues(alpha: 0.86) : colors.surface,
      child: SizedBox(
        height: kTitleBarHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // A narrow window keeps its drag band: the trail arrows and the
            // search give way first, the toggle and the caption never do.
            final trail = constraints.maxWidth >= 480;
            final search = onSearch != null && constraints.maxWidth >= 560;
            return Row(
              children: [
                _SidebarToggleButton(expanded: expanded, onPressed: onToggleSidebar),
                if (trail) ...[
                  DsTooltip(
                    message: t.common.back,
                    side: DsSide.bottom,
                    child: _CaptionButton(
                      semanticLabel: t.common.back,
                      icon: DsIcons.arrowLeft,
                      enabled: canBack,
                      onPressed: onBack,
                    ),
                  ),
                  DsTooltip(
                    message: t.common.forward,
                    side: DsSide.bottom,
                    child: _CaptionButton(
                      semanticLabel: t.common.forward,
                      icon: DsIcons.arrowRight,
                      enabled: canForward,
                      onPressed: onForward,
                    ),
                  ),
                ],
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) => host.startDragging(),
                    onDoubleTap: host.toggleMaximize,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          t.common.appTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DsTheme.of(context).typography.caption.copyWith(color: colors.textMuted),
                        ),
                      ),
                    ),
                  ),
                ),
                if (search)
                  ChromeIconButton(
                    icon: DsIcons.search,
                    semanticLabel: t.navigation.search,
                    tooltip: t.navigation.search,
                    shortcut: mac ? '⌘K' : 'Ctrl K',
                    onPressed: onSearch,
                  ),
                ChromeIconButton(
                  icon: DsIcons.appWindow,
                  semanticLabel: t.common.newWindow,
                  tooltip: t.common.newWindow,
                  shortcut: mac ? '⌘N' : 'Ctrl N',
                  onPressed: () => unawaited(openAppWindow(context)),
                ),
                const ThemeModeToggle(),
                if (WindowChromeState.drawsCaptionControls) ...[
                  Container(
                    width: 1,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: colors.border,
                  ),
                  const _CaptionControls(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The window strip above a page that sits outside the shell — a settings
/// subpage, a room, a pushed screen. Those routes replace the shell, so no
/// layout draws the window's own chrome; without this strip a self-drawn
/// window would lose its drag band and its caption controls. The decision
/// is the window's, not the layout's: a narrow desktop window gets the same
/// strip as a wide one, and the OS caption keeps its place everywhere else.
final class WindowChromeFrame extends StatelessWidget {
  /// Wraps a route's [child] in the window strip when the app draws it.
  const WindowChromeFrame({required this.child, this.enabled = true, super.key});

  /// The route's screen.
  final Widget child;

  /// Whether this route wants the strip. Immersive player modes that fill
  /// the window hide it; every ordinary route keeps it.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || !WindowChromeState.drawsStrip) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WindowCaptionBar(),
        Expanded(child: child),
      ],
    );
  }
}

/// The minimal caption strip for a route outside the shell: the drag band,
/// the app's name, the theme switch and the window's own controls. The
/// route's app bar already carries its back and its title, so this strip
/// does not repeat the sidebar toggle, the trail or the search.
final class WindowCaptionBar extends ConsumerWidget {
  /// A caption strip.
  const WindowCaptionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final t = context.t;
    final host = ref.watch(desktopWindowHostProvider);
    final wallpaper = BackgroundActiveScope.isActiveOf(context);
    return ColoredBox(
      color: wallpaper ? colors.surface.withValues(alpha: 0.86) : colors.surface,
      child: SizedBox(
        height: kTitleBarHeight,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => host.startDragging(),
                onDoubleTap: host.toggleMaximize,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      t.common.appTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsTheme.of(context).typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ),
                ),
              ),
            ),
            const ThemeModeToggle(),
            if (WindowChromeState.drawsCaptionControls) ...[
              Container(width: 1, height: 20, margin: const EdgeInsets.symmetric(horizontal: 4), color: colors.border),
              const _CaptionControls(),
            ],
          ],
        ),
      ),
    );
  }
}

/// The title bar's left corner: the app icon at rest, the sidebar toggle's
/// icon on hover — the state it leads to, collapsed or expanded — with the
/// localized tooltip and the shortcut under the pointer.
final class _SidebarToggleButton extends ConsumerWidget {
  const _SidebarToggleButton({required this.expanded, required this.onPressed});

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final t = context.t;
    return DsTooltip(
      message: t.common.toggleSidebar,
      shortcut: 'Ctrl+B',
      side: DsSide.bottom,
      child: SizedBox(
        width: kTitleBarHeight,
        height: kTitleBarHeight,
        child: DsPressable(
          semanticLabel: t.common.toggleSidebar,
          onPressed: onPressed,
          builder: (context, states, _) {
            final hovered = states.contains(WidgetState.hovered);
            final pressed = states.contains(WidgetState.pressed);
            return ColoredBox(
              color: pressed
                  ? colors.press
                  : hovered
                  ? colors.hover
                  : const Color(0x00000000),
              child: Center(
                child: DsIcon(
                  hovered ? (expanded ? DsIcons.panelLeftClose : DsIcons.panelLeftOpen) : DsIcons.tv,
                  size: 16,
                  color: colors.text,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

final class _CaptionControls extends ConsumerWidget {
  const _CaptionControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final host = ref.watch(desktopWindowHostProvider);
    final maximized = ref.watch(maximizedProvider);
    return Row(
      children: [
        _CaptionButton(semanticLabel: t.common.minimize, icon: DsIcons.minus, onPressed: host.minimize),
        _CaptionButton(
          semanticLabel: maximized ? t.common.restore : t.common.maximize,
          icon: maximized ? DsIcons.copy : DsIcons.square,
          onPressed: host.toggleMaximize,
        ),
        _CaptionButton(semanticLabel: t.common.close, icon: DsIcons.x, danger: true, onPressed: host.close),
      ],
    );
  }
}

final class _CaptionButton extends ConsumerWidget {
  const _CaptionButton({
    required this.semanticLabel,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
    this.danger = false,
  });

  final String semanticLabel;
  final DsIconData icon;

  /// The host's calls return futures; a void return swallows them.
  final VoidCallback onPressed;

  /// False dims the icon and deadens the press: an arrow over an empty
  /// trail, say.
  final bool enabled;
  final bool danger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    return SizedBox(
      width: kTitleBarHeight,
      height: kTitleBarHeight,
      child: DsPressable(
        semanticLabel: semanticLabel,
        onPressed: enabled ? onPressed : null,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          final pressed = states.contains(WidgetState.pressed);
          Color? background;
          if (enabled) {
            if (danger && hovered) {
              background = colors.danger.fill;
            } else if (hovered || pressed) {
              background = pressed ? colors.press : colors.hover;
            }
          }
          return ColoredBox(
            color: background ?? const Color(0x00000000),
            child: Center(child: DsIcon(icon, size: 14, color: enabled ? colors.text : colors.textSubtle)),
          );
        },
      ),
    );
  }
}
