import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:pure_uikit/pure_uikit.dart';



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
/// Defaults to Windows 11's caption, the same numbers `live_shell`'s
/// `ChromeMetrics.windows` publishes for the drag band; an app whose shell
/// plan picked a different set passes its own [PureCaptionMetrics] so the
/// strip and the band cannot disagree.
final class PureCaptionMetrics {
  /// Metrics for a strip [titleBarHeight] tall, with [buttonWidth] by
  /// [buttonHeight] caption buttons.
  const new({
    required this.titleBarHeight,
    required this.buttonWidth,
    required this.buttonHeight,
  });

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

/// The app-drawn caption strip: the language's own title-bar look, the app's
/// window seam.
///
/// Window operations always go through [WindowChromeActions]; what changes
/// with `UiConfig.language` is the *look*: macOS and cupertino draw the
/// traffic lights on the left with a centred title, yaru draws Ubuntu's
/// circular close on a headerbar, glass/neumorphic/wind paint their own
/// surfaces and buttons, and the token floor (material / fluent / forui)
/// keeps the Windows-11-style caption. Switching `UiConfig.language`
/// re-skins the strip along with everything else.
final class PureTitleBar extends StatefulWidget {
  /// A caption strip driven by [actions].
  const new({
    required this.labels,
    required this.actions,
    this.metrics = const PureCaptionMetrics.windows(),
    super.key,
  });

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
    final language = PureTheme.of(context).config.language;
    return switch (language) {
      // macOS windowing puts the traffic lights on the left and the title in
      // the middle; cupertino on the desktop is the same windowing.
      PureDesignLanguage.macos ||
      PureDesignLanguage.cupertino => _trafficLights(context),
      // Ubuntu's headerbar: centred title, one circular close on the right.
      PureDesignLanguage.yaru => _yaruHeaderBar(context),
      // Surfaces and buttons in the language's own material.
      PureDesignLanguage.glass => _glassStrip(context),
      PureDesignLanguage.neumorphic => _neumorphicStrip(context),
      PureDesignLanguage.wind => _windStrip(context),
      // The token floor doubles as the Windows-11 caption for fluent and the
      // forui and material languages, whose libraries ship no title bar.
      PureDesignLanguage.material ||
      PureDesignLanguage.fluent ||
      PureDesignLanguage.forui => _tokenStrip(context),
    };
  }

  // ---------------------------------------------------------------- shared

  Widget _dragRegion(BuildContext context) {
    final labels = widget.labels;
    return Expanded(
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
              style: TextStyle(fontSize: 12, color: PureTheme.of(context).colors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _centeredTitle(BuildContext context) {
    final labels = widget.labels;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => unawaited(widget.actions.startDragging()),
        onDoubleTap: () => unawaited(_toggle()),
        child: Center(
          child: Text(
            labels.title,
            style: TextStyle(fontSize: 13, color: PureTheme.of(context).colors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------- token / fluent

  Widget _tokenStrip(BuildContext context) {
    final colors = PureTheme.of(context).colors;
    final metrics = widget.metrics;
    return SizedBox(
      height: metrics.titleBarHeight,
      child: Material(
        color: colors.bgContainer,
        child: Row(
          children: [
            _dragRegion(context),
            _tokenCaptionButton(
              context,
              width: metrics.buttonWidth,
              tooltip: widget.labels.minimize,
              icon: Icons.horizontal_rule,
              onPressed: widget.actions.minimize,
            ),
            _tokenCaptionButton(
              context,
              width: metrics.buttonWidth,
              tooltip: _maximized ? widget.labels.restore : widget.labels.maximize,
              icon: _maximized ? Icons.filter_none : Icons.crop_square,
              onPressed: _toggle,
            ),
            _tokenCaptionButton(
              context,
              width: metrics.buttonWidth,
              tooltip: widget.labels.close,
              icon: Icons.close,
              destructiveHover: true,
              onPressed: widget.actions.close,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tokenCaptionButton(
    BuildContext context, {
    required double width,
    required String tooltip,
    required IconData icon,
    required Future<void> Function() onPressed,
    bool destructiveHover = false,
  }) {
    final colors = PureTheme.of(context).colors;
    return SizedBox(
      width: width,
      height: widget.metrics.buttonHeight,
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

  // ----------------------------------------------------- macos / cupertino

  /// The traffic lights: 12 px circles in macOS's colours and order, 8 px
  /// apart, 13 px in from the edge; the title sits centred. Hover reveals
  /// the glyphs the way macOS does.
  Widget _trafficLights(BuildContext context) {
    final theme = PureTheme.of(context);
    const height = 28.0;

    Widget light(
      Color color, {
      required IconData glyph,
      required Future<void> Function() onPressed,
      required String label,
    }) {
      return Tooltip(
        message: label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => unawaited(onPressed()),
            child: _HoverBuilder(
              builder: ({required hovered}) => Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: hovered ? Icon(glyph, size: 8, color: Colors.black.withValues(alpha: 0.55)) : null,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Material(
        color: theme.colors.bgContainer,
        child: Row(
          children: [
            const SizedBox(width: 13),
            light(
              const Color(0xFFFF5F57),
              glyph: Icons.close,
              onPressed: widget.actions.close,
              label: widget.labels.close,
            ),
            const SizedBox(width: 8),
            light(
              const Color(0xFFFEBC2E),
              glyph: Icons.remove,
              onPressed: widget.actions.minimize,
              label: widget.labels.minimize,
            ),
            const SizedBox(width: 8),
            light(
              const Color(0xFF28C840),
              glyph: _maximized ? Icons.crop_square : Icons.add,
              onPressed: _toggle,
              label: _maximized ? widget.labels.restore : widget.labels.maximize,
            ),
            _centeredTitle(context),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ yaru

  /// Ubuntu's headerbar: the title centred on a slightly taller bar and one
  /// circular close on the right that lights Yaru orange on hover.
  Widget _yaruHeaderBar(BuildContext context) {
    final theme = PureTheme.of(context);
    const height = 37.0;
    return SizedBox(
      height: height,
      child: Material(
        color: theme.colors.bgContainer,
        child: Row(
          children: [
            _centeredTitle(context),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Tooltip(
                message: widget.labels.close,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => unawaited(widget.actions.close()),
                    child: _HoverBuilder(
                      builder: ({required hovered}) => Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hovered ? const Color(0xFFE95420) : theme.colors.bgLayout,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: hovered ? Colors.white : theme.colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- glass

  Widget _glassStrip(BuildContext context) {
    final theme = PureTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    return SizedBox(
      height: 36,
      child: glass.GlassContainer(
        blur: glassTheme.blur,
        opacity: glassTheme.opacity,
        customBorderRadius: BorderRadius.zero,
        color: theme.colors.bgContainer,
        elevation: 0,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            _dragRegion(context),
            _glassIconButton(
              context,
              icon: Icons.horizontal_rule,
              tooltip: widget.labels.minimize,
              onPressed: widget.actions.minimize,
            ),
            _glassIconButton(
              context,
              icon: _maximized ? Icons.filter_none : Icons.crop_square,
              tooltip: _maximized ? widget.labels.restore : widget.labels.maximize,
              onPressed: _toggle,
            ),
            _glassIconButton(
              context,
              icon: Icons.close,
              tooltip: widget.labels.close,
              destructive: true,
              onPressed: widget.actions.close,
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required Future<void> Function() onPressed,
    bool destructive = false,
  }) {
    final theme = PureTheme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => unawaited(onPressed()),
        hoverColor: (destructive ? theme.colors.error : theme.colors.primary).withValues(alpha: 0.18),
        child: SizedBox(
          width: 40,
          child: Icon(icon, size: 16, color: theme.colors.textSecondary, semanticLabel: tooltip),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ neumorphic

  Widget _neumorphicStrip(BuildContext context) {
    final surface = neu.NeuTheme.of(context);
    return SizedBox(
      height: 38,
      child: neu.NeuContainer(
        baseColor: surface.baseColor,
        depth: surface.depth,
        distance: surface.distance,
        borderRadius: BorderRadius.zero,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            _dragRegion(context),
            _neuIconButton(
              context,
              icon: Icons.horizontal_rule,
              tooltip: widget.labels.minimize,
              onPressed: widget.actions.minimize,
            ),
            _neuIconButton(
              context,
              icon: _maximized ? Icons.filter_none : Icons.crop_square,
              tooltip: _maximized ? widget.labels.restore : widget.labels.maximize,
              onPressed: _toggle,
            ),
            _neuIconButton(context, icon: Icons.close, tooltip: widget.labels.close, onPressed: widget.actions.close),
          ],
        ),
      ),
    );
  }

  Widget _neuIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required Future<void> Function() onPressed,
  }) {
    final colors = PureTheme.of(context).colors;
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: neu.NeuButton(
          onPressed: () => unawaited(onPressed()),
          child: SizedBox(
            width: 26,
            height: 26,
            child: Icon(icon, size: 14, color: colors.textSecondary, semanticLabel: tooltip),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ wind

  Widget _windStrip(BuildContext context) {
    return SizedBox(
      height: 36,
      child: wind.WCard(
        className: 'rounded-none border-0 border-b border-gray-200 dark:border-gray-700',
        child: wind.WDiv(
          className: 'flex flex-row h-full',
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => unawaited(widget.actions.startDragging()),
                onDoubleTap: () => unawaited(_toggle()),
                child: wind.WDiv(
                  className: 'flex items-center px-3 h-full',
                  children: [
                    wind.WText(
                      widget.labels.title,
                      className: 'text-xs text-gray-500 dark:text-gray-400',
                    ),
                  ],
                ),
              ),
            ),
            _windIconButton(
              icon: Icons.horizontal_rule,
              tooltip: widget.labels.minimize,
              onPressed: widget.actions.minimize,
            ),
            _windIconButton(
              icon: _maximized ? Icons.filter_none : Icons.crop_square,
              tooltip: _maximized ? widget.labels.restore : widget.labels.maximize,
              onPressed: _toggle,
            ),
            _windIconButton(icon: Icons.close, tooltip: widget.labels.close, onPressed: widget.actions.close),
          ],
        ),
      ),
    );
  }

  Widget _windIconButton({
    required IconData icon,
    required String tooltip,
    required Future<void> Function() onPressed,
  }) {
    return wind.WButton(
      className: 'rounded-none w-10 h-full text-gray-500 dark:text-gray-400'
          ' hover:bg-gray-200 dark:hover:bg-gray-700',
      onTap: () => unawaited(onPressed()),
      child: Icon(icon, size: 15, semanticLabel: tooltip),
    );
  }
}

/// A tiny hover-bool builder — macOS traffic lights only reveal their glyphs
/// while the pointer is over them.
class _HoverBuilder extends StatefulWidget {
  const new({required this.builder});

  /// Called with the current hover state.
  final Widget Function({required bool hovered}) builder;

  @override
  State<_HoverBuilder> createState() => _HoverBuilderState();
}

final class _HoverBuilderState extends State<_HoverBuilder> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.builder(hovered: _hovered),
    );
  }
}
