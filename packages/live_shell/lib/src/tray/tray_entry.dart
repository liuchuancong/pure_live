import 'package:meta/meta.dart';

/// What the tray icon is saying about the app right now.
///
/// The colour is the message, so these are chosen to be distinguishable at 16
/// pixels and in both light and dark shell themes. On macOS that is also why the
/// icon is *not* exported as a template image: a template forces monochrome and
/// erases the difference between "recording" and "idle", leaving the menu bar
/// looking identical whatever is happening — so the app supplies two tinted
/// assets instead and accepts the contrast work that comes with it.
enum TrayIconState {
  /// Nothing running.
  idle,

  /// A room is playing in a window that exists.
  playing,

  /// A recording is in progress — the one state the viewer may need to see
  /// without opening the app, because it is the one with a consequence.
  recording,

  /// Something is running but blocked: reconnecting, out of disk, awaiting a
  /// permission the OS just took away.
  attention,
}

/// Whether the state means "work is happening behind the icon".
extension TrayIconStateX on TrayIconState {
  /// Whether something is live enough that quitting should warn about it.
  bool get isBusy => this == TrayIconState.recording || this == TrayIconState.playing;
}

/// One entry of the tray's right-click menu.
///
/// The menu is rebuilt wholesale on most platforms, which is why
/// [trayMenuNeedsRebuild] exists: a rebuild that could have been skipped closes
/// the menu the viewer is pointing at. Anything the viewer can reach by
/// expanding a submenu is a [TraySubmenu] rather than a flattened list, because
/// a tray menu with forty rows is not a menu.
@immutable
sealed class TrayEntry {
  /// A menu entry.
  const new({required this.id, required this.label, this.enabled = true});

  /// Stable identity for diffing and for routing the click back.
  final String id;

  /// The text. Keep it short: the shell truncates long labels itself, and
  /// [truncateTrayLabel] exists so the truncation never eats the part that
  /// matters.
  final String label;

  /// Whether it is clickable. A disabled row is still information.
  final bool enabled;
}

/// A clickable item.
@immutable
final class TrayAction extends TrayEntry {
  /// An item that does something.
  const new({required super.id, required super.label, this.checked, this.badge, super.enabled = true});

  /// A command's check state, for the toggles that live in the tray
  /// (play in background, launch at sign-in). Null means the item is not a
  /// toggle.
  final bool? checked;

  /// A short status suffix, e.g. `01:23:45` or `3`.
  ///
  /// It is a separate field rather than pasted onto [label] precisely so the
  /// label can be shortened without losing it.
  final String? badge;
}

/// A non-clickable heading, typically the app's live status.
@immutable
final class TrayHeading extends TrayEntry {
  /// A status line.
  const new({required super.id, required super.label});
}

/// A divider.
@immutable
final class TrayDivider extends TrayEntry {
  /// A separator between groups. Its id is stable so a menu diff sees the
  /// divider in the same place rather than as a removed row plus a new one.
  const new({super.id = '---', super.label = ''});

  @override
  bool operator ==(Object other) => other is TrayDivider;

  @override
  int get hashCode => id.hashCode;
}

/// A submenu: a heading with children, used for the platform list and for the
/// recording targets, where the items are as numerous as the sources.
@immutable
final class TraySubmenu extends TrayEntry {
  /// A submenu.
  const new({required super.id, required super.label, required this.children, super.enabled = true});

  /// Its entries, in display order.
  final List<TrayEntry> children;
}

/// Whether rebuilding the tray menu can be skipped.
///
/// Equality here is over the *rendered* shape, so a rebuild is only forced by
/// something the viewer would notice: a label, a check state, a badge, an
/// enable flag, the order or the depth. A new object identity with the same
/// content must not cause one — that is the bug where a progress counter pushes
/// a menu closed under the cursor once a second.
bool trayMenuNeedsRebuild(List<TrayEntry> before, List<TrayEntry> after) {
  if (before.length != after.length) {
    return true;
  }
  for (final (index, entry) in after.indexed) {
    if (!_sameEntry(before[index], entry)) {
      return true;
    }
  }
  return false;
}

bool _sameEntry(TrayEntry a, TrayEntry b) {
  if (a.id != b.id || a.label != b.label || a.enabled != b.enabled) {
    return false;
  }
  if (a is TrayAction && b is TrayAction) {
    return a.checked == b.checked && a.badge == b.badge;
  }
  if (a is TraySubmenu && b is TraySubmenu) {
    return !trayMenuNeedsRebuild(a.children, b.children);
  }
  return a.runtimeType == b.runtimeType;
}

/// Shortens [label] to [maxLength] characters, keeping [TrayAction.badge] whole.
///
/// The suffix is the reason this is a function and not a `…`-append: in
/// `CCTV 1 综合 · 录制中 01:12:45` the elapsed time is the only part the viewer
/// is looking for, and a naive tail truncation deletes exactly it while keeping
/// the channel name, which they already know.
String truncateTrayLabel(String label, {int maxLength = 34, String? keepSuffix}) {
  if (label.length <= maxLength) {
    return label;
  }
  final budget = maxLength - 1;
  if (keepSuffix == null || keepSuffix.isEmpty) {
    return '${label.substring(0, budget)}…';
  }
  final room = budget - keepSuffix.length - 3;
  if (room <= 2) {
    // The suffix alone fills the line: show it and let the name go entirely.
    return keepSuffix.length <= budget ? keepSuffix : keepSuffix.substring(0, budget);
  }
  return '${label.substring(0, room)}… $keepSuffix';
}
