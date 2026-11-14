import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_sites/live_sites.dart' show DanmakuBlockList, LiveAnchorRole, MessageSender;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/room/chat/room_message_actions.dart' show blockRoomMessageSender;
import 'package:pure_live/modules/live/room/chat/user_level_badge.dart' show UserLevelBadge;
import 'package:pure_live/shared/shared.dart';

/// The small card behind a sender's name: who is talking, in the fields the
/// platform actually gave, with the two verbs a viewer reaches for — copy the
/// name, or stop hearing them.
///
/// There is deliberately no avatar in the chat list; the card is the one place
/// a face is worth its download, because the viewer asked for this person.
Future<void> showChatUserCard(BuildContext context, WidgetRef ref, MessageSender sender, String platform) async {
  final t = context.t;
  final name = sender.userName.trim();
  if (name.isEmpty) return;
  final avatar = (sender.avatarUrl ?? '').trim();
  final role = switch (sender.role) {
    LiveAnchorRole.anchor => t.room.roleAnchor,
    LiveAnchorRole.moderator => t.room.roleModerator,
    LiveAnchorRole.platform => t.room.rolePlatform,
    _ => '',
  };
  final fan = [sender.fanBadgeName.trim(), sender.fanBadgeLevel.trim()].where((part) => part.isNotEmpty).join(' ');
  final level = (sender.userLevel ?? '').trim();
  final levelNumber = int.tryParse(level) ?? 0;
  final site = ref.read(sitesProvider).getById(platform);
  final platformName = site == null ? platform : localizedSiteName(site);
  final facts = [
    if (role.isNotEmpty) role,
    if (fan.isNotEmpty) fan,
    if (platformName.isNotEmpty) platformName,
  ].join(' · ');
  await showAppDialog<void>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: Text(name),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s12,
        children: [
          Row(
            spacing: DsSpace.s12,
            children: [
              DsAvatar(
                image: avatar.isEmpty ? null : cachedImage(avatar, policy: ImageCachePolicies.userAvatar),
                initials: avatarInitials(name),
                toneIndex: DsAvatar.toneFor(name),
                semanticLabel: name,
                style: const DsAvatarStyle(diameter: 48),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s4,
                  children: [
                    Row(
                      spacing: DsSpace.s6,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DsTheme.of(context).typography.bodyStrong,
                          ),
                        ),
                        if (levelNumber > 0) UserLevelBadge(level: levelNumber),
                      ],
                    ),
                    if (facts.isNotEmpty)
                      Text(
                        facts,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DsTheme.of(context).typography.caption
                            .copyWith(color: DsTheme.colorsOf(context).textMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: name));
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
              showDsToast(context: context, title: t.room.copied);
            }
          },
          child: Text(t.room.copyName),
        ),
        if (!DanmakuBlockList.isMaskedName(name))
          DsButton(
            variant: DsButtonVariant.dangerSoft,
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await blockRoomMessageSender(context, ref, name);
            },
            child: Text(t.room.blockUser),
          ),
      ],
    ),
  );
}
