import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_metrics.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/adwaita_settings_tile.dart'
    show kAdwaitaBodyFontSize;
import 'package:pure_settings_ui/src/vendor/utils/settings_style.dart';

/// iPad Settings keeps its sidebar at 320pt in both orientations
/// (UISplitViewController's default maximum primary column width).
const double kCupertinoListPaneWidth = 320;

/// AOSP Settings gives the homepage 36.36% of the window
/// (config_activity_embed_split_ratio).
const double kMaterialListPaneFraction = 0.3636;

/// Chrome's settings menu (--settings-menu-width).
const double kWebListPaneWidth = 266;

/// Chrome's settings page: #main's flex basis is the 680px card column
/// divided by the 96% card width.
const double kWebMainBasis = 680 / 0.96;

/// The macOS 27 System Settings sidebar, measured in a 740pt window.
/// (SwiftUI's own default is 215, resizable from 200 to 300.)
const double kMacosListPaneWidth = 232;

/// SwiftUI's `NavigationSplitView` never collapses on the Mac, but a macOS
/// style split view also runs in narrow windows, on phones and on the web.
/// Two panes need room for the 232pt sidebar and a detail pane of at least
/// 328pt: about two thirds of System Settings' ~507pt pane, the narrowest
/// width at which its grouped rows (20pt margins, 10pt insets) still fit a
/// label, a value and a control on one line. Narrower windows, phone-sized
/// ones included, show one pane, like SwiftUI in a compact width.
const double kMacosTwoPaneMinWidth = 560;

/// WinUI `NavigationView` (PaneDisplayMode Auto): the pane is open from
/// this window width (ExpandedModeThresholdWidth)...
const double kFluentExpandedMinWidth = 1008;

/// ...a compact icon rail from this one (CompactModeThresholdWidth), and
/// hidden below it.
const double kFluentCompactMinWidth = 641;

/// The open pane of Windows 11 Settings, measured on a real capture: its
/// items are 280 wide and start 16 from the window edge, and the 1000px
/// content column is centered in the rest of the window. (WinUI's default
/// OpenPaneLength is 320.)
const double kFluentExpandedPaneWidth = 300;

/// WinUI's CompactPaneLength: the icon rail.
const double kFluentCompactPaneWidth = 48;

/// GNOME Settings' `AdwNavigationSplitView`: the sidebar takes a quarter
/// of the window, between 180sp and 280sp...
const double kAdwaitaSidebarFraction = 0.25;
const double kAdwaitaSidebarMinWidth = 180;
const double kAdwaitaSidebarMaxWidth = 280;

/// ...and the view collapses to one pane at `max-width: 550sp`.
const double kAdwaitaCollapseWidth = 550;

/// How much GNOME's sp sizes grow with the text size: as much as its body
/// text (11pt, 14.67px). A non-linear [TextScaler] (Android 14 and later)
/// grows large sizes less than text, so scaling 180 or 550 directly would
/// barely move them.
double adwaitaSpScale(TextScaler textScaler) =>
    textScaler.scale(kAdwaitaBodyFontSize) / kAdwaitaBodyFontSize;

/// Where the panes go, for one layout pass. Internal.
@immutable
class SplitGeometry {
  const SplitGeometry.single()
    : isSplit = false,
      listWidth = 0,
      gap = 0,
      detailWidth = 0,
      compactPane = false;

  const SplitGeometry.split({
    required this.listWidth,
    required this.gap,
    required this.detailWidth,
    this.compactPane = false,
  }) : isSplit = true;

  final bool isSplit;

  /// The list pane is the Windows style's compact icon rail
  /// ([kFluentCompactPaneWidth] wide), which opens over the detail pane.
  final bool compactPane;

  /// Width of the list pane (the start pane).
  final double listWidth;

  /// Space between the panes: the hinge, when one splits the window.
  final double gap;
  final double detailWidth;

  @override
  String toString() => isSplit
      ? 'SplitGeometry.split($listWidth | $gap | $detailWidth'
            '${compactPane ? ', compact' : ''})'
      : 'SplitGeometry.single()';
}

/// Whether the host platform is a desktop, where the window's shortest side
/// says nothing about the device.
bool isDesktopPlatform(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

/// Whether a style shows two panes at [width] by default.
///
/// - Cupertino (iPad): width >= 600 on a device whose shortest side is at
///   least 600 (so an iPad, iPad mini portrait included, but not an iPhone in
///   landscape). Apple publishes no point threshold; iPadOS switches with the
///   horizontal size class, which is compact in a 444pt window and regular
///   in the 744pt iPad mini portrait.
/// - Material: AOSP Settings' rule, width >= 720dp and smallest width
///   >= 600dp.
/// - Web: Chrome's, width > 980px.
/// - macOS: width >= [kMacosTwoPaneMinWidth].
/// - Windows: width >= [kFluentCompactMinWidth] (the compact rail up to
///   [kFluentExpandedMinWidth]).
/// - GNOME: width > [kAdwaitaCollapseWidth], scaled by the text size.
///
/// On desktops only the width counts. The desktop styles only look at the
/// width anywhere, like their toolkits.
bool defaultShowsTwoPanes({
  required SettingsStyleFamily family,
  required double width,
  required double shortestSide,
  required bool desktop,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  switch (family) {
    case SettingsStyleFamily.cupertino:
      return width >= 600 && (desktop || shortestSide >= 600);
    case SettingsStyleFamily.material:
      return width >= 720 && (desktop || shortestSide >= 600);
    case SettingsStyleFamily.web:
      return width > 980;
    case SettingsStyleFamily.macos:
      return width >= kMacosTwoPaneMinWidth;
    case SettingsStyleFamily.fluent:
      return width >= kFluentCompactMinWidth;
    case SettingsStyleFamily.adwaita:
      return width > kAdwaitaCollapseWidth * adwaitaSpScale(textScaler);
    case SettingsStyleFamily.pure:
      // The same rule AOSP Settings uses: wide enough for two panes, and on a
      // phone only when the shortest side says it is really a tablet.
      return width >= pureSettingsSplitBreakpoint && (desktop || shortestSide >= 600);
  }
}

/// The default list pane width of a style for a window [width] wide.
double defaultListPaneWidth(
  SettingsStyleFamily family,
  double width, {
  TextScaler textScaler = TextScaler.noScaling,
}) {
  switch (family) {
    case SettingsStyleFamily.cupertino:
      return kCupertinoListPaneWidth;
    case SettingsStyleFamily.material:
      return width * kMaterialListPaneFraction;
    case SettingsStyleFamily.web:
      return kWebListPaneWidth;
    case SettingsStyleFamily.macos:
      return kMacosListPaneWidth;
    case SettingsStyleFamily.fluent:
      return width >= kFluentExpandedMinWidth
          ? kFluentExpandedPaneWidth
          : kFluentCompactPaneWidth;
    case SettingsStyleFamily.adwaita:
      return adwaitaSidebarWidth(width, textScaler);
    case SettingsStyleFamily.pure:
      // A fixed pane, like macOS's and Chrome's: a pure_uikit row carries a
      // leading icon, a title and a trailing control, and 280 keeps a
      // sentence-case title on one line at the token's body size.
      return pureSettingsListPaneWidth;
  }
}

/// GNOME's sidebar width in a window [width] wide: a quarter of it,
/// clamped to 180–280sp.
double adwaitaSidebarWidth(double width, TextScaler textScaler) {
  final sp = adwaitaSpScale(textScaler);
  final min = kAdwaitaSidebarMinWidth * sp;
  final max = math.max(min, kAdwaitaSidebarMaxWidth * sp);
  return (width * kAdwaitaSidebarFraction).clamp(min, max);
}

/// A fold or hinge that cuts the split view into a start and an end part,
/// in the split view's coordinates.
@immutable
class SeparatingHinge {
  const SeparatingHinge({required this.left, required this.right});

  /// Distance from the split view's left edge to the hinge.
  final double left;

  /// Distance from the split view's left edge to the end of the hinge.
  final double right;

  double get width => right - left;
}

/// Finds a vertical display feature that separates the window into two
/// screens within `[origin.dx, origin.dx + size.width]`.
///
/// A hinge (always occluding) or a fold in the half-opened (book) posture
/// separates. A flat fold, like an unfolded Pixel Fold, does not, so it
/// doesn't move the panes (Material's HingePolicy.AvoidSeparating).
/// Horizontal (tabletop) features are ignored.
SeparatingHinge? findSeparatingHinge({
  required List<DisplayFeature> features,
  required Offset origin,
  required Size size,
}) {
  for (final feature in features) {
    final bounds = feature.bounds;
    if (feature.type == DisplayFeatureType.cutout) continue;
    final separates =
        feature.type == DisplayFeatureType.hinge ||
        feature.state == DisplayFeatureState.postureHalfOpened;
    if (!separates) continue;
    // Vertical: taller than wide and spanning the split view's height.
    final vertical =
        bounds.height > bounds.width &&
        bounds.top <= origin.dy + 0.5 &&
        bounds.bottom >= origin.dy + size.height - 0.5;
    if (!vertical) continue;
    final left = bounds.left - origin.dx;
    final right = bounds.right - origin.dx;
    // Only a hinge strictly inside the split view splits it.
    if (left <= 0 || right >= size.width) continue;
    return SeparatingHinge(left: left, right: right);
  }
  return null;
}

/// Decides one or two panes and their widths.
///
/// The Windows style's list pane is the compact rail below
/// [kFluentExpandedMinWidth], whatever [listPaneWidth] says: that only sets
/// the open pane.
SplitGeometry computeSplitGeometry({
  required SettingsStyleFamily family,
  required bool forceSingle,
  required bool forceSplit,
  required double width,
  required double shortestSide,
  required bool desktop,
  required TextDirection textDirection,
  TextScaler textScaler = TextScaler.noScaling,
  double? breakpoint,
  double? listPaneWidth,
  SeparatingHinge? hinge,
}) {
  if (forceSingle || width <= 0) return const SplitGeometry.single();

  // A separating hinge always gets one pane on each side of it, the list on
  // the start side: nothing should straddle it.
  if (hinge != null) {
    final startWidth = textDirection == TextDirection.ltr
        ? hinge.left
        : width - hinge.right;
    return SplitGeometry.split(
      listWidth: startWidth,
      gap: hinge.width,
      detailWidth: width - startWidth - hinge.width,
    );
  }

  final split =
      forceSplit ||
      (breakpoint != null
          ? width >= breakpoint
          : defaultShowsTwoPanes(
              family: family,
              width: width,
              shortestSide: shortestSide,
              desktop: desktop,
              textScaler: textScaler,
            ));
  if (!split) return const SplitGeometry.single();

  if (family == SettingsStyleFamily.fluent && width < kFluentExpandedMinWidth) {
    final rail = math.min(kFluentCompactPaneWidth, width / 2);
    return SplitGeometry.split(
      listWidth: rail,
      gap: 0,
      detailWidth: width - rail,
      compactPane: true,
    );
  }

  var listWidth =
      listPaneWidth ??
      defaultListPaneWidth(family, width, textScaler: textScaler);
  // Leave the detail at least half the window when a narrow window is forced
  // into two panes.
  listWidth = math.min(listWidth, width / 2);
  return SplitGeometry.split(
    listWidth: listWidth,
    gap: 0,
    detailWidth: width - listWidth,
  );
}

/// Chrome's settings page puts a spacer after its content that grows as fast
/// as the content area (#main and #right both flex: 1), so the 680px column
/// sits closer to the menu than to the window edge. Returns that spacer's
/// width for a detail pane [detailWidth] wide.
double webDetailEndReserve(double detailWidth) =>
    math.max(0, (detailWidth - kWebMainBasis) / 2);
