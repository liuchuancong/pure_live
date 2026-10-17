import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// What the caption strip does when its buttons are pressed and its surface
/// is dragged.
///
/// A seam, not a wrapper: an app hands in an implementation that talks to its
/// window plugin (the app default goes through `window_manager`), and tests
/// hand in a fake so a widget test can assert the buttons' wiring without a
/// method channel in the room. The core keeps only the interface — the
/// windowing dependency never crosses into this package.
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

/// The strip's geometry, in logical pixels.
///
/// Values default to Windows 11's caption, the same numbers
/// `live_shell`'s `ChromeMetrics.windows` publishes for the drag band; an app
/// whose shell plan picked a different set passes its own [PureCaptionMetrics]
/// so the strip and the band cannot disagree.
final class PureCaptionMetrics {
  /// Metrics for a strip [titleBarHeight] tall, with [buttonWidth] by
  /// [buttonHeight] caption buttons.
  const new({required this.titleBarHeight, required this.buttonWidth, required this.buttonHeight});

  /// Windows 11's caption: 32 logical pixels tall, 46 wide per button.
  const new windows() : this(titleBarHeight: 32, buttonWidth: 46, buttonHeight: 32);

  /// The strip's height.
  final double titleBarHeight;

  /// One caption button's width.
  final double buttonWidth;

  /// One caption button's height.
  final double buttonHeight;
}

/// The strip's localised strings: the window title and the buttons' tooltips.
final class PureTitleBarLabels {
  /// Labels for the strip.
  const new({
    required this.title,
    required this.minimize,
    required this.maximize,
    required this.restore,
    required this.close,
  });

  /// The window title drawn at the strip's start.
  final String title;

  /// The minimise button's tooltip.
  final String minimize;

  /// The maximise button's tooltip on a restored window.
  final String maximize;

  /// The maximise button's tooltip on a maximised window.
  final String restore;

  /// The close button's tooltip.
  final String close;
}

/// The app-drawn caption strip, shared by every design language: drag region,
/// then minimise, maximise and close on the right.
///
/// This is the floor of the window-chrome contract: a design language may
/// draw its own native caption instead, but every language resolves to a strip
/// with working buttons — never to none. Colours come from the ambient
/// [PureTheme], so the strip follows light/dark and the accent without owning
/// a token of its own; the geometry comes from [metrics].
///
/// The frame itself is taken over natively (`BDW_CUSTOM_FRAME`): resize and
/// Aero Snap stay the operating system's, and this widget only owns the
/// strip's pixels and the buttons' semantics.
final class PureTitleBar extends StatefulWidget {
  /// A caption strip driven by [actions].
  const new({required this.labels, required this.actions, this.metrics = const PureCaptionMetrics.windows(), super.key});

  /// The strip's localised strings.
  final PureTitleBarLabels labels;

  /// The button and drag behaviours under test.
  final WindowChromeActions actions;

  /// The strip's geometry.
  final PureCaptionMetrics metrics;

  @override
  State<PureTitleBar> createState() => _PureTitleBarState();
}

final class _PureTitleBarState extends State<PureTitleBar> {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _readMaximized());
  }

  Future<void> _readMaximized() async {
    final maximized = await widget.actions.isMaximized();
    if (mounted) {
      setState(() => _maximized = maximized);
    }
  }

  Future<void> _toggle() async {
    await widget.actions.toggleMaximize();
    // The toggle's own echo keeps the glyph honest; a window-listener host
    // additionally receives the real maximise/restore events.
    final maximized = await widget.actions.isMaximized();
    if (mounted) {
      setState(() => _maximized = maximized);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = PureTheme.of(context).colors;
    final labels = widget.labels;
    final metrics = widget.metrics;
    return SizedBox(
      height: metrics.titleBarHeight,
      child: Material(
        color: colors.bgContainer,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => unawaited(widget.actions.startDragging()),
                onDoubleTap: () => unawaited(_toggle()),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    child: Text(
                      labels.title,
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
            _CaptionButton(
              width: metrics.buttonWidth,
              height: metrics.buttonHeight,
              tooltip: labels.minimize,
              icon: Icons.horizontal_rule,
              onPressed: widget.actions.minimize,
            ),
            _CaptionButton(
              width: metrics.buttonWidth,
              height: metrics.buttonHeight,
              tooltip: _maximized ? labels.restore : labels.maximize,
              icon: _maximized ? Icons.filter_none : Icons.crop_square,
              onPressed: _toggle,
            ),
            _CaptionButton(
              width: metrics.buttonWidth,
              height: metrics.buttonHeight,
              tooltip: labels.close,
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
    final colors = PureTheme.of(context).colors;
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
