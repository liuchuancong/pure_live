import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:live_shell/live_shell.dart' show ChromeMetrics;
import 'package:live_uikit/live_uikit.dart';

import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:window_manager/window_manager.dart' show DragToMoveArea, WindowListener, windowManager;

/// What the caption strip does when its buttons are pressed and its surface
/// is dragged.
///
/// A seam, not a wrapper: the default implementation talks to
/// `windowManager`, and the tests hand in a fake so a widget test can assert
/// the buttons' wiring without a method channel in the room.
abstract interface class WindowChromeActions {
  /// Minimises the window.
  Future<void> minimize();

  /// Toggles maximised state; the strip shows the matching glyph.
  Future<void> toggleMaximize();

  /// Whether the window is currently maximised.
  Future<bool> isMaximized();

  /// Asks the window to close. The shell's close policy owns what that means.
  Future<void> close();

  /// Starts an interactive drag of the window.
  Future<void> startDragging();
}

/// The default actions: [windowManager] is the only window this strip drives.
final class WindowManagerChromeActions implements WindowChromeActions {
  /// The singleton instance; the class is stateless.
  const new();

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> toggleMaximize() async {
    // window_manager exposes no toggle; maximise/restore is the pair.
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Future<bool> isMaximized() => windowManager.isMaximized();

  @override
  Future<void> close() => windowManager.close();

  @override
  Future<void> startDragging() => windowManager.startDragging();
}

/// The app-drawn caption strip: drag region, then minimise, maximise and
/// close on the right.
///
/// The strip's geometry comes from [ChromeMetrics.windows] — the same source
/// the shell's chrome plan reads, so the drag band, the buttons and any
/// future popup anchored under the strip cannot disagree about the height.
/// Colours come from the ambient [Theme], which is seeded from the same
/// config as every design language, so the strip follows light/dark and the
/// accent without owning a token of its own.
///
/// The frame itself is taken over natively (`BDW_CUSTOM_FRAME`): resize and
/// Aero Snap stay the operating system's, and this widget only owns the
/// strip's pixels and the buttons' semantics.
final class WindowTitleBar extends StatefulWidget {
  /// A caption strip driven by [actions].
  const new({super.key, this.actions = const WindowManagerChromeActions()});

  /// The button and drag behaviours under test.
  final WindowChromeActions actions;

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

final class _WindowTitleBarState extends State<WindowTitleBar> with WindowListener {
  static const ChromeMetrics _metrics = ChromeMetrics.windows();

  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(
      widget.actions.isMaximized().then((maximized) {
        if (mounted) {
          setState(() => _maximized = maximized);
        }
      }),
    );
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  Future<void> _toggle() async {
    await widget.actions.toggleMaximize();
    // The listener events cover real maximise/restore; the toggle's own echo
    // keeps the glyph honest in the environments where the event lands late.
    final maximized = await widget.actions.isMaximized();
    if (mounted) {
      setState(() => _maximized = maximized);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = LiveTheme.of(context).colors;
    return SizedBox(
      height: _metrics.titleBarHeight,
      child: Material(
        color: colors.bgContainer,
        child: Row(
          children: [
            Expanded(
              child: DragToMoveArea(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () => unawaited(_toggle()),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 12),
                      child: Text(
                        context.t.app.title,
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _CaptionButton(
              width: _metrics.buttonWidth,
              height: _metrics.buttonHeight,
              tooltip: context.t.window.minimize,
              icon: Icons.horizontal_rule,
              onPressed: widget.actions.minimize,
            ),
            _CaptionButton(
              width: _metrics.buttonWidth,
              height: _metrics.buttonHeight,
              tooltip: _maximized ? context.t.window.restore : context.t.window.maximize,
              icon: _maximized ? Icons.filter_none : Icons.crop_square,
              onPressed: _toggle,
            ),
            _CaptionButton(
              width: _metrics.buttonWidth,
              height: _metrics.buttonHeight,
              tooltip: context.t.window.close,
              icon: Icons.close,
              destructiveHover: true,
              onPressed: widget.actions.close,
            ),
          ],
        ),
      ),
    );
  }
}

/// One caption button: a flat hit target that lights on hover, red for close.
final class _CaptionButton extends StatelessWidget {
  const new({
    required this.width,
    required this.height,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.destructiveHover = false,
  });

  final double width;
  final double height;
  final String tooltip;
  final IconData icon;
  final Future<void> Function() onPressed;
  final bool destructiveHover;

  @override
  Widget build(BuildContext context) {
    final colors = LiveTheme.of(context).colors;
    return SizedBox(
      width: width,
      height: height,
      child: Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 600),
        child: InkWell(
          onTap: () => unawaited(onPressed()),
          hoverColor: destructiveHover ? const Color(0xFFE81123) : colors.text.withValues(alpha: 0.06),
          child: Icon(icon, size: 16, color: colors.textSecondary, semanticLabel: tooltip),
        ),
      ),
    );
  }
}
