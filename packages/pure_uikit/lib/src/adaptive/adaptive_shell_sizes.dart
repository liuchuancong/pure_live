import 'package:flutter/material.dart';

/// Layout constants shared by the adaptive shell and its navigation surfaces.
abstract final class AdaptiveShellSizes {
  /// The compact app bar height.
  static const double compactAppBarHeight = 56;

  /// The workspace toolbar height on wide layouts.
  static const double topBarHeight = 64;

  /// The labelled desktop sidebar's width.
  static const double sidebarWidth = 224;

  /// The tablet icon rail's width.
  static const double railWidth = 88;

  /// The collapsed rail's width — the compact pane: icon-only cells 44 tall,
  /// named by tooltips, a step narrower than the labelled rail.
  static const double compactRailWidth = 72;

  /// The phone drawer's width.
  static const double drawerWidth = 320;

  /// The focus-first TV rail's width.
  static const double tvRailWidth = 112;

  /// One horizontal navigation row's height.
  static const double navItemHeight = 42;

  /// The phone bottom bar's height.
  static const double bottomNavHeight = 62;

  /// The widest page content on any layout.
  static const double contentMaxWidth = 1440;
}

/// Motion durations for hover, selection, and drawer transitions.
abstract final class AdaptiveShellDurations {
  /// Hover and selection fills.
  static const Duration fast = Duration(milliseconds: 120);

  /// Drawer and pane transitions.
  static const Duration normal = Duration(milliseconds: 180);

  /// Page-level transitions.
  static const Duration slow = Duration(milliseconds: 260);
}

/// The nav tile's corner radius — a fixed soft radius rather than a token, so
/// a selection pill keeps its shape.
const BorderRadius adaptiveTileRadius = BorderRadius.all(Radius.circular(8));

/// The scrim over the content behind an open drawer.
Color adaptiveDrawerScrim({required bool isDark}) => Colors.black.withValues(alpha: isDark ? 0.58 : 0.28);
