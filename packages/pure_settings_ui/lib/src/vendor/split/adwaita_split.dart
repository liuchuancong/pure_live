import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/split/settings_page_header.dart';
import 'package:pure_settings_ui/src/vendor/split/sidebar_button.dart';
import 'package:pure_settings_ui/src/vendor/split/sidebar_row.dart';
import 'package:pure_settings_ui/src/vendor/split/sidebar_section.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/adwaita_settings_switch.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/adwaita_settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/adwaita_symbolic_icons.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_press.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';

// GNOME Settings 51 (libadwaita 1.10 `AdwNavigationSplitView` with a
// `.navigation-sidebar` list), measured against real GNOME 48/50 captures.
// All sizes are logical pixels (1 CSS px).

/// Flat header bars: the sidebar's and the content's.
const double kAdwaitaHeaderBarHeight = 46;

/// Panel rows of the GNOME Settings sidebar are 43 tall, 2 apart.
const double kAdwaitaSidebarRowHeight = 43;

/// `.navigation-sidebar > row` margin: 0 6 2 6.
const double _kRowMarginH = 6;
const double _kRowMarginBottom = 2;
const double _kRowRadius = 9;

/// The 16px symbolic icon starts 20 from the sidebar edge (6 margin + 14),
/// the label at 48 (12 after the icon).
const double _kRowPadding = 14;
const double _kIconSize = 16;
const double _kIconGap = 12;

/// `.navigation-sidebar` list padding: 6 top, 4 bottom.
const double kAdwaitaSidebarPaddingTop = 6;
const double kAdwaitaSidebarPaddingBottom = 4;

/// Flat header bar buttons: 34x34 with 9 corners, 6 from the bar's edge.
const double _kButtonSize = 34;
const double _kBarPadding = 6;

/// Row backgrounds, as shares of the foreground color: hover 7%, selected
/// 10%, selected and hovered 13%, pressed 16% (selected and pressed 19%).
const double _kHover = 0.07;
const double _kSelectedHover = 0.13;
const double _kPressed = 0.16;
const double _kSelectedPressed = 0.19;

Color _share(Color foreground, double share) =>
    foreground.withValues(alpha: foreground.a * share);

/// The 2px focus ring of a row or a header bar button.
BoxDecoration _focusRing(bool isDark) => BoxDecoration(
  borderRadius: BorderRadius.circular(_kRowRadius),
  border: adwaitaFocusBorder(isDark: isDark),
);

/// `--sidebar-border-color`, the 1px line on the sidebar's content side.
Color adwaitaSidebarBorderColor(SettingsThemeData theme) => adwaitaIsDark(theme)
    ? const Color.fromRGBO(0, 0, 6, 0.36)
    : const Color.fromRGBO(0, 0, 6, 0.07);

/// A row of the GNOME Settings sidebar: a tile in the list pane of a GNOME
/// style split view (also with one pane, where the sidebar is the first
/// page). Internal.
///
/// 43 tall with 6px side margins and 9px corners, a 16px symbolic icon and
/// the 14.67px label, which stays in the foreground color when selected.
/// Hover 7%, selected 10% (a neutral grey, not the accent), selected and
/// hovered 13%, pressed 16% of the foreground; a 2px accent focus ring.
/// Like GNOME rows, a switch row toggles when the row is clicked.
/// Descriptions and values are not shown.
class AdwaitaSidebarRow extends SidebarRow {
  const AdwaitaSidebarRow(
    super.tile, {
    super.key,
    required super.selected,
    super.semanticsSelected,
  });

  @override
  State<AdwaitaSidebarRow> createState() => _AdwaitaSidebarRowState();
}

class _AdwaitaSidebarRowState extends State<AdwaitaSidebarRow>
    with SidebarRowState<AdwaitaSidebarRow>, TilePressTracking {
  bool _hovered = false;

  @override
  String get debugLabel => 'AdwaitaSidebarRow';

  bool get _hasAction =>
      tile.isSwitch ? tile.onToggle != null : tile.onPressed != null;

  bool get _activatable => tile.enabled && _hasAction;

  @override
  void activateRow() {
    if (!_activatable) return;
    if (tile.isSwitch) {
      tile.onToggle!(!tile.initialValue);
    } else {
      tile.onPressed!(context);
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    // GTK shows `:active` as soon as the button goes down.
    if (event.buttons == kPrimaryButton) startPress(event);
  }

  @override
  void didUpdateWidget(AdwaitaSidebarRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_activatable) {
      resetPress();
      _hovered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = SettingsTheme.of(context).themeData;
    final textScaler = MediaQuery.textScalerOf(context);
    final foreground = adwaitaForegroundOf(theme);
    final isDark = adwaitaIsDark(theme);
    final enabled = tile.enabled;
    final selected = widget.selected;
    final pressed = _activatable && this.pressed;
    final hovered = _activatable && _hovered;

    final Color background;
    if (selected) {
      background = pressed
          ? _share(foreground, _kSelectedPressed)
          : hovered
          ? _share(foreground, _kSelectedHover)
          : (theme.selectedTileColor ?? _share(foreground, 0.10));
    } else {
      background = pressed
          ? _share(foreground, _kPressed)
          : hovered
          ? _share(foreground, _kHover)
          : _share(foreground, 0);
    }

    final textColor = !enabled
        ? (theme.inactiveTitleColor ?? _share(foreground, 0.5))
        : selected
        ? (theme.selectedTileTextColor ?? foreground)
        : foreground;
    final iconColor = !enabled
        ? textColor
        : selected
        ? (theme.selectedTileIconColor ?? foreground)
        : (theme.leadingIconsColor ?? foreground);

    final leading = tile.leading;
    final line = buildLine(
      leading: leading == null
          ? null
          : Padding(
              padding: const EdgeInsetsDirectional.only(end: _kIconGap),
              child: IconTheme.merge(
                data: IconThemeData(color: iconColor, size: _kIconSize),
                child: leading,
              ),
            ),
      titleStyle: (theme.tileTextStyle ?? kAdwaitaBodyStyle).copyWith(
        color: textColor,
      ),
      trailingStyle: kAdwaitaBodyStyle.copyWith(color: textColor),
      trailingIconColor: iconColor,
      endPadding: const EdgeInsetsDirectional.only(start: 6),
      // The row takes the focus and the clicks, like `AdwSwitchRow`.
      toggle: !tile.isSwitch
          ? null
          : ExcludeFocus(
              child: AdwaitaSettingsSwitch(
                value: tile.initialValue,
                onChanged: enabled ? tile.onToggle : null,
                // As in a list: inactiveSwitchColor replaces the color of a
                // disabled switch.
                activeTrackColor: enabled
                    ? tile.activeSwitchColor
                    : (theme.inactiveSwitchColor ?? tile.activeSwitchColor),
                brightness: isDark ? Brightness.dark : Brightness.light,
              ),
            ),
    );

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final box = AnimatedContainer(
      duration: reduceMotion ? Duration.zero : kAdwaitaHighlightDuration,
      curve: kAdwaitaHighlightCurve,
      constraints: const BoxConstraints(minHeight: kAdwaitaSidebarRowHeight),
      padding: EdgeInsets.symmetric(
        horizontal: _kRowPadding,
        vertical: textScaler.scale(4),
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(_kRowRadius),
      ),
      foregroundDecoration: showsFocusRing && _activatable
          ? _focusRing(isDark)
          : null,
      child: line,
    );

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: _kRowMarginH,
        end: _kRowMarginH,
        bottom: _kRowMarginBottom,
      ),
      child: MergeSemantics(
        child: Semantics(
          button: !tile.isSwitch && tile.onPressed != null,
          // A row that does nothing has no enabled state, like a list row.
          enabled: _hasAction ? enabled : null,
          selected: widget.semanticsSelected,
          onTap: _activatable ? activateRow : null,
          child: IgnorePointer(
            ignoring: !enabled,
            child: FocusableActionDetector(
              enabled: _activatable,
              focusNode: focusNode,
              actions: actions,
              onShowFocusHighlight: handleFocusHighlight,
              child: MouseRegion(
                onEnter: (_) {
                  if (_activatable && !_hovered) {
                    setState(() => _hovered = true);
                  }
                },
                onExit: (_) {
                  if (_hovered) setState(() => _hovered = false);
                },
                child: Listener(
                  onPointerDown: _activatable ? _handlePointerDown : null,
                  onPointerMove: handlePressMove,
                  onPointerUp: handlePressEnd,
                  onPointerCancel: handlePressEnd,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTap: _activatable ? handleTap : null,
                    onTapCancel: releasePress,
                    child: box,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A group of the GNOME sidebar: its rows, under a bold heading when it has
/// a title (as `AdwSidebar` sections do). GNOME Settings separates its
/// groups with lines ([AdwaitaSidebarSeparator]). Internal.
class AdwaitaSidebarSection extends SidebarSection {
  const AdwaitaSidebarSection({
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
    final style = theme.titleTextStyle ?? kAdwaitaHeadingStyle;
    return Padding(
      padding:
          titlePadding ??
          const EdgeInsetsDirectional.only(
            start: _kRowMarginH + _kRowPadding,
            end: _kRowMarginH + _kRowPadding,
            top: 6,
            bottom: 6,
          ),
      child: DefaultTextStyle(
        style: style.copyWith(
          color:
              style.color ?? theme.titleTextColor ?? adwaitaForegroundOf(theme),
        ),
        child: title,
      ),
    );
  }
}

/// The line between two groups of the GNOME Settings sidebar: 1px of the
/// foreground at 15% with 6px margins, so rows on both sides of it are 58
/// apart (45 otherwise). Internal.
class AdwaitaSidebarSeparator extends StatelessWidget {
  const AdwaitaSidebarSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = SettingsTheme.of(context).themeData;
    return Padding(
      padding: const EdgeInsets.all(_kRowMarginH),
      child: SizedBox(
        height: 1,
        child: ColoredBox(color: _share(adwaitaForegroundOf(theme), 0.15)),
      ),
    );
  }
}

/// A flat GNOME header bar: 46 tall and transparent, with the title in
/// bold in the middle, a back button (`go-previous-symbolic`) at the start
/// when [onBack] is set, and [actions] at the end. Used over the sidebar
/// (with the split view's title) and over each page. Internal.
class AdwaitaHeaderBar extends StatelessWidget {
  const AdwaitaHeaderBar({
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
    final theme = SettingsTheme.of(context).themeData;
    final foreground = adwaitaForegroundOf(theme);
    final title = this.title;
    final actions = this.actions;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: kAdwaitaHeaderBarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kBarPadding),
          child: NavigationToolbar(
            leading: onBack == null
                ? null
                : Align(
                    widthFactor: 1,
                    child: AdwaitaFlatButton(
                      semanticLabel: settingsBackLabel(context),
                      onPressed: onBack!,
                      child: AdwaitaGoPreviousIcon(color: foreground),
                    ),
                  ),
            middle: title == null
                ? null
                : Semantics(
                    header: true,
                    child: DefaultTextStyle(
                      style: kAdwaitaHeadingStyle.copyWith(color: foreground),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: title,
                    ),
                  ),
            trailing: actions == null || actions.isEmpty
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: actions),
            middleSpacing: 6,
          ),
        ),
      ),
    );
  }
}

/// A flat 34x34 header bar button with 9px corners: the foreground at 7%
/// on hover and 16% while pressed, and the accent focus ring. Internal.
class AdwaitaFlatButton extends SidebarButton {
  const AdwaitaFlatButton({
    super.key,
    required String super.semanticLabel,
    required VoidCallback super.onPressed,
    required this.child,
  });

  final Widget child;

  @override
  Widget buildButton(BuildContext context, SidebarButtonStates states) {
    final theme = SettingsTheme.of(context).themeData;
    final foreground = adwaitaForegroundOf(theme);
    return Container(
      width: _kButtonSize,
      height: _kButtonSize,
      decoration: BoxDecoration(
        color: states.pressed
            ? _share(foreground, _kPressed)
            : states.hovered
            ? _share(foreground, _kHover)
            : null,
        borderRadius: BorderRadius.circular(_kRowRadius),
      ),
      foregroundDecoration: states.focused
          ? _focusRing(adwaitaIsDark(theme))
          : null,
      alignment: Alignment.center,
      child: ExcludeSemantics(child: child),
    );
  }
}
