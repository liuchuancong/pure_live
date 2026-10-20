import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:pure_live/app/providers/app_providers.dart' show environmentProvider, windowChromeProvider;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/desktop/shell/shell_preferences.dart' show ShellWindowChrome;
import 'package:pure_live/platforms/desktop/shell/window_title_bar.dart'
    show windowChromeActionsProvider, windowChromeStateProvider;
import 'package:pure_uikit/pure_uikit.dart' show PureCanvasScope, PureTheme, PureTitleBar, PureTitleBarLabels;

/// The window's own strip above every page (the reference's `DesktopFrame`,
/// A16.1): where the desktop shell took the caption over from the system —
/// self-drawn frame mode — the app draws it once, above the whole navigator,
/// so a pushed room, settings page or search window still has its drag band
/// and its min/maximise/close, exactly like a window with a native title bar.
///
/// It stands down in three cases: the native caption is in charge (the frame
/// preference is not the app's), the device is not a desktop window, and the
/// window is full screen — where the video owns every pixel and the
/// reference hides the bar too (`DesktopWindow.fullScreen`).
///
/// The strip itself is the design language's own look ([PureTitleBar]
/// dispatches it); this frame only owns the placement: above the routes,
/// inside the window's painted edge, and wrapped in an [Overlay] so a
/// caption button can show its name under the pointer without waiting for a
/// route's overlay to exist — the reference's `DesktopFrame` wraps the same
/// way for the same reason.
final class DesktopTitleFrame extends ConsumerWidget {
  /// Wraps the app's content [child] in the caption when the shell runs.
  const new({required this.child, super.key});

  /// Everything the window shows under the caption.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktop = ref.watch(environmentProvider).runtime.formFactor == FormFactor.desktop;
    final appDrawn = ref.watch(windowChromeProvider) == ShellWindowChrome.app;
    if (!desktop || !appDrawn) {
      return child;
    }
    final state = ref.watch(windowChromeStateProvider);
    final actions = ref.watch(windowChromeActionsProvider);
    final t = context.t;
    final labels = PureTitleBarLabels(
      title: t.app.title,
      minimize: t.window.minimize,
      maximize: t.window.maximize,
      restore: t.window.restore,
      close: t.window.close,
    );
    // Only full screen changes the frame's shape. Maximising is the strip's own
    // business — it listens to [WindowChromeState.maximized] — so handing the
    // page subtree to the builder as `child` keeps a maximize from rebuilding
    // every route under this frame, which is what a `ListenableBuilder` over
    // both notifiers used to do. The strip's language is the theme's, decided by
    // `PureTitleBar` like every other control here.
    return ValueListenableBuilder<bool>(
      valueListenable: state.fullScreen,
      child: child,
      builder: (context, fullScreen, content) => fullScreen
          ? content!
          : Overlay.wrap(
              child: ColoredBox(
                // The band the strip floats on wears the pages' own surface —
                // transparent over a window material (the surface continues
                // under the strip, the way the system shell's does), the layout
                // colour otherwise — so the strip is an inset of the page, not
                // a bar painted on top of it. The strip itself paints nothing.
                color: PureCanvasScope.transparentOf(context)
                    ? const Color(0x00000000)
                    : PureTheme.of(context).colors.bgLayout,
                child: Column(
                  children: [
                    PureTitleBar(labels: labels, actions: actions, maximized: state.maximized),
                    Expanded(child: content!),
                  ],
                ),
              ),
            ),
    );
  }
}
