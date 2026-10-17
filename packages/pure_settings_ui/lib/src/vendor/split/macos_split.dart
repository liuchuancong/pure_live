import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pure_settings_ui/src/vendor/split/settings_page_header.dart';
import 'package:pure_settings_ui/src/vendor/split/sidebar_button.dart';
import 'package:pure_settings_ui/src/vendor/split/sidebar_keyboard.dart';
import 'package:pure_settings_ui/src/vendor/split/sidebar_row.dart';
import 'package:pure_settings_ui/src/vendor/split/sidebar_section.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/macos_settings_switch.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/macos_settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';

// The macOS 26/27 System Settings split view (a SwiftUI
// `NavigationSplitView`), measured on macOS 27. All sizes are in points.

/// The unified toolbar: the sidebar's top strip (where the traffic lights
/// sit) and the detail pane's title bar.
const double kMacosToolbarHeight = 52;

/// Sidebar rows (NSTableView rowHeight, "medium" sidebar size).
const double kMacosSidebarRowHeight = 32;

/// The selection is inset this far from both sidebar edges...
const double _kSelectionInset = 10;

/// ...with these corners.
const double _kSelectionRadius = 8;

/// Row content starts 16 from the sidebar edge (6 inside the selection).
const double _kContentInset = 6;

/// A 20pt icon at 19 (3 into the content) and the label at 46.
const double _kIconSize = 20;
const double _kIconStart = 3;
const double _kIconGap = 7;

/// Section headers: 11pt bold in a 19pt row, text at 14.
const double _kHeaderRowHeight = 19;
const double _kHeaderStart = 14;

/// Space between two sidebar sections, with or without a header.
const double kMacosSidebarSectionGap = 13;

/// The selection of a key window: [SettingsThemeData.selectedTileColor].
/// In an inactive window it turns grey (measured #D7D7D6 / #424742 on the
/// replica's glass; `unemphasizedSelectedContentBackgroundColor` is #DCDCDC /
/// #464646), and the label keeps its color.
const Color _kInactiveSelectionLight = Color(0xFFD7D7D7);
const Color _kInactiveSelectionDark = Color(0xFF464646);

/// Plain symbols (not the colored squircles of System Settings) take the
/// accent color, as SwiftUI sidebars draw them.
const Color _kSymbolTintLight = Color(0xFF0077FF);
const Color _kSymbolTintDark = Color(0xFF008FFF);

/// Section headers render in the tertiary label color.
const Color _kHeaderLight = Color(0xFFA0A0A0);
const Color _kHeaderDark = Color(0xFF5A5A5A);

/// The toolbar title renders grey, not in the label color.
const Color _kToolbarTitleLight = Color(0xFF4C4C4C);
const Color _kToolbarTitleDark = Color(0xFFE9E9E9);

/// The focus ring ([macosFocusColor]), 3pt outside the row's selection
/// shape.
const double kMacosFocusRingWidth = 3;

/// 13pt body text, semibold when selected.
const TextStyle _kLabelStyle = kMacosBodyStyle;

/// Section headers: 11pt bold, set as tight as SwiftUI draws them.
const TextStyle _kHeaderStyle = TextStyle(
  fontSize: 11,
  height: 14 / 11,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.1,
);

/// The toolbar title: SF Pro Semibold 15.
const TextStyle _kToolbarTitleStyle = TextStyle(
  fontSize: 15,
  height: 19 / 15,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.2,
);

bool _isDark(BuildContext context) =>
    macosIsDark(context, SettingsTheme.of(context).themeData);

/// The hairline between the sidebar and the detail pane (0.5pt). The glass
/// sidebar's edge barely shows in System Settings; this keeps it as faint.
Color macosSidebarEdgeColor(SettingsThemeData theme) {
  final page = theme.settingsListBackground;
  final isDark =
      page != null &&
      ThemeData.estimateBrightnessForColor(page) == Brightness.dark;
  return isDark ? const Color(0x59000000) : const Color(0x0F000000);
}

/// Tracks whether the app's window is active (AppKit's key window), so the
/// sidebar selection can turn grey when it isn't. Internal.
///
/// Flutter reports [AppLifecycleState.inactive] when the app loses the
/// focus (on the web, when the browser window does).
class MacosWindowActivity extends StatefulWidget {
  const MacosWindowActivity({super.key, required this.child});

  final Widget child;

  /// Whether the window at [context] is active. True outside a
  /// [MacosWindowActivity].
  static bool isActiveOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_MacosWindowActiveScope>()
          ?.active ??
      true;

  @override
  State<MacosWindowActivity> createState() => _MacosWindowActivityState();
}

class _MacosWindowActivityState extends State<MacosWindowActivity>
    with WidgetsBindingObserver {
  late bool _active = _isActive(WidgetsBinding.instance.lifecycleState);

  static bool _isActive(AppLifecycleState? state) =>
      state == null || state == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = _isActive(state);
    if (active != _active) setState(() => _active = active);
  }

  @override
  Widget build(BuildContext context) =>
      _MacosWindowActiveScope(active: _active, child: widget.child);
}

class _MacosWindowActiveScope extends InheritedWidget {
  const _MacosWindowActiveScope({required this.active, required super.child});

  final bool active;

  @override
  bool updateShouldNotify(_MacosWindowActiveScope oldWidget) =>
      active != oldWidget.active;
}

/// A row of the macOS System Settings sidebar: a tile in the list pane of a
/// macOS style split view. Internal.
///
/// 32pt tall, a 20pt icon and the 13pt label; the selected row is a
/// rounded rect inset 10pt, in the accent color with a white semibold label
/// while the window is active, grey otherwise. A plain [Icon] takes the
/// accent color (white on the accent). No hover highlight, like AppKit
/// sidebars. Descriptions and values are not shown.
class MacosSidebarItem extends SidebarRow {
  const MacosSidebarItem(
    super.tile, {
    super.key,
    required super.selected,
    super.semanticsSelected,
    required this.opensPage,
  });

  /// The tile opens a page, so the arrow keys select it.
  final bool opensPage;

  @override
  State<MacosSidebarItem> createState() => _MacosSidebarItemState();
}

class _MacosSidebarItemState extends State<MacosSidebarItem>
    with SidebarRowState<MacosSidebarItem> {
  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    ...actions,
    SidebarSelectIntent: CallbackAction<SidebarSelectIntent>(
      onInvoke: (_) {
        if (widget.opensPage && !widget.selected) activateRow();
        return null;
      },
    ),
  };

  @override
  String get debugLabel => 'MacosSidebarItem';

  bool get _canPress => tile.enabled && tile.onPressed != null;

  @override
  void activateRow() {
    if (_canPress) tile.onPressed!(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = SettingsTheme.of(context).themeData;
    final textScaler = MediaQuery.textScalerOf(context);
    final isDark = _isDark(context);
    final active = MacosWindowActivity.isActiveOf(context);
    final selected = widget.selected;
    final emphasized = selected && active;
    final enabled = tile.enabled;

    final Color? fill = !selected
        ? null
        : active
        ? theme.selectedTileColor
        : (isDark ? _kInactiveSelectionDark : _kInactiveSelectionLight);
    // AppKit draws sidebar labels vibrant: plain black or white.
    final label = theme.settingsTileTextColor?.withValues(alpha: 1);
    final Color? textColor = !enabled
        ? theme.inactiveTitleColor
        : emphasized
        ? (theme.selectedTileTextColor ?? label)
        : label;
    final Color? iconColor = !enabled
        ? theme.inactiveTitleColor
        : emphasized
        ? (theme.selectedTileIconColor ?? textColor)
        : (isDark ? _kSymbolTintDark : _kSymbolTintLight);

    final leading = tile.leading;
    final line = buildLine(
      leading: leading == null
          ? null
          : Padding(
              padding: const EdgeInsetsDirectional.only(
                start: _kIconStart,
                end: _kIconGap,
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: iconColor, size: _kIconSize),
                child: leading,
              ),
            ),
      titleStyle: (theme.tileTextStyle ?? _kLabelStyle).copyWith(
        color: textColor,
        fontWeight: selected ? FontWeight.w600 : null,
      ),
      trailingStyle: _kLabelStyle.copyWith(color: textColor),
      trailingIconColor: textColor,
      endPadding: const EdgeInsetsDirectional.only(start: 6),
      toggle: !tile.isSwitch
          ? null
          : CupertinoTheme(
              data: CupertinoTheme.of(context).copyWith(
                brightness: isDark ? Brightness.dark : Brightness.light,
              ),
              // The row takes the focus when it can be pressed; otherwise
              // the switch does, so the keyboard can reach it. A row with
              // onPressed keeps its switch as a node of its own (both have
              // a tap action), labelled with the title; otherwise the
              // switch merges into the row: "Title, switch, on".
              child: ExcludeFocus(
                excluding: _canPress,
                child: tile.labelSwitchIfSeparate(
                  MacosSettingsSwitch(
                    value: tile.initialValue,
                    onChanged: enabled ? tile.onToggle : null,
                    // As in a list: inactiveSwitchColor replaces the color
                    // of a disabled switch.
                    activeTrackColor: enabled
                        ? tile.activeSwitchColor
                        : (theme.inactiveSwitchColor ?? tile.activeSwitchColor),
                  ),
                ),
              ),
            ),
    );

    final Widget item = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kSelectionInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(_kSelectionRadius),
        ),
        position: DecorationPosition.background,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: showsFocusRing && _canPress
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(_kSelectionRadius),
                  border: Border.all(
                    color: macosFocusColor(isDark: isDark),
                    width: kMacosFocusRingWidth,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                )
              : const BoxDecoration(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: kMacosSidebarRowHeight,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _kContentInset,
                vertical: textScaler.scale(4),
              ),
              child: line,
            ),
          ),
        ),
      ),
    );

    return IgnorePointer(
      ignoring: !enabled,
      child: Semantics(
        container: true,
        button: _canPress,
        enabled: enabled,
        selected: widget.semanticsSelected,
        child: FocusableActionDetector(
          enabled: _canPress,
          focusNode: focusNode,
          actions: _actions,
          onShowFocusHighlight: handleFocusHighlight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: !_canPress,
            onTap: _canPress ? handleTap : null,
            child: item,
          ),
        ),
      ),
    );
  }
}

/// A group of the macOS sidebar: an optional 11pt bold header over its
/// rows. Sections are 13pt apart ([MacosSidebarSectionGap]). Internal.
class MacosSidebarSection extends SidebarSection {
  const MacosSidebarSection({
    super.key,
    required super.title,
    required super.tiles,
    super.titlePadding,
  });

  @override
  Widget buildHeader(
    BuildContext context,
    SettingsThemeData theme,
    Widget title,
  ) {
    final textScaler = MediaQuery.textScalerOf(context);
    final style = theme.titleTextStyle ?? _kHeaderStyle;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kHeaderRowHeight),
      child: Padding(
        padding:
            titlePadding ??
            EdgeInsetsDirectional.only(
              start: _kHeaderStart,
              end: _kHeaderStart,
              top: textScaler.scale(3),
              bottom: textScaler.scale(2),
            ),
        child: DefaultTextStyle(
          style: style.copyWith(
            color:
                style.color ??
                (_isDark(context) ? _kHeaderDark : _kHeaderLight),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: title,
        ),
      ),
    );
  }
}

/// The 13pt space between two sections of the macOS sidebar. Internal.
class MacosSidebarSectionGap extends StatelessWidget {
  const MacosSidebarSectionGap({super.key});

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: kMacosSidebarSectionGap);
}

/// The top of the macOS sidebar: the 52pt strip under the (transparent)
/// title bar, where the traffic lights sit. With [onBack] (the split view
/// can be left), a round glass back button at its end, where SwiftUI puts
/// the sidebar button. Internal.
class MacosSidebarTopBar extends StatelessWidget {
  const MacosSidebarTopBar({super.key, required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: kMacosToolbarHeight,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: onBack == null
              ? null
              : Padding(
                  padding: const EdgeInsetsDirectional.only(end: 7),
                  child: MacosNavigationCapsule(
                    onBack: onBack!,
                    showForward: false,
                  ),
                ),
        ),
      ),
    );
  }
}

/// The toolbar of a macOS System Settings pane: 52pt tall, the Liquid
/// Glass back/forward capsule when there is a page to go back to, and the
/// page title in 15pt semibold grey (at 20pt without the capsule, 13pt
/// after it). There is no large title in the content. Internal.
class MacosToolbar extends StatelessWidget {
  const MacosToolbar({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
  });

  final Widget? title;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark(context);
    final title = this.title;
    final actions = this.actions;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: kMacosToolbarHeight,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: onBack == null ? 20 : 8,
            end: 20,
          ),
          child: Row(
            children: [
              if (onBack != null) ...[
                MacosNavigationCapsule(onBack: onBack!),
                const SizedBox(width: 13),
              ],
              Expanded(
                child: title == null
                    ? const SizedBox.shrink()
                    : Semantics(
                        header: true,
                        // AppKit centers the title's text box (y 16.5, 19
                        // tall): 1pt above where Flutter puts the line.
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: DefaultTextStyle(
                            style: _kToolbarTitleStyle.copyWith(
                              color: isDark
                                  ? _kToolbarTitleDark
                                  : _kToolbarTitleLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            child: title,
                          ),
                        ),
                      ),
              ),
              if (actions != null && actions.isNotEmpty)
                Row(mainAxisSize: MainAxisSize.min, children: actions),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Liquid Glass back/forward capsule of the System Settings toolbar:
/// 73x36 with `‹` and `›` split by a hairline (forward stays disabled), or a
/// 36pt circle with only `‹`. Internal.
class MacosNavigationCapsule extends StatelessWidget {
  const MacosNavigationCapsule({
    super.key,
    required this.onBack,
    this.showForward = true,
  });

  final VoidCallback onBack;
  final bool showForward;

  @override
  Widget build(BuildContext context) {
    final theme = SettingsTheme.of(context).themeData;
    final isDark = _isDark(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    // Toolbar glyphs render in plain black or white; disabled ones at 30%.
    final label = (theme.settingsTileTextColor ?? const Color(0xD8000000))
        .withValues(alpha: 1);
    final disabled = label.withValues(alpha: 0.3);
    return Container(
      width: showForward ? 73 : 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFFCFCFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0x24FFFFFF) : const Color(0x21000000),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33000000) : const Color(0x12000000),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _CapsuleButton(
              label: settingsBackLabel(context),
              onPressed: onBack,
              isDark: isDark,
              child: _MacosToolbarChevron(color: label, pointsLeft: !isRtl),
            ),
          ),
          if (showForward) ...[
            Container(
              width: 1,
              height: 20,
              color: isDark ? const Color(0x26FFFFFF) : const Color(0x33000000),
            ),
            Expanded(
              child: _CapsuleButton(
                label: 'Forward',
                onPressed: null,
                isDark: isDark,
                child: _MacosToolbarChevron(color: disabled, pointsLeft: isRtl),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One half of the capsule: it tints while pressed and has no hover state.
class _CapsuleButton extends SidebarButton {
  const _CapsuleButton({
    required String label,
    required super.onPressed,
    required this.isDark,
    required this.child,
  }) : super(semanticLabel: label, hasEnabledState: true, tracksHover: false);

  final bool isDark;
  final Widget child;

  @override
  Widget buildButton(BuildContext context, SidebarButtonStates states) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: states.pressed
            ? (isDark ? const Color(0x1FFFFFFF) : const Color(0x14000000))
            : null,
        borderRadius: BorderRadius.circular(18),
        border: states.focused
            ? Border.all(color: macosFocusColor(isDark: isDark), width: 3)
            : null,
      ),
      alignment: Alignment.center,
      child: ExcludeSemantics(child: child),
    );
  }
}

/// The toolbar's `chevron.left` / `chevron.right`: 8x14pt of ink with a
/// 2pt round stroke.
class _MacosToolbarChevron extends StatelessWidget {
  const _MacosToolbarChevron({required this.color, required this.pointsLeft});

  final Color color;
  final bool pointsLeft;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(8, 14),
      painter: _ToolbarChevronPainter(color: color, pointsLeft: pointsLeft),
    );
  }
}

class _ToolbarChevronPainter extends CustomPainter {
  const _ToolbarChevronPainter({required this.color, required this.pointsLeft});

  final Color color;
  final bool pointsLeft;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.0;
    const inset = stroke / 2;
    double x(double fromLeft) => pointsLeft ? fromLeft : size.width - fromLeft;
    canvas.drawPath(
      Path()
        ..moveTo(x(size.width - inset), inset)
        ..lineTo(x(inset), size.height / 2)
        ..lineTo(x(size.width - inset), size.height - inset),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ToolbarChevronPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pointsLeft != pointsLeft;
}
