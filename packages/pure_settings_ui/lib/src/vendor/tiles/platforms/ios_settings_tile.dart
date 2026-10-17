import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/cupertino_settings_switch.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_colors.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_data.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_parts.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_style.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';

class IOSSettingsTile extends StatefulWidget {
  const IOSSettingsTile(
    this.tile, {
    this.selected = false,
    this.sidebar = false,
    this.semanticsSelected,
    super.key,
  });

  final SettingsTileData tile;

  /// Drawn as the selected row of an iPad sidebar: a filled capsule.
  final bool selected;

  /// In the list pane of a split view with two panes: an iPad sidebar row
  /// (no card, separator or chevron; highlighted as a capsule).
  final bool sidebar;

  /// Whether assistive technologies hear the row as selected: null for rows
  /// that don't open a page in a split view's list pane.
  final bool? semanticsSelected;

  @override
  IOSSettingsTileState createState() => IOSSettingsTileState();
}

class IOSSettingsTileState extends State<IOSSettingsTile> {
  SettingsTileData get tile => widget.tile;

  bool isPressed = false;

  /// Clears the pressed tint shortly after a tap.
  Timer? _releaseTimer;

  /// Only an enabled row with `onPressed` reacts to taps, and only then does
  /// it expose a tap action to screen readers.
  bool get _canPress => tile.enabled && tile.onPressed != null;

  @override
  void didUpdateWidget(IOSSettingsTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_canPress) {
      _releaseTimer?.cancel();
      isPressed = false;
    }
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final additionalInfo = IOSSettingsTileAdditionalInfo.of(context);
    final theme = SettingsTheme.of(context);

    // The row is one node, so the rows of a section never merge into one. A
    // row with onPressed is a button, dimmed when disabled. A switch row
    // without onPressed reads as its switch: "title, switch, on" (with it,
    // the switch is a node of its own, labelled with the title).
    final isSwitch = tile.isSwitch;
    final isButton = tile.onPressed != null;
    Widget row = Semantics(
      container: true,
      button: isButton,
      enabled: isButton || (!isSwitch && !tile.enabled) ? tile.enabled : null,
      selected: widget.semanticsSelected,
      child: buildTitle(
        context: context,
        theme: theme,
        additionalInfo: additionalInfo,
      ),
    );
    if (isSwitch && !isButton) row = MergeSemantics(child: row);

    return IgnorePointer(
      ignoring: !tile.enabled,
      child: Column(
        children: [
          row,
          if (tile.description != null)
            buildDescription(
              context: context,
              theme: theme,
              additionalInfo: additionalInfo,
            ),
        ],
      ),
    );
  }

  Widget buildTitle({
    required BuildContext context,
    required SettingsTheme theme,
    required IOSSettingsTileAdditionalInfo additionalInfo,
  }) {
    final content = buildTileContent(context, theme, additionalInfo);

    // iPad sidebar rows highlight as a 52pt capsule.
    if (widget.sidebar) {
      return ClipRRect(borderRadius: BorderRadius.circular(26), child: content);
    }

    // Continuous (superellipse) corners, like the grouped cards in iOS
    // Settings.
    return ClipRSuperellipse(
      borderRadius: BorderRadius.vertical(
        top: additionalInfo.enableTopBorderRadius
            ? const Radius.circular(26)
            : Radius.zero,
        bottom: additionalInfo.enableBottomBorderRadius
            ? const Radius.circular(26)
            : Radius.zero,
      ),
      child: content,
    );
  }

  Widget buildDescription({
    required BuildContext context,
    required SettingsTheme theme,
    required IOSSettingsTileAdditionalInfo additionalInfo,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);

    // Fill the width the tile gets (a pane of a split view can be much
    // narrower than the screen), falling back to the screen width when it's
    // unbounded. The footer is a semantics node of its own, read after the
    // row.
    return Semantics(
      container: true,
      child: LayoutBuilder(
        builder: (context, constraints) => Container(
          width: constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width,
          padding:
              tile.descriptionPadding ??
              EdgeInsets.only(
                left: 16,
                right: 16,
                top: textScaler.scale(8),
                bottom: additionalInfo.needToShowDivider
                    ? 24
                    : textScaler.scale(8),
              ),
          decoration: BoxDecoration(
            color: theme.themeData.settingsListBackground,
          ),
          child: DefaultTextStyle(
            style:
                (theme.themeData.tileDescriptionTextStyle ??
                        const TextStyle(fontSize: 13))
                    .copyWith(color: theme.themeData.titleTextColor),
            child: tile.description!,
          ),
        ),
      ),
    );
  }

  /// Returns the non-value trailing controls (switch, trailing icon, chevron).
  Widget buildTrailing({
    required BuildContext context,
    required SettingsTheme theme,
  }) {
    final themeData = theme.themeData;
    final textScaler = MediaQuery.textScalerOf(context);
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tile.trailing != null)
          Padding(
            padding:
                tile.trailingPadding ??
                const EdgeInsets.symmetric(horizontal: 16),
            child: IconTheme(
              data: IconTheme.of(context).copyWith(
                color: themeData.iconColorFor(
                  enabled: tile.enabled,
                  selected: widget.selected,
                ),
              ),
              child: tile.trailing!,
            ),
          ),
        // The switch's glass lens paints up to ~12.5pt past its end and ~6pt
        // above and below it. The 16pt end padding and the 52pt row keep it
        // inside the card.
        if (tile.isSwitch)
          tile.labelSwitchIfSeparate(
            CupertinoTheme(
              // The switch picks its light or dark colors from this: the
              // list's, which `SettingsList.brightness` can set apart from the
              // app's.
              data: CupertinoTheme.of(
                context,
              ).copyWith(brightness: SettingsStyleScope.brightnessOf(context)),
              child: CupertinoSettingsSwitch(
                value: tile.initialValue,
                // A disabled tile's switch takes no focus, keys or taps.
                onChanged: tile.enabled ? tile.onToggle : null,
                activeTrackColor: tile.enabled
                    ? tile.activeSwitchColor
                    : (themeData.inactiveSwitchColor ??
                          themeData.inactiveTitleColor),
              ),
            ),
          ),
        // iPad sidebar rows have no chevron.
        if (tile.isNavigation && !widget.sidebar)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6, end: 2),
            child: IconTheme(
              // The chevron of a disabled row is not dimmed.
              data: IconTheme.of(context).copyWith(
                color: themeData.iconColorFor(
                  enabled: true,
                  selected: widget.selected,
                ),
              ),
              child: Icon(
                isRTL
                    ? CupertinoIcons.chevron_back
                    : CupertinoIcons.chevron_forward,
                size: textScaler.scale(18),
              ),
            ),
          ),
      ],
    );
  }

  void changePressState({bool isPressed = false}) {
    // A tap recognizer that is dropped mid-press (the tile was disabled)
    // cancels during the build. didUpdateWidget has cleared the tint by then.
    if (mounted && this.isPressed != isPressed) {
      setState(() {
        this.isPressed = isPressed;
      });
    }
  }

  void _handleTap() {
    changePressState(isPressed: true);

    tile.onPressed!.call(context);

    _releaseTimer?.cancel();
    _releaseTimer = Timer(
      const Duration(milliseconds: 100),
      () => changePressState(isPressed: false),
    );
  }

  Widget buildTileContent(
    BuildContext context,
    SettingsTheme theme,
    IOSSettingsTileAdditionalInfo additionalInfo,
  ) {
    final themeData = theme.themeData;
    final sidebar = widget.sidebar;
    final Color? background;
    if (sidebar && widget.selected) {
      background = themeData.selectedTileColor;
    } else if (isPressed) {
      background = themeData.tileHighlightColor;
    } else {
      background = sidebar ? null : themeData.settingsSectionBackground;
    }

    // Without callbacks the detector has no tap recognizer, so a row that
    // does nothing exposes no tap action, and a press that started before
    // the tile was disabled does not fire.
    final canPress = _canPress;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: canPress ? _handleTap : null,
      onTapDown: canPress ? (_) => changePressState(isPressed: true) : null,
      onTapUp: canPress ? (_) => changePressState(isPressed: false) : null,
      onTapCancel: canPress ? () => changePressState(isPressed: false) : null,
      child: Container(
        color: background,
        // iPad sidebar: icon 14pt into the row, label 8.5pt after a 28pt
        // icon.
        padding: EdgeInsetsDirectional.only(start: sidebar ? 14 : 16),
        child: Row(
          children: [
            if (tile.leading != null)
              Padding(
                padding:
                    tile.leadingPadding ??
                    EdgeInsetsDirectional.only(end: sidebar ? 8.5 : 12.0),
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: themeData.iconColorFor(
                      enabled: tile.enabled,
                      selected: widget.selected,
                    ),
                  ),
                  child: tile.leading!,
                ),
              ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsetsDirectional.only(end: sidebar ? 14 : 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _buildTitleAndValue(context, themeData),
                        ),
                        buildTrailing(context: context, theme: theme),
                      ],
                    ),
                  ),
                  if (tile.description == null &&
                      additionalInfo.needToShowDivider &&
                      !sidebar)
                    Divider(
                      height: 0,
                      thickness: 0.7,
                      color: themeData.dividerColor,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The title over the title description, then the value.
  Widget _buildTitleAndValue(BuildContext context, SettingsThemeData theme) {
    final textScaler = MediaQuery.textScalerOf(context);
    final titleColor = theme.titleColorFor(
      enabled: tile.enabled,
      selected: widget.selected,
    );
    final Color? valueColor;
    final Color? titleDescriptionColor;
    if (!tile.enabled) {
      valueColor = titleDescriptionColor = theme.inactiveTitleColor;
    } else if (widget.selected) {
      valueColor = theme.selectedTileTextColor ?? theme.trailingTextColor;
      titleDescriptionColor = titleColor?.withValues(alpha: 0.8);
    } else {
      valueColor = theme.trailingTextColor;
      titleDescriptionColor = theme.titleTextColor;
    }
    // 16 + 17pt text + 16 gives the 52pt row of iOS Settings.
    final edgePadding = textScaler.scale(tile.compact ? 8.0 : 16.0);

    return LayoutBuilder(
      // The title fills the row. The value keeps its natural width, up to
      // half the row, so neither a long title nor a long value can hide the
      // other (Issues #186, #203).
      builder: (context, constraints) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tileText(
                  tile.title,
                  padding:
                      tile.titlePadding ??
                      EdgeInsetsDirectional.only(
                        top: edgePadding,
                        bottom: tile.titleDescription == null
                            ? edgePadding
                            : textScaler.scale(tile.compact ? 2.0 : 4.0),
                      ),
                  style: (theme.tileTextStyle ?? const TextStyle(fontSize: 17))
                      .copyWith(color: titleColor),
                ),
                if (tile.titleDescription != null)
                  tileText(
                    tile.titleDescription!,
                    padding:
                        tile.titleDescriptionPadding ??
                        EdgeInsetsDirectional.only(bottom: edgePadding),
                    style: TextStyle(
                      color: titleDescriptionColor,
                      fontSize: 15,
                    ),
                  ),
              ],
            ),
          ),
          if (tile.value != null && !tile.isSwitch)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: tileValue(
                tile.value!,
                style: TextStyle(color: valueColor, fontSize: 17),
                maxWidth: constraints.maxWidth / 2,
              ),
            ),
        ],
      ),
    );
  }
}

class IOSSettingsTileAdditionalInfo extends InheritedWidget {
  final bool needToShowDivider;
  final bool enableTopBorderRadius;
  final bool enableBottomBorderRadius;

  const IOSSettingsTileAdditionalInfo({
    super.key,
    required this.needToShowDivider,
    required this.enableTopBorderRadius,
    required this.enableBottomBorderRadius,
    required super.child,
  });

  @override
  bool updateShouldNotify(IOSSettingsTileAdditionalInfo oldWidget) =>
      needToShowDivider != oldWidget.needToShowDivider ||
      enableTopBorderRadius != oldWidget.enableTopBorderRadius ||
      enableBottomBorderRadius != oldWidget.enableBottomBorderRadius;

  static IOSSettingsTileAdditionalInfo of(BuildContext context) {
    final IOSSettingsTileAdditionalInfo? result = context
        .dependOnInheritedWidgetOfExactType<IOSSettingsTileAdditionalInfo>();
    return result ??
        const IOSSettingsTileAdditionalInfo(
          needToShowDivider: true,
          enableBottomBorderRadius: true,
          enableTopBorderRadius: true,
          child: SizedBox(),
        );
  }
}
