import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:pure_live/app/app.dart' show sitesProvider;
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
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
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s4),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(shape: BoxShape.circle, color: live ? colors.accent : colors.border),
            child: DsAvatar(
              initials: avatarInitials(name),
              image: avatar.isEmpty ? null : cachedImage(avatar, policy: ImageCachePolicies.avatar),
              size: DsSize.sm,
              semanticLabel: name,
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
                Text(
                  where,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
