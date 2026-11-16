import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:pure_live/app/app.dart' show sitesProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/modules/live/room/panels/room_panel.dart' show showRoomDetails;
import 'package:pure_live/modules/live/room/room_links.dart' show openAnchorVideos, openRoomArea;
import 'package:pure_live/shared/shared.dart' show avatarInitials, cachedImage, localizedSiteName;

/// The title bar's identity block (the redesign's own shape): the avatar in
/// its live ring, and two lines — the anchor's name over the platform and
/// area. The room's title is not here: it lives on the picture's own caption
/// (see the player surface), so the bar stays the identity's only home —
/// the words that answer "who am I watching, where" sit by the window's
/// actions, and the words that answer "what is this" sit by the picture.
final class RoomIdentityBar extends ConsumerWidget {
  const RoomIdentityBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final detail = ref.watch(roomProvider.select((room) => room.room));
    if (detail == null) {
      // The detail hasn't landed: the block keeps its footprint with the
      // quiet blocks the two lines rest on, so the bar never jumps when the
      // facts arrive.
      return const Padding(
        padding: EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s4),
        child: Row(
          spacing: DsSpace.s8,
          children: [
            DsSkeleton.circle(size: 34),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s4,
              children: [DsSkeleton(width: 120, height: 14), DsSkeleton(width: 160, height: 11)],
            ),
          ],
        ),
      );
    }
    final anchor = (detail.anchor?.name ?? '').trim();
    final name = anchor.isEmpty ? detail.content.title : anchor;
    final avatar = (detail.anchor?.avatarUrl ?? detail.content.coverUrl).trim();
    final live = detail.broadcast.isLiveNow;
    final matches = ref.watch(sitesProvider).all.where((site) => site.manifest.id == detail.ref.platform);
    final platform = matches.isEmpty ? detail.ref.platform : localizedSiteName(matches.first);
    final area = (detail.area?.areaName ?? '').trim();
    final where = [platform, if (area.isNotEmpty) area].join(' · ');
    return DsPressable(
      semanticLabel: name,
      onPressed: () => unawaited(showRoomDetails(context)),
      builder: (context, states, _) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s4),
        child: Row(
          spacing: DsSpace.s8,
          children: [
            // The avatar is its own door — the streamer's videos on their
            // platform — said by the ring warming on hover and the tooltip,
            // while the rest of the row stays the details panel.
            DsTooltip(
              message: t.room.anchorVideosHint,
              child: DsPressable(
                semanticLabel: t.room.anchorVideos,
                onPressed: () => unawaited(openAnchorVideos(context, ref, detail)),
                builder: (context, states, _) => Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: states.contains(WidgetState.hovered)
                        ? colors.hover
                        : live
                        ? colors.accent
                        : colors.border,
                  ),
                  child: DsAvatar(
                    initials: avatarInitials(name),
                    image: avatar.isEmpty ? null : cachedImage(avatar, policy: ImageCachePolicies.avatar),
                    size: DsSize.sm,
                    semanticLabel: name,
                  ),
                ),
              ),
            ),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 1,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.bodyStrong.copyWith(color: colors.text),
                  ),
                  // The `平台 · 分区` line: the platform stays a label,
                  // the area opens the partition's own room list — said by
                  // the chevron and the hover's warmer ink.
                  if (area.isEmpty)
                    Text(
                      platform,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    )
                  else
                    DsTooltip(
                      message: t.room.areaHint,
                      child: DsPressable(
                        semanticLabel: t.room.areaEntry,
                        onPressed: () => unawaited(openRoomArea(context, ref, detail)),
                        builder: (context, states, _) => Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: DsSpace.s3,
                          children: [
                            Flexible(
                              child: Text(
                                where,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.caption.copyWith(
                                  color: states.contains(WidgetState.hovered) ? colors.text : colors.textMuted,
                                ),
                              ),
                            ),
                            DsIcon(
                              DsIcons.chevronRight,
                              size: 12,
                              color: states.contains(WidgetState.hovered) ? colors.text : colors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
