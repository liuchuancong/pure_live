import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveRestriction, LiveRoom, LiveStatus;
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// The reference's `cannotPlayHere` (shared/rooms/room_cards.dart): a
/// carousel, or a restriction this client cannot pass. A login or an age
/// check counts only while the platform has no credential ([signedIn]).
bool cannotPlayHere(LiveRoom room, {required bool signedIn}) {
  if (room.broadcast.effectiveLiveStatus == LiveStatus.carousel) return true;
  return switch (room.broadcast.effectiveRestriction) {
    LiveRestriction.none => false,
    LiveRestriction.needsLogin || LiveRestriction.adult => !signedIn,
    _ => true,
  };
}

/// Whether discovery (the popular page) also shows the rooms it would
/// otherwise hide — the reference's `showUnplayableInDiscover` (default
/// false). Follows and search always show them, exactly as there.
final class ShowUnplayableController extends Notifier<bool> {
  @override
  bool build() {
    try {
      return StoragePrefs.getBool('browse.showUnplayable') ?? false;
    } on Object {
      return false;
    }
  }

  /// Shows ([value]) or hides the unplayable rooms; written through at
  /// once, and the feeds re-apply the rule on their own change listener.
  void setShow({required bool value}) {
    state = value;
    unawaited(StoragePrefs.setBool('browse.showUnplayable', value));
  }
}

/// The discovery pages' "show unplayable" answer.
final showUnplayableProvider = NotifierProvider<ShowUnplayableController, bool>(ShowUnplayableController.new);
