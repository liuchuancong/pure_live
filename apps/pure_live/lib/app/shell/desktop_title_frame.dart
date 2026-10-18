import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:pure_live/app/providers/app_providers.dart' show environmentProvider, windowChromeProvider;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/desktop/shell/shell_preferences.dart' show ShellWindowChrome;
import 'package:pure_live/platforms/desktop/shell/window_title_bar.dart'
    show PureTitleBar, PureTitleBarLabels, windowChromeActionsProvider, windowChromeStateProvider;

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
    return ListenableBuilder(
      listenable: Listenable.merge([state.maximized, state.fullScreen]),
      builder: (context, _) {
        if (state.fullScreen.value) {
          return child;
        }
        return Overlay.wrap(
          child: Column(
            children: [
              PureTitleBar(
                labels: PureTitleBarLabels(
                  title: context.t.app.title,
                  minimize: context.t.window.minimize,
                  maximize: context.t.window.maximize,
                  restore: context.t.window.restore,
                  close: context.t.window.close,
                ),
                actions: ref.watch(windowChromeActionsProvider),
                maximized: state.maximized,
              ),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}
