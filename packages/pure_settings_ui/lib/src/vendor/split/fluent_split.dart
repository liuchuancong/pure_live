import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pure_settings_ui/src/vendor/split/fluent_compact_pane.dart';
import 'package:pure_settings_ui/src/vendor/split/fluent_controls.dart';
import 'package:pure_settings_ui/src/vendor/split/settings_page_header.dart';
import 'package:pure_settings_ui/src/vendor/split/sidebar_keyboard.dart';
import 'package:pure_settings_ui/src/vendor/split/sidebar_row.dart';
import 'package:pure_settings_ui/src/vendor/split/sidebar_section.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/fluent_settings_switch.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_press.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_semantics.dart';
import 'package:pure_settings_ui/src/vendor/utils/fluent_tokens.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';

export 'package:pure_settings_ui/src/vendor/split/fluent_compact_pane.dart'
    show FluentCompactPaneLayout;
export 'package:pure_settings_ui/src/vendor/split/fluent_controls.dart'
    show FluentSubtleButton;
export 'package:pure_settings_ui/src/vendor/split/fluent_page_header.dart'
    show FluentPageHeader;

// The WinUI 3 `NavigationView` of Windows 11 Settings (left pane), from
// microsoft-ui-xaml's NavigationView_themeresources.xaml, measured against
// real Settings captures. All sizes are effective pixels. The page header
// is in `fluent_page_header.dart`, the compact rail's overlay in
// `fluent_compact_pane.dart`.

/// NavigationViewItemOnLeftMinHeight.
const double kFluentPaneItemMinHeight = 36;

/// NavigationViewItemButtonMargin (4,2): items are 4 from the pane edges
/// and 4 apart.
const double _kItemMarginH = 4;
const double _kItemMarginV = 2;

/// The icon is 16 (NavigationViewItemOnLeftIconBoxHeight), centered in a 40
/// column (NavigationViewIconBoxWidth): 24 from the pane edge.
const double _kIconColumn = 40;
const double _kIconSize = 16;

/// The compact rail draws the same row at the rail's own scale: a larger
/// glyph now that the label is gone, on a taller cell.
const double _kCompactIconSize = 24;
const double _kCompactItemMinHeight = 40;

/// NavigationViewItemContentPresenterMargin (4,-1,8,-1): the label starts
/// 48 from the pane edge.
const double _kLabelStart = 4;
const double _kLabelEnd = 8;

/// The selection indicator: a 3x16 accent pill with 2 corners at the
/// item's start edge.
const double _kPillWidth = 3;
const double _kPillHeight = 16;
const double _kPillRadius = 2;

/// The pill slides (and stretches) from the old item to the new one.
const Duration _kPillDuration = Duration(milliseconds: 350);

/// Windows Settings puts the open pane's items 16 from the window edge,
/// 12 more than NavigationView's own 4 item margin.
const double kFluentPaneGutter = 12;

/// The pane's top row, where Windows Settings has its title bar ("←
/// Settings", 48 tall).
const double kFluentPaneHeaderHeight = 48;

/// The pane opened over the content from the compact rail
/// (OpenPaneLength).
const double kFluentOverlayPaneWidth = 320;

/// NavigationViewItemHeader: BodyStrong in the secondary text color, 16 in
/// (NavigationViewItemInnerHeaderMargin), on a 40 row.
const double _kHeaderHeight = 40;
const double _kHeaderStart = 16;

/// The list pane of a Windows style split view: the keyboard navigation
/// and the selection indicator that the items share, so it can slide from
/// one to the other. Internal.
class FluentNavigationPane extends StatefulWidget {
  const FluentNavigationPane({
    super.key,
    this.enabled = true,
    required this.child,
  });

  /// False when the list is not a pane (one pane shows cards).
  final bool enabled;
  final Widget child;

  @override
  State<FluentNavigationPane> createState() => _FluentNavigationPaneState();
}

class _FluentNavigationPaneState extends State<FluentNavigationPane> {
  final _FluentSelectionIndicator _indicator = _FluentSelectionIndicator();

  @override
  Widget build(BuildContext context) {
    return _FluentIndicatorScope(
      indicator: _indicator,
      child: SettingsSidebarKeyboard(
        enabled: widget.enabled,
        child: widget.child,
      ),
    );
  }
}

/// Where the selection indicator was last shown, so the next selected item
/// can slide it in from there.
class _FluentSelectionIndicator {
  final Map<String, _FluentNavigationItemState> _items =
      <String, _FluentNavigationItemState>{};

  /// The item whose pill shows (or last showed).
  String? shownId;

  void register(String id, _FluentNavigationItemState item) =>
      _items[id] = item;

  void unregister(String id, _FluentNavigationItemState item) {
    if (_items[id] == item) _items.remove(id);
  }

  /// The pill of the item [id] in global coordinates, if it is on screen.
  Rect? globalPillRectOf(String id) {
    final item = _items[id];
    if (item == null || !item.mounted) return null;
    final box = item.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      item.pillRect(box.size),
    );
  }
}

class _FluentIndicatorScope extends InheritedWidget {
  const _FluentIndicatorScope({required this.indicator, required super.child});

  final _FluentSelectionIndicator indicator;

  static _FluentSelectionIndicator? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_FluentIndicatorScope>()?.indicator;

  @override
  bool updateShouldNotify(_FluentIndicatorScope oldWidget) =>
      indicator != oldWidget.indicator;
}

/// An item of the Windows Settings navigation pane (a WinUI
/// `NavigationViewItem`): a tile in the list pane of a Windows style split
/// view. Internal.
///
/// At least 36 tall with 4,2 margins and 4 corners; a 16 icon in a 40
/// column and the Body label at 48. Selected: the neutral
/// SubtleFillSecondary fill and a 3x16 accent pill at the start edge, which
/// slides over from the previously selected item. Hover and pressed fills,
/// a secondary label while pressed, and the Fluent focus ring. In the
/// compact rail the item is 40 wide and shows only its icon, with the label
/// in a tooltip. Descriptions and values are not shown.
class FluentNavigationItem extends SidebarRow {
  const FluentNavigationItem(
    super.tile, {
    super.key,
    required this.id,
    required super.selected,
    super.semanticsSelected,
  });

  /// The id of the page the item opens, if any: the selection indicator
  /// finds the item by it.
  final String? id;

  @override
  State<FluentNavigationItem> createState() => _FluentNavigationItemState();
}

class _FluentNavigationItemState extends State<FluentNavigationItem>
    with
        SingleTickerProviderStateMixin,
        SidebarRowState<FluentNavigationItem>,
        TilePressTracking {
  bool _hovered = false;

  /// Slides the pill in when the item becomes selected.
  late final AnimationController _pill;

  /// Where the pill slides in from, in this item's coordinates.
  Rect? _pillFrom;

  /// The text direction, as the last build read it: [pillRect] is also
  /// called after a frame, for another item.
  late TextDirection _textDirection;

  _FluentSelectionIndicator? _indicator;

  /// The item under its tooltip; see [build].
  final GlobalKey _contentKey = GlobalKey(
    debugLabel: 'FluentNavigationItem content',
  );

  @override
  String get debugLabel => 'FluentNavigationItem';

  /// A switch item in the rail has no room for its switch: a tap toggles.
  bool _togglesOnTap(bool compact) =>
      compact &&
      tile.isSwitch &&
      tile.onPressed == null &&
      tile.onToggle != null;

  bool _clickable(bool compact) =>
      tile.enabled && (tile.onPressed != null || _togglesOnTap(compact));

  @override
  void activateRow() {
    if (!tile.enabled) return;
    if (tile.onPressed != null) {
      tile.onPressed!(context);
    } else if (_togglesOnTap(FluentPaneModeScope.compactOf(context))) {
      tile.onToggle!(!tile.initialValue);
    }
  }

  /// A switch item without onPressed reads as one node: "Title, switch,
  /// on" (in the rail too, where a tap toggles). One with onPressed keeps
  /// its switch apart (both have a tap action), labelled with the title.
  bool get _mergesSwitch => tile.isSwitch && tile.onPressed == null;

  @override
  void initState() {
    super.initState();
    _pill = AnimationController(
      vsync: this,
      duration: _kPillDuration,
      value: 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final indicator = _FluentIndicatorScope.maybeOf(context);
    if (indicator != _indicator) {
      final id = widget.id;
      if (id != null) _indicator?.unregister(id, this);
      _indicator = indicator;
      if (id != null) indicator?.register(id, this);
      // A newly built selected item is where the pill is: after one pane
      // (cards, no items) the indicator's last item is stale.
      if (widget.selected && id != null) indicator?.shownId = id;
    }
  }

  @override
  void didUpdateWidget(FluentNavigationItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      if (oldWidget.id != null) _indicator?.unregister(oldWidget.id!, this);
      if (widget.id != null) _indicator?.register(widget.id!, this);
    }
    if (!tile.enabled) resetPress();
    if (widget.selected && !oldWidget.selected) {
      // Find the old pill once every item has rebuilt.
      WidgetsBinding.instance.addPostFrameCallback((_) => _slidePillIn());
    }
  }

  @override
  void dispose() {
    final id = widget.id;
    if (id != null) _indicator?.unregister(id, this);
    _pill.dispose();
    super.dispose();
  }

  void _slidePillIn() {
    if (!mounted || !widget.selected) return;
    final indicator = _indicator;
    final id = widget.id;
    final previous = indicator?.shownId;
    if (id != null) indicator?.shownId = id;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final from = previous == null || previous == id || reduceMotion
        ? null
        : indicator?.globalPillRectOf(previous);
    final box = context.findRenderObject();
    if (from == null || box is! RenderBox || !box.hasSize) {
      _pillFrom = null;
      _pill.value = 1;
      return;
    }
    final toLocal = Matrix4.tryInvert(box.getTransformTo(null));
    if (toLocal == null) return;
    setState(() => _pillFrom = MatrixUtils.transformRect(toLocal, from));
    _pill.forward(from: 0);
  }

  /// The pill's rectangle in an item of [size] (margins included).
  Rect pillRect(Size size) => _pillRectIn(size, _textDirection);

  void _handlePointerDown(PointerDownEvent event) {
    if (pressed) return;
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons != kPrimaryMouseButton) {
      return;
    }
    startPress(event);
  }

  /// The item's fill, label color and icon color in its current state.
  ({Color? fill, Color foreground, Color iconColor}) _colors(
    SettingsThemeData theme,
    FluentTokens tokens, {
    required bool pressed,
    required bool hovered,
  }) {
    final enabled = tile.enabled;
    final selected = widget.selected;
    final selectedFill = theme.selectedTileColor ?? tokens.navItemSelected;
    final Color? fill;
    if (!enabled) {
      fill = selected ? selectedFill : null;
    } else if (selected) {
      fill = pressed
          ? selectedFill
          : hovered
          ? tokens.navItemPressed
          : selectedFill;
    } else {
      fill = pressed
          ? tokens.navItemPressed
          : hovered
          ? tokens.navItemSelected
          : null;
    }

    final primary = selected
        ? (theme.selectedTileTextColor ??
              theme.settingsTileTextColor ??
              tokens.textPrimary)
        : (theme.settingsTileTextColor ?? tokens.textPrimary);
    final secondary = theme.tileDescriptionTextColor ?? tokens.textSecondary;
    final foreground = !enabled
        ? (theme.inactiveTitleColor ?? tokens.textDisabled)
        : pressed
        ? secondary
        : primary;
    final iconColor = !enabled
        ? foreground
        : pressed
        ? secondary
        : selected
        ? (theme.selectedTileIconColor ?? primary)
        : (theme.leadingIconsColor ?? primary);
    return (fill: fill, foreground: foreground, iconColor: iconColor);
  }

  @override
  Widget build(BuildContext context) {
    final theme = SettingsTheme.of(context).themeData;
    final tokens = fluentTokensOf(context);
    final compact = FluentPaneModeScope.compactOf(context);
    final textDirection = _textDirection = Directionality.of(context);
    final enabled = tile.enabled;
    final clickable = _clickable(compact);
    final (:fill, :foreground, :iconColor) = _colors(
      theme,
      tokens,
      pressed: clickable && pressed,
      hovered: clickable && _hovered,
    );

    final labelStyle = (theme.tileTextStyle ?? FluentTypography.body).copyWith(
      color: foreground,
    );

    final title = tile.title;
    final String? tooltip = title is Text
        ? (title.data ?? title.textSpan?.toPlainText())
        : null;

    Widget? icon = tile.leading;
    if (icon == null && compact && tooltip != null && tooltip.isNotEmpty) {
      // The rail needs something to click: the label's first letter.
      icon = ExcludeSemantics(
        child: Text(
          tooltip.characters.first,
          style: labelStyle.copyWith(fontWeight: FontWeight.w600),
        ),
      );
    }

    // The compact rail's glyph is the rail's own size, not whatever the
    // tile's leading slot carried — a label-less row is read by its icon,
    // so the icon carries the row.
    Widget? railIcon = icon;
    if (compact && railIcon is Icon) {
      railIcon = Icon(railIcon.icon, size: _kCompactIconSize, color: railIcon.color);
    }
    final iconColumn = SizedBox(
      width: _kIconColumn,
      child: railIcon == null
          ? null
          : Center(
              child: IconTheme.merge(
                data: IconThemeData(color: iconColor, size: compact ? _kCompactIconSize : _kIconSize),
                child: railIcon,
              ),
            ),
    );
    final textScaler = MediaQuery.textScalerOf(context);
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: compact ? _kCompactItemMinHeight : kFluentPaneItemMinHeight,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: textScaler.scale(2)),
        // The rail shows only the icon, centred in the cell whatever the
        // rail's width. Its line is a Row like the open pane's, so an item
        // without a tooltip is updated in place when the pane opens.
        child: compact
            ? Center(child: iconColumn)
            : buildLine(
                leading: iconColumn,
                titleStyle: labelStyle,
                titlePadding: const EdgeInsetsDirectional.only(
                  start: _kLabelStart,
                  end: _kLabelEnd,
                ),
                trailingStyle: labelStyle,
                trailingIconColor: iconColor,
                endPadding: const EdgeInsetsDirectional.only(end: _kLabelEnd),
                // The item takes the focus when it can be clicked;
                // otherwise the switch does, so the keyboard can reach it.
                toggle: !tile.isSwitch
                    ? null
                    : ExcludeFocus(
                        excluding: clickable,
                        child: tile.labelSwitchIfSeparate(
                          FluentSettingsSwitch(
                            value: tile.initialValue,
                            onChanged: enabled ? tile.onToggle : null,
                            activeTrackColor: tile.activeSwitchColor,
                          ),
                        ),
                      ),
              ),
      ),
    );

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Widget item = TweenAnimationBuilder<Color?>(
      // Background changes fade in 83 ms (BrushTransition).
      tween: ColorTween(
        end: fill ?? tokens.navItemSelected.withValues(alpha: 0),
      ),
      duration: reduceMotion ? Duration.zero : kFluentFasterDuration,
      builder: (context, color, child) => DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(kFluentControlRadius),
        ),
        child: child,
      ),
      child: content,
    );

    // Always there, so what the item shows keeps its State when the ring
    // comes and goes.
    item = fluentFocusRing(tokens, item, show: showsFocusRing && clickable);

    item = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _kItemMarginH,
        vertical: _kItemMarginV,
      ),
      child: item,
    );

    // The pill paints over the item (and, while it slides, over its
    // neighbors), in the accent color.
    item = CustomPaint(
      foregroundPainter: widget.selected
          ? _PillPainter(
              animation: _pill,
              from: _pillFrom,
              textDirection: textDirection,
              color: tokens.accent,
            )
          : null,
      child: item,
    );

    // Under a GlobalKey, so the item moves with its State when the rail's
    // tooltip comes or goes around it.
    item = KeyedSubtree(
      key: _contentKey,
      child: _interactive(item, clickable: clickable),
    );

    if (compact && tooltip != null) item = _railTooltip(tooltip, tokens, item);

    // A rail item that toggles on a tap has no switch to show, so it says
    // what the switch would.
    final togglesOnTap = _togglesOnTap(compact);
    Widget semantics = Semantics(
      container: true,
      button: clickable && !togglesOnTap,
      enabled: enabled,
      selected: widget.semanticsSelected,
      toggled: togglesOnTap ? tile.initialValue : null,
      onTap: clickable ? activateRow : null,
      // The rail doesn't draw the title: the item reads as the title
      // would, so its semantics label wins over its text.
      label: compact ? tileTitleLabel(title) : null,
      child: item,
    );
    if (_mergesSwitch) semantics = MergeSemantics(child: semantics);

    return IgnorePointer(ignoring: !enabled, child: semantics);
  }

  /// [child] with the item's keyboard focus, hover, press and click.
  Widget _interactive(Widget child, {required bool clickable}) {
    return FocusableActionDetector(
      enabled: clickable,
      focusNode: focusNode,
      actions: actions,
      onShowFocusHighlight: handleFocusHighlight,
      mouseCursor: clickable && kIsWeb
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: MouseRegion(
        onEnter: (_) {
          if (!_hovered) setState(() => _hovered = true);
        },
        onExit: (_) {
          if (_hovered) setState(() => _hovered = false);
        },
        child: Listener(
          onPointerDown: clickable ? _handlePointerDown : null,
          onPointerMove: handlePressMove,
          onPointerUp: handlePressEnd,
          onPointerCancel: handlePressEnd,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: clickable ? handleTap : null,
            child: child,
          ),
        ),
      ),
    );
  }

  /// The rail shows an item's label in a tooltip next to it.
  Widget _railTooltip(String message, FluentTokens tokens, Widget child) {
    return Tooltip(
      message: message,
      excludeFromSemantics: true,
      waitDuration: const Duration(milliseconds: 400),
      preferBelow: false,
      verticalOffset: 0,
      margin: const EdgeInsetsDirectional.only(start: _kIconColumn + 12),
      decoration: BoxDecoration(
        color: tokens.overlayPane,
        borderRadius: BorderRadius.circular(kFluentControlRadius),
        border: Border.all(color: tokens.overlayStroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      textStyle: FluentTypography.caption.copyWith(color: tokens.textPrimary),
      padding: const EdgeInsets.fromLTRB(9, 6, 9, 8),
      child: child,
    );
  }
}

/// The selection pill's rectangle in an item of [size] (margins included):
/// at the item's start edge, in the middle of its height.
Rect _pillRectIn(Size size, TextDirection textDirection) {
  final left = textDirection == TextDirection.rtl
      ? size.width - _kItemMarginH - _kPillWidth
      : _kItemMarginH;
  return Rect.fromLTWH(
    left,
    (size.height - _kPillHeight) / 2,
    _kPillWidth,
    _kPillHeight,
  );
}

/// Paints the selection pill at its place in the item, or on its way there
/// from the previously selected item: the edge in front moves first and the
/// one behind catches up, so the pill stretches as it travels.
class _PillPainter extends CustomPainter {
  _PillPainter({
    required this.animation,
    required this.from,
    required this.textDirection,
    required this.color,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Rect? from;
  final TextDirection textDirection;
  final Color color;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void paint(Canvas canvas, Size size) {
    final to = _pillRectIn(size, textDirection);
    final from = this.from;
    final t = animation.value;
    var rect = to;
    if (from != null && t < 1) {
      final lead = Curves.easeOutCubic.transform((t / 0.65).clamp(0.0, 1.0));
      final trail = Curves.easeInOutCubic.transform(
        ((t - 0.25) / 0.75).clamp(0.0, 1.0),
      );
      final down = to.center.dy >= from.center.dy;
      final top = _lerp(from.top, to.top, down ? trail : lead);
      final bottom = _lerp(from.bottom, to.bottom, down ? lead : trail);
      final left = _lerp(from.left, to.left, lead);
      rect = Rect.fromLTRB(
        left,
        math.min(top, bottom - _kPillWidth),
        left + _kPillWidth,
        bottom,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(_kPillRadius)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_PillPainter oldDelegate) =>
      oldDelegate.from != from ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.color != color ||
      oldDelegate.animation != animation;
}

/// A group of the Windows pane: a NavigationViewItemHeader (hidden in the
/// compact rail) over its items. Internal.
class FluentNavigationSection extends SidebarSection {
  const FluentNavigationSection({
    super.key,
    required super.title,
    required super.tiles,
    super.titlePadding,
  });

  @override
  Widget? buildHeader(
    BuildContext context,
    SettingsThemeData theme,
    Widget title,
  ) {
    if (FluentPaneModeScope.compactOf(context)) return null;
    final style = theme.titleTextStyle ?? FluentTypography.bodyStrong;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kHeaderHeight),
      child: Padding(
        padding:
            titlePadding ??
            const EdgeInsetsDirectional.only(
              start: _kHeaderStart,
              end: _kHeaderStart,
            ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: DefaultTextStyle(
            style: style.copyWith(
              color:
                  style.color ??
                  theme.tileDescriptionTextColor ??
                  fluentTokensOf(context).textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: title,
          ),
        ),
      ),
    );
  }
}

/// A NavigationViewItemSeparator between two sections of the Windows pane
/// (1px, 3 above and 4 below). A section header already separates in the
/// open pane, so the line only shows before an untitled section, or in the
/// compact rail, which hides the headers. Internal.
class FluentPaneSeparator extends StatelessWidget {
  const FluentPaneSeparator({super.key, required this.beforeTitle});

  /// The next section has a title.
  final bool beforeTitle;

  @override
  Widget build(BuildContext context) {
    if (beforeTitle && !FluentPaneModeScope.compactOf(context)) {
      return const SizedBox(height: 4);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 3, bottom: 4),
      child: SizedBox(
        height: 1,
        child: ColoredBox(color: fluentTokensOf(context).divider),
      ),
    );
  }
}

/// The top of the Windows pane. The open pane shows the split view's title
/// like the Windows Settings title bar ("Settings" in Caption, with the
/// back button when the view can be left); the compact rail has room for
/// the back button and the pane toggle ("hamburger") button only. Internal.
class FluentPaneHeader extends StatelessWidget {
  const FluentPaneHeader({
    super.key,
    required this.title,
    required this.onBack,
    required this.onTogglePane,
  });

  final Widget? title;
  final VoidCallback? onBack;

  /// Opens or closes the pane over the content. Null for the open pane
  /// of wide windows, which has no toggle.
  final VoidCallback? onTogglePane;

  @override
  Widget build(BuildContext context) {
    final theme = SettingsTheme.of(context).themeData;
    final tokens = fluentTokensOf(context);
    final compact = FluentPaneModeScope.compactOf(context);
    final title = this.title;
    final onBack = this.onBack;
    final onTogglePane = this.onTogglePane;

    Widget titleText() => DefaultTextStyle(
      style: FluentTypography.caption.copyWith(
        color: theme.settingsTileTextColor ?? tokens.textPrimary,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      child: Semantics(header: true, child: title!),
    );

    final Widget? back = onBack == null
        ? null
        : FluentSubtleButton(
            semanticLabel: settingsBackLabel(context),
            onPressed: onBack,
            glyph: FluentGlyph.back,
          );
    const margins = EdgeInsetsDirectional.only(
      start: _kItemMarginH,
      end: _kItemMarginH,
    );

    // Only the top inset: the pane's items don't move away from a side
    // inset (a display cutout in landscape) either, and the 48 wide rail
    // has no room for one, which would push the buttons out of it.
    return SafeArea(
      left: false,
      right: false,
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onTogglePane == null)
            // The open pane of a wide window.
            SizedBox(
              height: kFluentPaneHeaderHeight,
              child: Row(
                children: [
                  if (back != null)
                    Padding(padding: margins, child: back)
                  else
                    const SizedBox(width: 16),
                  if (title != null) Expanded(child: titleText()),
                ],
              ),
            )
          else ...[
            if (back != null)
              SizedBox(
                height: kFluentPaneHeaderHeight,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: _kItemMarginH,
                    ),
                    child: back,
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(
                top: back == null ? 6 : 0,
                bottom: _kItemMarginV,
              ),
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    Padding(
                      padding: margins,
                      child: FluentSubtleButton(
                        semanticLabel: settingsMenuLabel(context),
                        onPressed: onTogglePane,
                        glyph: FluentGlyph.menu,
                      ),
                    ),
                    if (!compact && title != null) Expanded(child: titleText()),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
