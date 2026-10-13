import 'dart:async';

import 'package:live_shell/src/tray/tray_entry.dart';

/// Which physical interaction with the icon happened.
enum TrayPointer {
  /// The primary button.
  click,

  /// The secondary button, which on some shells is also how the menu is opened.
  rightClick,

  /// Two primary presses in a row.
  ///
  /// Distinct from [click] but deliberately not the way to open the app: a
  /// double click is delivered as two clicks first, so an app that opens the
  /// window on both reacts twice — the second reaction landing on a window that
  /// is already up, which looks like a flicker. Bind bringing-the-window-back to
  /// the single click and leave the double click for something idempotent.
  doubleClick,
}

/// The tray icon: what it shows, and what clicking it means.
///
/// [create] returning false is a result the caller must act on, not a log line.
/// A tray that cannot be drawn is normal on a Linux session without a status
/// notifier, and happens on Windows when the notification area is full or the
/// shell is mid-restart. Hiding a window at that point leaves a process with no
/// window and no icon — invisible to the viewer, uncloseable except through Task
/// Manager — so the close policy takes `hasTray` as an input and quits instead.
abstract interface class TrayHost {
  /// Puts the icon in the shell, reporting whether it got there.
  Future<bool> create({TrayIconState state = TrayIconState.idle});

  /// Whether the icon is actually present.
  bool get isCreated;

  /// Removes the icon. Part of every quit path, including the ones that go
  /// through process exit: a stale icon outlives its process only until the
  /// shell notices, which the viewer notices first.
  Future<void> dispose();

  /// Swaps the icon for [state].
  ///
  /// Implementations must not force a menu rebuild for an icon change, and must
  /// keep the two tinted assets for the states that need colour.
  Future<void> setIcon(TrayIconState state);

  /// Sets the hover text.
  ///
  /// Built from [truncateTrayLabel] with the elapsed or count suffix kept: the
  /// tooltip is where "recording, 01:12:45" has to survive.
  Future<void> setTooltip(String text);

  /// Applies [entries], rebuilding only if they differ from what is shown.
  ///
  /// Rebuilding is destructive — the open menu closes under the cursor — so an
  /// unchanged menu must not trigger one. A status tick that recomputes the same
  /// entries every second turns the tray into something that cannot be used.
  Future<void> setMenu(List<TrayEntry> entries);

  /// The ids of entries the viewer chose, in the order they were chosen.
  Stream<String> get selections;

  /// The raw pointer interactions, for the shells whose click conventions
  /// differ: on Windows and Linux a left click brings the window back and the
  /// right one opens the menu, while on macOS the click opens the menu and the
  /// window is reached from an entry in it.
  Stream<TrayPointer> get pointers;
}
