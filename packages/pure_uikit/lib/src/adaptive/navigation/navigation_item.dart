import 'package:flutter/material.dart';

import 'package:pure_uikit/src/adaptive/adaptive_shell_sizes.dart';
import 'package:pure_uikit/src/adaptive/adaptive_surface_tokens.dart';
import 'package:pure_uikit/src/scales/spacing.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// A navigation destination shared by every adaptive navigation surface.
@immutable
class PureNavDestination {
  /// A destination with a stable [id], [label] and [icon].
  const new({
    required this.id,
    required this.label,
    required this.icon,
    IconData? selectedIcon,
    this.badgeCount,
    this.tooltip,
    this.enabled = true,
    this.showInCompactBar = true,
    this.startsGroup = false,
  }) : selectedIcon = selectedIcon ?? icon;

  /// Stable identifier used to resolve selection across different nav layouts.
  final String id;

  /// The display label.
  final String label;

  /// The resting glyph.
  final IconData icon;

  /// Optional filled/active variant of [icon].
  final IconData selectedIcon;

  /// Optional count badge.
  final int? badgeCount;

  /// Optional tooltip; defaults to [label].
  final String? tooltip;

  /// Whether the destination can be activated.
  final bool enabled;

  /// Whether this destination is considered for the compact bottom bar.
  final bool showInCompactBar;

  /// Inserts a subtle group divider before this destination on wide layouts.
  final bool startsGroup;

  /// A copy with the given fields replaced.
  PureNavDestination copyWith({
    String? id,
    String? label,
    IconData? icon,
    IconData? selectedIcon,
    int? badgeCount,
    String? tooltip,
    bool? enabled,
    bool? showInCompactBar,
    bool? startsGroup,
  }) {
    return PureNavDestination(
      id: id ?? this.id,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      selectedIcon: selectedIcon ?? this.selectedIcon,
      badgeCount: badgeCount ?? this.badgeCount,
      tooltip: tooltip ?? this.tooltip,
      enabled: enabled ?? this.enabled,
      showInCompactBar: showInCompactBar ?? this.showInCompactBar,
      startsGroup: startsGroup ?? this.startsGroup,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PureNavDestination &&
        other.id == id &&
        other.label == label &&
        other.icon == icon &&
        other.selectedIcon == selectedIcon &&
        other.badgeCount == badgeCount &&
        other.enabled == enabled &&
        other.showInCompactBar == showInCompactBar &&
        other.startsGroup == startsGroup;
  }

  @override
  int get hashCode => Object.hash(
    id,
    label,
    icon,
    selectedIcon,
    badgeCount,
    enabled,
    showInCompactBar,
    startsGroup,
  );
}

/// Orientation of the shared navigation tile.
enum PureNavigationTileLayout {
  /// Icon + label, used by desktop sidebars and drawers.
  horizontal,

  /// Icon over label, used by rails and TV navigation.
  vertical,
}

/// A single accessible, hoverable navigation row.
///
/// Ink effects are drawn by a transparent [Material], while the animated
/// selected background lives in the child. Keeping this in one place ensures
/// hover, focus, badge, and selection behaviour stay consistent across every
/// navigation surface. Keyboard focus gets an explicit brand outline, including
/// on the selected destination where an ink overlay would be hidden.
class PureNavigationTile extends StatefulWidget {
  /// Renders [destination] as one navigation row.
  const new({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.layout = PureNavigationTileLayout.horizontal,
    this.iconSize = 20,
    this.height,
    this.autofocus = false,
    this.showLabel = true,
    this.showSelectedBar = true,
    super.key,
  });

  /// The destination this row stands for.
  final PureNavDestination destination;

  /// Whether the row is the active destination.
  final bool selected;

  /// The activation handler; disabled destinations never call it.
  final VoidCallback onTap;

  /// Icon-by-label or icon-over-label.
  final PureNavigationTileLayout layout;

  /// The glyph size.
  final double iconSize;

  /// Overrides the row height.
  final double? height;

  /// Whether the row takes initial focus (TV/D-pad).
  final bool autofocus;

  /// Whether the vertical layout draws its label under the icon; false is
  /// the compact rail's icon-only cell, named by its tooltip instead.
  final bool showLabel;

  /// Whether the leading selection bar is drawn (horizontal layout).
  final bool showSelectedBar;

  @override
  State<PureNavigationTile> createState() => _PureNavigationTileState();
}

final class _PureNavigationTileState extends State<PureNavigationTile> {
  bool _focused = false;
  bool _hovered = false;

  /// True from the moment a pointer takes the tile until focus leaves it: a
  /// click answers in the fill and the pill alone — the ring is the
  /// keyboard's and the remote's answer, never the mouse's.
  bool _pointerFocused = false;

  /// The ring, only for a keyboard- or remote-driven focus.
  bool get _showsFocusRing => _focused && !_pointerFocused;

  void _handleFocusChange(bool focused) {
    if (_focused == focused) {
      return;
    }
    setState(() {
      _focused = focused;
      // Focus leaving ends a pointer's claim: the next arrival — by
      // traversal or remote — is the keyboard's to answer.
      if (!focused) {
        _pointerFocused = false;
      }
    });
    if (focused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        Scrollable.ensureVisible(
          context,
          duration: AdaptiveShellDurations.fast,
          curve: Curves.easeOutCubic,
          alignment: 0.5,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdaptiveSurfaceColors.of(context);
    final textTheme = PureTheme.of(context).text;
    final destination = widget.destination;
    final selected = widget.selected;
    final vertical = widget.layout == PureNavigationTileLayout.vertical;

    final foreground = !destination.enabled
        ? colors.textTertiary.withValues(alpha: 0.55)
        : selected
        ? colors.brand
        : colors.textSecondary;

    final icon = _NavIcon(
      destination: destination,
      selected: selected,
      color: foreground,
      size: widget.iconSize,
      colors: colors,
      showDot: vertical,
    );

    final content = vertical
        ? widget.showLabel
            ? Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  icon,
                  const SizedBox(height: 3),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.label.copyWith(
                      color: foreground,
                      fontSize: 10.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              )
            : icon
        : Row(
            children: <Widget>[
              if (widget.showSelectedBar)
                AnimatedContainer(
                  duration: AdaptiveShellDurations.fast,
                  curve: Curves.easeOutCubic,
                  width: 3,
                  height: selected ? 18 : 0,
                  decoration: BoxDecoration(color: colors.brand, borderRadius: BorderRadius.circular(3)),
                ),
              if (widget.showSelectedBar) const SizedBox(width: 9),
              icon,
              const SizedBox(width: PureSpacing.md),
              Expanded(
                child: Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.body.copyWith(
                    color: foreground,
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (destination.badgeCount != null) ...<Widget>[
                const SizedBox(width: PureSpacing.xs),
                _Badge(count: destination.badgeCount!, colors: colors),
              ],
            ],
          );

    final tile = AnimatedContainer(
      duration: AdaptiveShellDurations.fast,
      curve: Curves.easeOutCubic,
      height: widget.height ?? (vertical ? 62 : AdaptiveShellSizes.navItemHeight),
      padding: vertical
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 6)
          : const EdgeInsets.only(right: PureSpacing.sm),
      decoration: BoxDecoration(
        // The hover's answer is this same fill at a whisper, fading in —
        // the pane's own hover, never a block that snaps on.
        color: selected
            ? colors.brandSubtle
            : _hovered
            ? colors.hover
            : Colors.transparent,
        borderRadius: adaptiveTileRadius,
      ),
      foregroundDecoration: _showsFocusRing
          ? BoxDecoration(
              borderRadius: adaptiveTileRadius,
              border: Border.all(color: colors.brand, width: 1.4),
            )
          : null,
      child: Center(child: content),
    );

    return Semantics(
      selected: selected,
      enabled: destination.enabled,
      button: true,
      label: destination.label,
      child: Tooltip(
        message: destination.tooltip ?? destination.label,
        waitDuration: const Duration(milliseconds: 600),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: Material(
              color: Colors.transparent,
              borderRadius: adaptiveTileRadius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: destination.enabled ? widget.onTap : null,
                onTapDown: destination.enabled
                    ? (_) => setState(() => _pointerFocused = true)
                    : null,
                autofocus: widget.autofocus,
                onFocusChange: _handleFocusChange,
                borderRadius: adaptiveTileRadius,
                // Every ink effect is carried by the tile above — the hover
                // fill fades there, and a press takes the fill, not a ripple.
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,
                focusColor: Colors.transparent,
                mouseCursor: destination.enabled
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: tile,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _NavIcon extends StatelessWidget {
  const new({
    required this.destination,
    required this.selected,
    required this.color,
    required this.size,
    required this.colors,
    required this.showDot,
  });

  final PureNavDestination destination;
  final bool selected;
  final Color color;
  final double size;
  final AdaptiveSurfaceColors colors;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(selected ? destination.selectedIcon : destination.icon, size: size, color: color);

    if (!showDot || destination.badgeCount == null) {
      return icon;
    }

    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(left: 0, bottom: 0, child: icon),
          Positioned(
            right: -2,
            top: -3,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: colors.live,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _Badge extends StatelessWidget {
  const new({required this.count, required this.colors});

  final int count;
  final AdaptiveSurfaceColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(color: colors.live, borderRadius: BorderRadius.circular(999)),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}
