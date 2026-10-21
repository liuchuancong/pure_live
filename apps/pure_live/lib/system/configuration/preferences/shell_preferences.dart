import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:pure_live/system/configuration/preferences/values.dart';

/// The shell's shape: the launch branch, the last visited branch, whether the wide column is expanded, its width, and the stored window size — the reference's `app` and `windowSize` sections.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The visible shell branches, in the shipping order — the page settings'
/// untouched default.
const List<String> defaultShellBranches = ['follow', 'popular', 'areas', 'iptv', 'record'];

/// The default before IPTV joined the chrome. A stored document still naming
/// exactly this list was never customised, so it grows the current default
/// instead of keeping IPTV hidden.
const List<String> legacyShellBranches = ['follow', 'popular', 'areas', 'record'];

/// The shell's shape: the launch branch, the last visited branch, whether
/// the wide column is expanded, its width, the stored window size and the
/// visible branch list.
@immutable
final class ShellPreferences extends Equatable {
  /// The shipping defaults.
  const new({
    this.launchBranch = AppLaunchBranch.follow,
    this.restoreLastTab = false,
    this.lastBranchId,
    this.shellNavExpanded = true,
    this.sidebarWidth = 180,
    this.windowWidth = 0,
    this.windowHeight = 0,
    this.shellBranches = defaultShellBranches,
  });

  /// Reads the domain's keys from the flat document; unknown shapes decode
  /// to the defaults.
  factory ShellPreferences.fromJson(Map<String, Object?> json) {
    final branches = (json['shellBranches'] as List<Object?>?)?.whereType<String>().toList();
    return ShellPreferences(
      launchBranch: AppLaunchBranch.fromId(json['launchBranch'] as String?),
      restoreLastTab: json['restoreLastTab'] as bool? ?? false,
      lastBranchId: json['lastBranchId'] as String?,
      shellNavExpanded: json['shellNavExpanded'] as bool? ?? true,
      sidebarWidth: (json['sidebarWidth'] as num?)?.toDouble() ?? 180,
      windowWidth: json['windowWidth'] as int? ?? 0,
      windowHeight: json['windowHeight'] as int? ?? 0,
      shellBranches: branches == null || branches.isEmpty ? defaultShellBranches : branches,
    );
  }

  /// The branch the router starts on, unless [restoreLastTab] wins.
  final AppLaunchBranch launchBranch;

  /// Whether the app starts on the branch it was last left on.
  final bool restoreLastTab;

  /// The shell branch id the app was last left on; null before the first
  /// tab switch.
  final String? lastBranchId;

  /// Whether the wide column is drawn expanded (the labelled sidebar) or
  /// collapsed (the icon rail). The toggle in the column's head flips it, the
  /// choice survives restarts, and the width classes apply on top without
  /// ever rewriting it — a narrow window draws the rail whatever this says.
  final bool shellNavExpanded;

  /// The labelled sidebar's width, in logical pixels — what the drag handle
  /// between the panes writes and every boot restores. The shell clamps it
  /// before drawing, so a hand-edited document cannot stretch it absurdly.
  final double sidebarWidth;

  /// The desktop window's stored width; 0 keeps the launch default.
  final int windowWidth;

  /// The desktop window's stored height; 0 keeps the launch default.
  final int windowHeight;

  /// The visible shell branches, in display order; the home branch is the
  /// floor, so this is never empty.
  final List<String> shellBranches;

  /// The domain's keys as stored, flat.
  Map<String, Object?> toJson() => {
    'launchBranch': launchBranch.id,
    'restoreLastTab': restoreLastTab,
    'lastBranchId': lastBranchId,
    'shellNavExpanded': shellNavExpanded,
    'sidebarWidth': sidebarWidth,
    'windowWidth': windowWidth,
    'windowHeight': windowHeight,
    'shellBranches': shellBranches,
  };

  /// Returns a copy with the given fields replaced.
  ShellPreferences copyWith({
    AppLaunchBranch? launchBranch,
    bool? restoreLastTab,
    String? lastBranchId,
    bool? shellNavExpanded,
    double? sidebarWidth,
    int? windowWidth,
    int? windowHeight,
    List<String>? shellBranches,
  }) => ShellPreferences(
    launchBranch: launchBranch ?? this.launchBranch,
    restoreLastTab: restoreLastTab ?? this.restoreLastTab,
    lastBranchId: lastBranchId ?? this.lastBranchId,
    shellNavExpanded: shellNavExpanded ?? this.shellNavExpanded,
    sidebarWidth: sidebarWidth ?? this.sidebarWidth,
    windowWidth: windowWidth ?? this.windowWidth,
    windowHeight: windowHeight ?? this.windowHeight,
    shellBranches: shellBranches ?? this.shellBranches,
  );

  @override
  List<Object?> get props => [
    launchBranch,
    restoreLastTab,
    lastBranchId,
    shellNavExpanded,
    sidebarWidth,
    windowWidth,
    windowHeight,
    shellBranches,
  ];
}
