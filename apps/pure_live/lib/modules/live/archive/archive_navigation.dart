import 'package:desen_ui/desen_ui.dart' show DsStatus, showDsToast;
import 'package:flutter/widgets.dart' show BuildContext, ValueChanged;
import 'package:live_sites/live_sites.dart' show LiveRoom;

import 'package:pure_live/l10n/translations.dart';

/// In-memory ownership callbacks for the application's registered archive
/// route. Keeps media ownership local; this object is never serialized or
/// persisted, so it only ever rides a route's `extra`.
final class ArchiveArguments {
  /// Kept local to the app's memory.
  const new({this.room, this.beforePlay, this.onRetire, this.pickOnly = false});

  /// Returns metadata to the existing room without creating a second player.
  final bool pickOnly;

  /// Optional presenter identity already known by the invoking page.
  final LiveRoom? room;

  /// Releases a covered live decoder before opening the selected recording.
  final Future<void> Function()? beforePlay;

  /// Reports actual asynchronous native retirement to the owning page.
  final ValueChanged<Future<void>>? onRetire;
}

/// Opens the archive route and awaits both entry and native retirement
/// before deciding whether the invoking room resumes.
///
/// [push] is the route-table seam: the invoking feature hands in its typed
/// route's push and no page imports another's page. Back may close the
/// catalog while the live decoder is still stopping — never decide whether
/// to resume until the owning retirement callback has settled.
Future<bool> openArchives(
  BuildContext context, {
  required Future<Object?> Function(ArchiveArguments arguments) push,
  LiveRoom? room,
  Future<void> Function()? beforePlay,
}) async {
  var entering = Future<void>.value();
  var retirement = Future<void>.value();
  Object? retirementError;
  try {
    await push(
      ArchiveArguments(
        room: room,
        beforePlay: beforePlay == null ? null : () => entering = Future<void>.sync(beforePlay),
        onRetire: (future) {
          retirement = future.then<void>(
            (_) {},
            onError: (Object error, StackTrace _) {
              retirementError = error;
            },
          );
        },
      ),
    );
    await entering;
    await retirement;
    if (retirementError != null) throw StateError('Archive native retirement failed');
    return true;
  } on Object {
    await entering.catchError((Object _) {});
    await retirement.catchError((Object _) {});
    if (context.mounted) {
      showDsToast(context: context, title: context.t.room.replayOpenFailed, status: DsStatus.danger);
    }
    return false;
  }
}
