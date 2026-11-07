import 'package:desen_ui/desen_ui.dart' show DsStatus, showDsToast;
import 'package:flutter/widgets.dart' show BuildContext, ValueChanged;
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:live_vod/live_vod.dart' show DouyuVodVideo, HuyaArchiveVideo, SoopArchiveVideo;

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

/// What the archive player page opens: the recording's public metadata —
/// whichever platform's slot it rides — and the invoking room's ownership
/// callbacks. In-memory only; never serialized or persisted.
final class ArchivePlayerRequest {
  /// Kept local to the app's memory; exactly one recording slot is filled.
  const new({required this.arguments, this.soop, this.huya, this.douyu});

  /// The SOOP recording, whose parts the controller walks.
  final SoopArchiveVideo? soop;

  /// The Huya recording, whose renditions the controller reads.
  final HuyaArchiveVideo? huya;

  /// The Douyu recording, whose session's segments the controller reads.
  final DouyuVodVideo? douyu;

  /// The invoking room's callbacks (its decoder release and the retirement
  /// it waits on).
  final ArchiveArguments arguments;

  /// The recording's title, whatever platform it rides.
  String get title => soop?.title ?? huya?.title ?? douyu?.title ?? '';
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
