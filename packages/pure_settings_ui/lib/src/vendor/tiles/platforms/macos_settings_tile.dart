import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/macos_settings_switch.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_colors.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_data.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_parts.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_press.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';

// Metrics of a macOS 26/27 System Settings grouped form (SwiftUI
// `Form {}.formStyle(.grouped)`), measured on macOS 27. All sizes are in
// points.

/// Card corners (continuous, like every macOS 26+ card).
const double kMacosCardRadius = 12;

/// Row text starts this far from the card edge, and trailing controls end
/// this far from it. Separators are inset by the same amount.
const double kMacosRowInset = 10;

/// Top and bottom padding of a row: 10 + 16pt line + 10 gives the 36pt row
/// of System Settings (37pt with the separator).
const double kMacosRowVerticalPadding = 10;

/// Rows with a leading icon are at least this tall: the 24pt icon rows of
/// System Settings (General, Network) are 48pt.
const double kMacosIconRowMinHeight = 48;

/// Body text, the SF Pro `body` style: 13pt on a 16pt line.
const TextStyle kMacosBodyStyle = TextStyle(
  fontSize: 13,
  height: 16 / 13,
  letterSpacing: -0.08,
);

/// Section headers: 13pt semibold on a 16pt line. (SwiftUI draws Form
/// headers narrower than the bold `headline` font: their width matches SF
/// Pro Semibold.)
const TextStyle kMacosHeaderStyle = TextStyle(
  fontSize: 13,
  height: 16 / 13,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.08,
);

/// Row subtitles and section footers: SF Pro `subheadline`, 11pt on a 14pt
/// line.
const TextStyle kMacosCaptionStyle = TextStyle(
  fontSize: 11,
  height: 14 / 11,
  letterSpacing: 0.06,
);

/// The chevron is `tertiaryLabelColor`: [SettingsThemeData.leadingIconsColor]
/// (`secondaryLabelColor` by default) at this share of its opacity.
const double _kChevronOpacityLight = 0.259 / 0.498;
const double _kChevronOpacityDark = 0.247 / 0.549;

/// `keyboardFocusIndicatorColor`: #0067F4 or #1AA9FF, both at 50%.
const Color _kFocusLight = Color(0x800067F4);
const Color _kFocusDark = Color(0x801AA9FF);

/// The color of the keyboard focus ring of a row or a toolbar button.
Color macosFocusColor({required bool isDark}) =>
    isDark ? _kFocusDark : _kFocusLight;

/// Whether the macOS style should draw its dark variant, judged by the card
/// color (so a list forced to dark with `SettingsList.brightness` gets dark
/// switches, whatever the app theme says).
bool macosIsDark(BuildContext context, SettingsThemeData theme) {
  for (final color in [
    theme.settingsSectionBackground,
    theme.settingsListBackground,
  ]) {
    if (color != null && color.a >= 0.5) {
      return ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    }
  }
  return CupertinoTheme.brightnessOf(context) == Brightness.dark;
}

/// Where a tile sits in its card. [MacosSettingsSection] puts one above each
/// tile. A tile without one draws its own card and footer.
class MacosSettingsTileScope extends InheritedWidget {
  const MacosSettingsTileScope({
    super.key,
    required this.isFirst,
    required this.isLast,
    required super.child,
  });

  /// The tile is the first row of its card.
  final bool isFirst;

  /// The tile is the last row of its card.
  final bool isLast;

  static MacosSettingsTileScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MacosSettingsTileScope>();

  @override
  bool updateShouldNotify(MacosSettingsTileScope oldWidget) =>
      isFirst != oldWidget.isFirst || isLast != oldWidget.isLast;
}

/// Space between a footer and a card after it in the same section, as
/// between a SwiftUI section with a footer and the next section.
const double kMacosFooterBottomGap = 30;

/// The grey text under a card: a tile's `description`.
Widget buildMacosFooter({
  required BuildContext context,
  required Widget description,
  EdgeInsetsGeometry? padding,
  bool isLast = true,
}) {
  final theme = SettingsTheme.of(context).themeData;
  final textScaler = MediaQuery.textScalerOf(context);
  final style = theme.tileDescriptionTextStyle ?? kMacosCaptionStyle;

  return Padding(
    padding:
        padding ??
        EdgeInsetsDirectional.only(
          start: kMacosRowInset,
          end: kMacosRowInset,
          top: textScaler.scale(10),
          bottom: isLast ? 0 : textScaler.scale(kMacosFooterBottomGap),
        ),
    // A node of its own, read after the card. Otherwise its text lands on
    // the section's node and is read before the section title.
    child: Semantics(
      container: true,
      child: DefaultTextStyle(
        style: style.copyWith(
          color: style.color ?? theme.tileDescriptionTextColor,
        ),
        child: description,
      ),
    ),
  );
}

/// Centers a trailing control on the title's first line, [lineHeight] tall
/// (and keeps it at its own size when it is taller than the line).
Widget _onTitleLine(double lineHeight, Widget child) => ConstrainedBox(
  constraints: BoxConstraints(minHeight: lineHeight),
  child: Align(widthFactor: 1, heightFactor: 1, child: child),
);

/// A row of a macOS System Settings grouped form.
///
/// Title on the left in 13pt, then (on the right) the value in the
/// secondary grey, the trailing widget, and the switch or the chevron. A
/// `titleDescription` becomes an 11pt subtitle; the value, the trailing
/// widget and the switch then line up with the title line, as in SwiftUI,
/// and the chevron stays centered. A `description` becomes the footer under
/// the card.
///
/// Rows do not highlight on hover, like System Settings. A row with
/// `onPressed` shows a grey tint while it is pressed and can be focused and
/// activated with the keyboard (Tab, then Space or Enter), which draws the
/// macOS focus ring. On switch rows only the switch toggles; the rest of the
/// row calls `onPressed`.
class MacosSettingsTile extends StatefulWidget {
  const MacosSettingsTile(this.tile, {super.key});

  final SettingsTileData tile;

  @override
  State<MacosSettingsTile> createState() => _MacosSettingsTileState();
}

class _MacosSettingsTileState extends State<MacosSettingsTile> {
  SettingsTileData get tile => widget.tile;

  bool _pressed = false;
  bool _showFocusHighlight = false;

  /// Pointers that went down on the switch or the trailing widget. They
  /// belong to that control, so the row does not show its pressed tint.
  final Set<int> _controlPointers = <int>{};

  late final Map<Type, Action<Intent>> _actions = tileActivateActions(
    _activate,
  );

  bool get _canPress => tile.enabled && tile.onPressed != null;

  void _activate() {
    if (_canPress) tile.onPressed!(context);
  }

  void _setPressed(bool pressed) {
    if (mounted && _pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  void didUpdateWidget(MacosSettingsTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_canPress) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = SettingsTheme.of(context).themeData;
    final scope = MacosSettingsTileScope.maybeOf(context);

    Widget row = _buildRow(context, theme, scope);
    if (scope == null) {
      // Not inside a MacosSettingsSection: draw a card of its own.
      row = ClipRSuperellipse(
        borderRadius: BorderRadius.circular(kMacosCardRadius),
        child: ColoredBox(
          color: theme.settingsSectionBackground ?? const Color(0x00000000),
          child: row,
        ),
      );
      if (tile.description != null) {
        row = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row,
            buildMacosFooter(
              context: context,
              description: tile.description!,
              padding: tile.descriptionPadding,
            ),
          ],
        );
      }
    }
    return row;
  }

  Widget _buildRow(
    BuildContext context,
    SettingsThemeData theme,
    MacosSettingsTileScope? scope,
  ) {
    final isDark = macosIsDark(context, theme);
    final verticalPadding = MediaQuery.textScalerOf(context)
        .scale(kMacosRowVerticalPadding / (tile.compact ? 2 : 1));
    Widget row = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: tile.leading == null
            ? 0
            : kMacosIconRowMinHeight - (tile.compact ? 12 : 0),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: kMacosRowInset,
          vertical: verticalPadding,
        ),
        child: _buildContent(context, theme, isDark: isDark),
      ),
    );

    if (_pressed) {
      row = ColoredBox(
        color: theme.tileHighlightColor ?? const Color(0x00000000),
        child: row,
      );
    }
    if (_showFocusHighlight && _canPress) {
      row = _buildFocusRing(scope, isDark: isDark, child: row);
    }
    return _buildInteraction(row);
  }

  /// The leading widget, the title over the subtitle, the value, the
  /// controls and the chevron.
  Widget _buildContent(
    BuildContext context,
    SettingsThemeData theme, {
    required bool isDark,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final enabled = tile.enabled;
    // With a subtitle, the value and the controls stay on the title line.
    final crossAxisAlignment = tile.titleDescription != null
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center;

    final baseTitleStyle = theme.tileTextStyle ?? kMacosBodyStyle;
    final titleStyle = baseTitleStyle.copyWith(
      color: enabled
          ? (baseTitleStyle.color ?? theme.settingsTileTextColor)
          : theme.inactiveTitleColor,
    );
    // The height of the title's first line. Trailing controls are centered
    // on it.
    final lineHeight =
        textScaler.scale(titleStyle.fontSize ?? 13) *
        (titleStyle.height ?? 16 / 13);
    final valueStyle = kMacosBodyStyle.copyWith(
      color: enabled ? theme.trailingTextColor : theme.inactiveTitleColor,
    );
    final baseSubtitleStyle =
        theme.tileDescriptionTextStyle ?? kMacosCaptionStyle;
    final subtitleStyle = baseSubtitleStyle.copyWith(
      color: enabled
          ? (baseSubtitleStyle.color ?? theme.tileDescriptionTextColor)
          : theme.inactiveSubtitleColor,
    );
    final iconColor = theme.iconColorFor(enabled: enabled);

    final titleColumn = tileTitleColumn(
      tile: tile,
      titleStyle: titleStyle,
      subtitleStyle: subtitleStyle,
      subtitlePadding: EdgeInsetsDirectional.only(top: textScaler.scale(2)),
      // The description is the footer under the card.
      showDescription: false,
    );
    final controls = _buildControls(
      theme,
      titleColor: titleStyle.color,
      iconColor: iconColor,
      isDark: isDark,
      lineHeight: lineHeight,
    );

    return Row(
      children: [
        if (tile.leading != null)
          Padding(
            padding:
                tile.leadingPadding ??
                const EdgeInsetsDirectional.only(start: 2, end: 11),
            child: IconTheme.merge(
              data: IconThemeData(color: iconColor, size: 20),
              child: tile.leading!,
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              crossAxisAlignment: crossAxisAlignment,
              children: [
                Expanded(child: titleColumn),
                // The value keeps its natural width, up to half the row, so
                // neither a long title nor a long value hides the other.
                if (tile.value != null && !tile.isSwitch)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: tileValue(
                      tile.value!,
                      style: valueStyle,
                      maxWidth: constraints.maxWidth / 2,
                    ),
                  ),
                if (controls.isNotEmpty)
                  Listener(
                    onPointerDown: (event) =>
                        _controlPointers.add(event.pointer),
                    onPointerUp: (event) =>
                        _controlPointers.remove(event.pointer),
                    onPointerCancel: (event) =>
                        _controlPointers.remove(event.pointer),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: crossAxisAlignment,
                      children: controls,
                    ),
                  ),
              ],
            ),
          ),
        ),
        // The chevron stays centered in rows with a subtitle.
        if (tile.isNavigation)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: _onTitleLine(
              lineHeight,
              MacosChevron(
                color: _chevronColor(iconColor, isDark),
                size: textScaler.scale(13),
                pointsLeft: Directionality.of(context) == TextDirection.rtl,
              ),
            ),
          ),
      ],
    );
  }

  /// The trailing widget and the switch, which line up with the title's
  /// first line.
  List<Widget> _buildControls(
    SettingsThemeData theme, {
    required Color? titleColor,
    required Color? iconColor,
    required bool isDark,
    required double lineHeight,
  }) => [
    if (tile.trailing != null)
      Padding(
        padding:
            tile.trailingPadding ?? const EdgeInsetsDirectional.only(start: 8),
        child: IconTheme.merge(
          data: IconThemeData(color: iconColor, size: 16),
          child: DefaultTextStyle(
            style: kMacosBodyStyle.copyWith(color: titleColor),
            child: tile.trailing!,
          ),
        ),
      ),
    if (tile.isSwitch)
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 12),
        child: _onTitleLine(
          lineHeight,
          CupertinoTheme(
            // The switch picks its light or dark colors from this.
            data: CupertinoTheme.of(
              context,
            ).copyWith(brightness: isDark ? Brightness.dark : Brightness.light),
            // A disabled switch draws its own paler track, as in System
            // Settings, instead of the grey inactiveTitleColor the other
            // styles fall back to. inactiveSwitchColor still replaces it.
            child: tile.labelSwitchIfSeparate(
              MacosSettingsSwitch(
                value: tile.initialValue,
                onChanged: tile.enabled ? tile.onToggle : null,
                activeTrackColor: tile.enabled
                    ? tile.activeSwitchColor
                    : (theme.inactiveSwitchColor ?? tile.activeSwitchColor),
              ),
            ),
          ),
        ),
      ),
  ];

  /// The focus ring follows the card's corners where the row touches them.
  Widget _buildFocusRing(
    MacosSettingsTileScope? scope, {
    required bool isDark,
    required Widget child,
  }) {
    const cardCorner = Radius.circular(kMacosCardRadius);
    const innerCorner = Radius.circular(6);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          side: BorderSide(color: macosFocusColor(isDark: isDark), width: 3),
          borderRadius: BorderRadius.vertical(
            top: scope?.isFirst ?? true ? cardCorner : innerCorner,
            bottom: scope?.isLast ?? true ? cardCorner : innerCorner,
          ),
        ),
      ),
      child: child,
    );
  }

  /// The row's semantics node, keyboard focus and press handling.
  Widget _buildInteraction(Widget content) => IgnorePointer(
    ignoring: !tile.enabled,
    // One node per row. A switch without a competing onPressed merges
    // into it, so the row reads as "title, switch, on".
    child: Semantics(
      container: true,
      // A disabled row that would open something is a dimmed button.
      button: tile.onPressed != null,
      enabled: tile.enabled,
      child: FocusableActionDetector(
        enabled: _canPress,
        actions: _actions,
        onShowFocusHighlight: (value) {
          if (value != _showFocusHighlight) {
            setState(() => _showFocusHighlight = value);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _canPress
              ? (_) {
                  if (_controlPointers.isEmpty) _setPressed(true);
                }
              : null,
          onTapUp: _canPress ? (_) => _setPressed(false) : null,
          onTapCancel: _canPress ? () => _setPressed(false) : null,
          onTap: _canPress ? _activate : null,
          child: content,
        ),
      ),
    ),
  );

  static Color? _chevronColor(Color? iconColor, bool isDark) {
    if (iconColor == null) return null;
    return iconColor.withValues(
      alpha:
          iconColor.a * (isDark ? _kChevronOpacityDark : _kChevronOpacityLight),
    );
  }
}

/// The `chevron.right` of a navigation row: 5.5x9pt at 13pt, drawn with a
/// 1.2pt stroke, so it needs no icon font.
class MacosChevron extends StatelessWidget {
  const MacosChevron({
    super.key,
    required this.color,
    this.size = 13,
    this.pointsLeft = false,
  });

  final Color? color;

  /// The point size of the symbol (13 in a 13pt row).
  final double size;

  /// Points left instead of right (right-to-left layouts).
  final bool pointsLeft;

  @override
  Widget build(BuildContext context) {
    final scale = size / 13;
    return CustomPaint(
      size: Size(5.5 * scale, 9 * scale),
      painter: _ChevronPainter(
        color: color ?? const Color(0x42000000),
        pointsLeft: pointsLeft,
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({required this.color, required this.pointsLeft});

  final Color color;
  final bool pointsLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 1.2 * size.height / 9;
    final inset = stroke / 2;
    double x(double fromStart) =>
        pointsLeft ? size.width - fromStart : fromStart;
    final path = Path()
      ..moveTo(x(inset), inset)
      ..lineTo(x(size.width - inset), size.height / 2)
      ..lineTo(x(inset), size.height - inset);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pointsLeft != pointsLeft;
}
