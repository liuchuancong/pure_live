import 'dart:async';

import 'package:fpdart/fpdart.dart' show Left;
import 'package:live_library/live_library.dart' show LibraryRoom;
import 'package:live_sites/live_sites.dart' show LiveRoom, LiveRoomIdentity, LiveRoomProvider, LiveSiteError;
import 'package:pure_live/app/composition/sites.dart' show AppSites;

/// What one pass over the followed rooms found.
final class FollowRefreshResult {
  /// Creates the result.
  const new({required this.rooms, required this.failed, required this.wentLive});

  /// The merged details to write back, in the order they were asked for.
  final List<LiveRoom> rooms;

  /// Requests that failed or timed out. Their rooms keep the stored detail —
  /// a room nobody answered for is not a room that went offline.
  final int failed;

  /// The rooms that were not live when the pass started and are live now.
  final List<LiveRoom> wentLive;
}

/// Re-reads the followed rooms' state (the reference's `FollowRefresher`): one
/// request per room, at most `concurrency` in flight, one adapter per platform,
/// a time limit per request, and a cooldown on a room whose last request failed.
///
/// A room of a platform this build has no adapter for is not asked at all and
/// stays exactly as stored, so a retired favourite never reads as offline.
final class FollowRefresher {
  /// A refresher over the booted [sites].
  new({
    required this.sites,
    this.timeout = const Duration(seconds: 10),
    this.cooldown = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// The platform registry the rooms are looked up in.
  final AppSites sites;

  /// The limit of one request.
  final Duration timeout;

  /// How long a failed room is skipped by passes that honour the cooldown.
  final Duration cooldown;

  final DateTime Function() _now;
  final Map<String, DateTime> _failedAt = {};

  /// Refreshes [followed]. [onProgress] answers after each request with the
  /// number done and the total; [cancelled] is consulted before each one, so a
  /// pass the user walked away from stops at the next boundary.
  Future<FollowRefreshResult> refresh(
    List<LibraryRoom> followed, {
    int concurrency = 4,
    bool bypassCooldown = false,
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    final now = _now();
    final queue = <_FollowJob>[];
    for (final record in followed) {
      final stored = record.room;
      final capability = sites.registry.getById(stored.ref.platform)?.capability<LiveRoomProvider>();
      if (capability == null) {
        // No adapter for this platform in this build: keep the stored detail.
        continue;
      }
      if (!bypassCooldown && now.difference(_failedAt[stored.identityKey] ?? DateTime(0)) < cooldown) {
        continue;
      }
      queue.add((record: record, capability: capability));
    }

    final rooms = <LiveRoom>[];
    final wentLive = <LiveRoom>[];
    var failed = 0;
    var done = 0;
    var cursor = 0;

    Future<void> worker() async {
      while (true) {
        if (cancelled?.call() ?? false) {
          return;
        }
        final index = cursor++;
        if (index >= queue.length) {
          return;
        }
        final job = queue[index];
        final stored = job.record.room;
        final fresh = await job.capability.getRoom(stored.ref.roomId).timeout(timeout).catchError((Object _) {
          return const Left<LiveSiteError, LiveRoom>(_timeoutError);
        });
        done += 1;
        onProgress?.call(done, queue.length);
        final merged = fresh.fold((_) => null, stored.mergedWith);
        if (merged == null) {
          failed += 1;
          _failedAt[stored.identityKey] = _now();
          continue;
        }
        _failedAt.remove(stored.identityKey);
        rooms.add(merged);
        if (!stored.broadcast.isLiveNow && merged.broadcast.isLiveNow) {
          wentLive.add(merged);
        }
      }
    }

    await Future.wait([for (var i = 0; i < concurrency.clamp(1, 16); i++) worker()]);
    return FollowRefreshResult(rooms: rooms, failed: failed, wentLive: wentLive);
  }
}

/// One room to ask about, with the adapter that answers for it.
typedef _FollowJob = ({LibraryRoom record, LiveRoomProvider capability});

/// The error a request that never answered is reported as. One value because
/// the caller only distinguishes "answered" from "did not".
const LiveSiteError _timeoutError = LiveSiteError.network(siteId: 'follow', message: 'room refresh timed out');
