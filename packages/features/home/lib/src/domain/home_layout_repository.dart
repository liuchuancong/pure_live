// Module: lib/src/domain/home_layout_repository.dart
// Purpose: What the home surface needs from persistence, without saying where the layout lives.
// Author: liuchuancong
// Created: 2026-10-10
//
// The screen reads a layout and writes one; who stores it, per account or per device, is the app's
// decision. Keeping the interface here means an app that wants the arrangement to follow the signed-in
// user substitutes a different implementation instead of forking the domain.

import 'home_tab.dart';

/// The saved order-and-visibility choice for one app's home tabs.
abstract interface class HomeLayoutRepository {
  /// The stored layout, or an empty one when nothing has been saved or the row could not be read.
  ///
  /// A read never throws: an unreadable row costs the user their arrangement, and the recovery path is the
  /// defaults plus a report, not an exception on the way to the first screen of the app.
  Future<HomeLayout> load();

  /// Saves [layout] and returns what a subsequent [load] will produce.
  Future<HomeLayout> save(HomeLayout layout);

  /// Discards the user's choice so the app's declared defaults apply again.
  Future<void> reset();
}
