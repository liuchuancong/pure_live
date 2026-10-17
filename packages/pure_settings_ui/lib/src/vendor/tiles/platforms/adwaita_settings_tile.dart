import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/adwaita_settings_switch.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/adwaita_symbolic_icons.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_colors.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_data.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_parts.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_press.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';

// Rows of a GNOME boxed list (`AdwActionRow` in `.boxed-list`, libadwaita
// 1.10). All sizes are in logical pixels (1 CSS px).

/// One-line rows are 54 tall: 2 px row padding around a 50 px header.
const double kAdwaitaRowMinHeight = 54;

/// Compact rows keep half the space around the text: 9 px instead of 18 px.
const double kAdwaitaCompactRowMinHeight = 36;

/// Corner radius of a boxed list (a card).
const double kAdwaitaCardRadius = 12;

/// Text starts 14 px from the card edge: 2 px row padding + 12 px margin.
const double _kRowInset = 14;

/// Space above and below the title and subtitle: 2 px row padding + 6 px
/// title box margin.
const double _kTitleBoxPadding = 8;

/// `border-spacing` of the row header and of its suffixes.
const double _kSpacing = 6;

/// Prefix icons are 16 px symbolic icons, 12 px before the title.
const double _kIconSize = 16;
const double _kIconGap = 12;

/// Space between the title and the subtitle.
const double _kSubtitleGap = 3;

/// Rows fade their hover and pressed backgrounds in 200 ms, ease-out-quad.
const Duration kAdwaitaHighlightDuration = Duration(milliseconds: 200);
const Curve kAdwaitaHighlightCurve = Cubic(0.25, 0.46, 0.45, 0.94);

/// Body text: Adwaita Sans 11 pt (14.67 px) on an 18 px line.
const double kAdwaitaBodyFontSize = 44 / 3;

/// Row subtitles use the `smaller` size (12.22 px) on a 15 px line.
const double _kSubtitleFontSize = kAdwaitaBodyFontSize / 1.2;

/// Row titles and sidebar labels: body text. The boxed list also gives it
/// to custom rows.
const TextStyle kAdwaitaBodyStyle = TextStyle(
  fontSize: kAdwaitaBodyFontSize,
  fontWeight: FontWeight.w400,
  height: 18 / kAdwaitaBodyFontSize,
  leadingDistribution: TextLeadingDistribution.even,
);

/// `.heading`: body text in bold, for group titles, sidebar headings and
/// header bar titles.
const TextStyle kAdwaitaHeadingStyle = TextStyle(
  fontSize: kAdwaitaBodyFontSize,
  fontWeight: FontWeight.w700,
  height: 18 / kAdwaitaBodyFontSize,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _kSubtitleStyle = TextStyle(
  fontSize: _kSubtitleFontSize,
  fontWeight: FontWeight.w400,
  height: 15 / _kSubtitleFontSize,
  leadingDistribution: TextLeadingDistribution.even,
);

/// The GNOME foreground color in light mode, `rgba(0, 0, 6, 0.8)`.
const Color _kForegroundLight = Color.fromRGBO(0, 0, 6, 0.8);

/// `--accent-color`, which focus rings use at 50%.
const Color _kAccentLight = Color(0xFF0461BE);
const Color _kAccentDark = Color(0xFF81D0FF);

/// The GNOME foreground color of [theme]. Hover, pressed and selected
/// backgrounds are this color at different strengths, like `currentColor`
/// in the libadwaita stylesheet.
Color adwaitaForegroundOf(SettingsThemeData theme) =>
    theme.settingsTileTextColor ?? _kForegroundLight;

/// Whether the theme has light text, so the dark GNOME colors apply.
bool adwaitaIsDark(SettingsThemeData theme) =>
    adwaitaForegroundOf(theme).computeLuminance() > 0.5;

/// The border of the 2 px focus ring of a row or a button.
Border adwaitaFocusBorder({required bool isDark}) => Border.all(
  color: (isDark ? _kAccentDark : _kAccentLight).withValues(alpha: 0.5),
  width: 2,
);

class AdwaitaSettingsTile extends StatefulWidget {
  const AdwaitaSettingsTile(this.tile, {super.key});

  final SettingsTileData tile;

  @override
  State<AdwaitaSettingsTile> createState() => _AdwaitaSettingsTileState();
}

class _AdwaitaSettingsTileState extends State<AdwaitaSettingsTile>
    with TilePressTracking {
  SettingsTileData get tile => widget.tile;

  bool _hovered = false;
  bool _showFocusHighlight = false;

  late final Map<Type, Action<Intent>> _actions = tileActivateActions(
    _activate,
  );

  bool get _hasAction =>
      tile.isSwitch ? tile.onToggle != null : tile.onPressed != null;

  /// Like `.activatable` rows: only these highlight, take focus and react.
  bool get _activatable => tile.enabled && _hasAction;

  /// A switch row toggles on a click anywhere in the row, like
  /// `AdwSwitchRow`. It never calls `onPressed`.
  void _activate() {
    if (!_activatable) return;
    if (tile.isSwitch) {
      tile.onToggle!(!tile.initialValue);
    } else {
      tile.onPressed!(context);
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.buttons == kPrimaryButton) startPress(event);
  }

  @override
  void didUpdateWidget(AdwaitaSettingsTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_activatable) {
      resetPress();
      _hovered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = SettingsTheme.of(context).themeData;
    final info = AdwaitaSettingsTileAdditionalInfo.of(context);
    final isDark = adwaitaIsDark(theme);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    const corner = Radius.circular(kAdwaitaCardRadius);
    final highlighted = AnimatedContainer(
      duration: reduceMotion ? Duration.zero : kAdwaitaHighlightDuration,
      curve: kAdwaitaHighlightCurve,
      decoration: BoxDecoration(color: _highlightColor(theme)),
      // A 2 px accent ring just inside the row, following the card corners.
      foregroundDecoration: _showFocusHighlight && _activatable
          ? BoxDecoration(
              border: adwaitaFocusBorder(isDark: isDark),
              borderRadius: BorderRadius.vertical(
                top: info.isFirst ? corner : Radius.zero,
                bottom: info.isLast ? corner : Radius.zero,
              ),
            )
          : null,
      child: _buildRow(theme, isDark: isDark),
    );

    return MergeSemantics(
      child: Semantics(
        button: !tile.isSwitch && _hasAction,
        enabled: _hasAction ? tile.enabled : null,
        onTap: _activatable ? _activate : null,
        child: IgnorePointer(
          ignoring: !tile.enabled,
          child: FocusableActionDetector(
            enabled: _activatable,
            actions: _actions,
            onShowFocusHighlight: (value) {
              if (value != _showFocusHighlight) {
                setState(() => _showFocusHighlight = value);
              }
            },
            onShowHoverHighlight: (value) {
              if (value != _hovered) setState(() => _hovered = value);
            },
            child: Listener(
              // GTK shows `:active` as soon as the button goes down.
              onPointerDown: _activatable ? _handlePointerDown : null,
              onPointerMove: handlePressMove,
              onPointerUp: handlePressEnd,
              onPointerCancel: handlePressEnd,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: _activatable ? _activate : null,
                onTapCancel: releasePress,
                child: highlighted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// GNOME uses the foreground at 3% on hover and 8% while pressed.
  Color _highlightColor(SettingsThemeData theme) {
    final foreground = adwaitaForegroundOf(theme);
    final pressedColor =
        theme.tileHighlightColor ??
        foreground.withValues(alpha: foreground.a * 0.08);
    if (_activatable && pressed) return pressedColor;
    return pressedColor.withValues(
      alpha: _activatable && _hovered ? pressedColor.a * 3 / 8 : 0,
    );
  }

  Widget _buildRow(SettingsThemeData theme, {required bool isDark}) {
    final enabled = tile.enabled;
    final iconColor = theme.iconColorFor(enabled: enabled);
    final titleStyle = (theme.tileTextStyle ?? kAdwaitaBodyStyle).copyWith(
      color: theme.titleColorFor(enabled: enabled),
    );
    final subtitleStyle = (theme.tileDescriptionTextStyle ?? _kSubtitleStyle)
        .copyWith(
          color: enabled
              ? theme.tileDescriptionTextColor
              : theme.inactiveSubtitleColor,
        );

    final titleBox = Padding(
      padding: EdgeInsets.symmetric(
        vertical: tile.compact ? _kTitleBoxPadding / 2 : _kTitleBoxPadding,
      ),
      // GNOME rows have one subtitle, under the title. Both descriptions go
      // there, the title description first.
      child: tileTitleColumn(
        tile: tile,
        titleStyle: titleStyle,
        subtitleStyle: subtitleStyle,
        subtitlePadding: const EdgeInsets.only(top: _kSubtitleGap),
      ),
    );

    Widget buildSuffixes(double maxValueWidth) {
      final suffixes = <Widget>[
        // A value is a dimmed label at the end of the row, like the
        // secondary label of a GNOME Settings row.
        if (!tile.isSwitch && tile.value != null)
          tileValue(
            tile.value!,
            style: (theme.tileDescriptionTextStyle ?? kAdwaitaBodyStyle)
                .copyWith(
                  color: enabled
                      ? theme.trailingTextColor
                      : theme.inactiveSubtitleColor,
                ),
            maxWidth: maxValueWidth,
          ),
        // Text in `trailing` gets the title style, like a label suffix in
        // GTK, so a combo row value (text + AdwaitaPanDownIcon) needs no
        // style of its own.
        if (tile.trailing != null)
          Padding(
            padding: tile.trailingPadding ?? EdgeInsets.zero,
            child: DefaultTextStyle(
              style: titleStyle,
              child: IconTheme.merge(
                data: IconThemeData(color: iconColor, size: _kIconSize),
                child: tile.trailing!,
              ),
            ),
          ),
        if (tile.isSwitch)
          // The row takes the focus and the clicks, like `AdwSwitchRow`.
          ExcludeFocus(
            child: AdwaitaSettingsSwitch(
              value: tile.initialValue,
              onChanged: enabled ? tile.onToggle : null,
              activeTrackColor: enabled
                  ? tile.activeSwitchColor
                  : (theme.inactiveSwitchColor ?? tile.activeSwitchColor),
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
          ),
        if (tile.isNavigation) AdwaitaGoNextIcon(color: iconColor),
      ];
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final suffix in suffixes) ...[
            const SizedBox(width: _kSpacing),
            suffix,
          ],
        ],
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: tile.compact
            ? kAdwaitaCompactRowMinHeight
            : kAdwaitaRowMinHeight,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: _kRowInset),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              if (tile.leading != null)
                Padding(
                  padding:
                      tile.leadingPadding ??
                      const EdgeInsetsDirectional.only(end: _kIconGap),
                  child: IconTheme.merge(
                    data: IconThemeData(color: iconColor, size: _kIconSize),
                    child: tile.leading!,
                  ),
                ),
              Expanded(child: titleBox),
              // The value may take up to half the row, so neither a long
              // title nor a long value hides the other.
              buildSuffixes(constraints.maxWidth / 2),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tells an [AdwaitaSettingsTile] where it is in its boxed list, so its
/// focus ring can follow the rounded corners of the card.
class AdwaitaSettingsTileAdditionalInfo extends InheritedWidget {
  const AdwaitaSettingsTileAdditionalInfo({
    super.key,
    required this.isFirst,
    required this.isLast,
    required super.child,
  });

  final bool isFirst;
  final bool isLast;

  @override
  bool updateShouldNotify(AdwaitaSettingsTileAdditionalInfo oldWidget) =>
      oldWidget.isFirst != isFirst || oldWidget.isLast != isLast;

  static AdwaitaSettingsTileAdditionalInfo of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<
              AdwaitaSettingsTileAdditionalInfo
            >() ??
        const AdwaitaSettingsTileAdditionalInfo(
          isFirst: true,
          isLast: true,
          child: SizedBox(),
        );
  }
}
