/// The room's two doors into its own platform: the area a broadcast
/// belongs to (the partition's room list) and the streamer's videos beside
/// the picture (each platform's own shape of that).
library;

import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart' show LiveArea, LiveRoom, SiteIds;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/archive/archive_navigation.dart' show openArchives;
import 'package:pure_live/modules/live/areas/controllers/areas_controller.dart';
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/modules/live/room/page/room_status.dart' show RoomPictureKind, pictureStateOf;

/// Opens the partition's room list for [room]'s own area: the identity
/// bar's and the details hero's `平台 · 分区` line lead here. An area the
/// detail named only by its words is matched against the platform's areas
/// catalogue (the areas page's own cached read) before giving up.
Future<void> openRoomArea(BuildContext context, WidgetRef ref, LiveRoom room) async {
  final t = context.t;
  final platform = room.ref.platform;
  final area = room.area;
  final name = (area?.areaName ?? '').trim();
  if (area == null || name.isEmpty) {
    showDsToast(context: context, title: t.room.areaUnavailable, status: DsStatus.danger);
    return;
  }
  final id = area.areaId.trim();
  var target = area;
  if (id.isEmpty) {
    final areas = await _platformAreas(ref, platform);
    final match = areas.where((candidate) => candidate.areaName == name).firstOrNull;
    if (match == null) {
      if (context.mounted) {
        showDsToast(context: context, title: t.room.areaUnavailable, status: DsStatus.danger);
      }
      return;
    }
    target = match;
  }
  if (!context.mounted) return;
  unawaited(
    context.push(
      AreaRoomsRoute(platform: target.platform, areaId: target.areaId).location,
      extra: target,
    ),
  );
}

/// Opens the streamer's own videos on their platform: Bilibili's space
/// page, Huya's uploader page, or the replay catalogue Douyu and Soop keep
/// behind a room. A streamer no station names an id for says so.
Future<void> openAnchorVideos(BuildContext context, WidgetRef ref, LiveRoom room) async {
  final t = context.t;
  final platform = room.ref.platform;
  final anchorId = (room.anchor?.anchorId ?? '').trim();
  switch (platform) {
    case SiteIds.bilibili:
      if (anchorId.isEmpty) {
        showDsToast(context: context, title: t.room.anchorVideosUnavailable, status: DsStatus.danger);
        return;
      }
      unawaited(context.push('/vod/u/$anchorId'));
    case SiteIds.huya:
      if (anchorId.isEmpty) {
        showDsToast(context: context, title: t.room.anchorVideosUnavailable, status: DsStatus.danger);
        return;
      }
      unawaited(context.push('/huya/u/$anchorId'));
    case SiteIds.douyu:
    case SiteIds.soop:
      await _openReplayCatalog(context, ref, room);
    default:
      showDsToast(context: context, title: t.room.anchorVideosUnavailable, status: DsStatus.danger);
  }
}

/// The replay catalogue walk, the player surface's own entry verbatim: the
/// covered decoder goes quiet while a recording opens and the room reads
/// its own picture again after the walk — unless the viewer had personally
/// paused it.
Future<void> _openReplayCatalog(BuildContext context, WidgetRef ref, LiveRoom room) async {
  final controller = ref.read(roomProvider.notifier);
  final walked = await openArchives(
    context,
    room: room,
    push: (arguments) => context.push<Object?>(RouteNames.archive, extra: arguments),
    beforePlay: controller.pause,
  );
  if (!walked || !context.mounted) return;
  if (pictureStateOf(context.t, ref.read(roomProvider)).kind == RoomPictureKind.paused) {
    await controller.togglePlayPause();
  }
}

/// The platform's areas catalogue, read once and kept: an empty answer asks
/// the controller to load (its API memory cache answers a repeat within the
/// TTL) before the caller matches by name.
Future<List<LiveArea>> _platformAreas(WidgetRef ref, String platform) async {
  final controller = ref.read(areasCatalogProvider.notifier);
  var catalog = controller.catalogOf(platform);
  if (catalog.areas.isEmpty) {
    await controller.open(platform);
    catalog = controller.catalogOf(platform);
  }
  return catalog.areas;
}
