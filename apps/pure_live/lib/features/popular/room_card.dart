import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// One recommended room as a card. The two designs — the grid tile and the
/// list row — are fixed; the saved appearance only decides which pieces of
/// information they draw.
final class RoomCard extends ConsumerWidget {
  /// Shows [room]; [listRow] draws the list layout's row instead of the
  /// grid's cover-on-top card.
  const RoomCard({required this.room, this.onOpen, this.listRow = false, super.key});

  /// The room shown.
  final LiveRoom room;

  /// Fired when the card is opened.
  final VoidCallback? onOpen;

  /// Whether this is the feed's list layout, not its grid.
  final bool listRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(roomCardAppearanceProvider);
    final visibility = appearance.visibility;
    final site = ref.read(sitesProvider).getById(room.ref.platform);
    final platformName = site == null ? room.ref.platform : localizedSiteName(site);
    final platformIcon = localizedSiteIcon(site, size: 12);
    final live = room.broadcast.isLiveNow;
    final replay = room.broadcast.isRecord;
    final title = room.content.title;
    final anchorName = (room.anchor?.name ?? '').trim();
    final avatarUrl = (room.anchor?.avatarUrl ?? '').trim();
    final figure = audienceFigureOf(room, ref.watch(audienceMetricProvider), policy: ref.watch(audiencePolicyProvider));
    final status = roomBroadcastText(context.t, room) ?? '';
    final radius = BorderRadius.circular(appearance.cornerRadius);
    if (listRow) {
      return _ListRow(
        title: title,
        anchorName: anchorName,
        avatarUrl: avatarUrl,
        platformName: platformName,
        status: status,
        replay: replay,
        figure: visibility.shows(RoomCardElement.audience) ? figure : null,
        visibility: visibility,
        radius: radius,
        onOpen: onOpen,
      );
    }
    return DsCard(
      onPressed: onOpen,
      style: DsCardStyle(padding: EdgeInsets.zero, borderRadius: radius),
      child: ClipRRect(
        borderRadius: radius,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    _CoverImage(url: room.content.coverUrl, title: title, radius: appearance.cornerRadius),
                    if (visibility.shows(RoomCardElement.replayBadge) && replay)
                      PositionedDirectional(
                        top: DsSpace.s8,
                        end: DsSpace.s8,
                        child: RoomCoverChip(
                          text: context.t.settings.roomCardReplay,
                          icon: DsIcons.history,
                          maxWidth: width * 0.35,
                        ),
                      ),
                    if (visibility.shows(RoomCardElement.coverTitle) ||
                        (visibility.shows(RoomCardElement.audience) && figure != null))
                      PositionedDirectional(
                        start: DsSpace.s8,
                        end: DsSpace.s8,
                        bottom: DsSpace.s8,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (visibility.shows(RoomCardElement.coverTitle))
                              Flexible(
                                child: RoomCoverChip(
                                  text: title,
                                  maxWidth: width * 0.55,
                                  style: DsTheme.of(context).typography.caption
                                      .copyWith(color: const Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
                                ),
                              ),
                            if (visibility.shows(RoomCardElement.audience) && figure != null) ...[
                              if (visibility.shows(RoomCardElement.coverTitle)) const Spacer(),
                              RoomCoverChip(
                                text: AudienceFormat.format(figure),
                                icon: DsIcons.flame,
                                maxWidth: width * 0.3,
                                style: DsTheme.of(context).typography.numeric(
                                  DsTheme.of(context).typography.caption
                                      .copyWith(color: const Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: _GridInfo(
                    title: title,
                    anchorName: anchorName,
                    avatarUrl: avatarUrl,
                    platformIcon: platformIcon,
                    status: status,
                    live: live,
                    visibility: visibility,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The grid card's information area: the title, then the avatar, platform,
/// anchor and broadcast state on one line. The cover carries the title chip
/// and the audience figure.
final class _GridInfo extends StatelessWidget {
  const _GridInfo({
    required this.title,
    required this.anchorName,
    required this.avatarUrl,
    required this.platformIcon,
    required this.status,
    required this.live,
    required this.visibility,
  });

  final String title;
  final String anchorName;
  final String avatarUrl;
  final Widget? platformIcon;
  final String status;
  final bool live;
  final RoomCardVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final showsAvatar = visibility.shows(RoomCardElement.avatar);
    final showsPlatform = visibility.shows(RoomCardElement.platformBadge);
    final showsAnchor = visibility.shows(RoomCardElement.anchorName) && anchorName.isNotEmpty;
    final showsStatus = visibility.shows(RoomCardElement.status) && status.isNotEmpty;
    final hasLine = showsAvatar || showsPlatform || showsAnchor || showsStatus;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: DsSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 2,
        children: [
          if (visibility.shows(RoomCardElement.title))
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.bodyStrong.copyWith(color: colors.text),
              ),
            ),
          if (hasLine)
            Row(
              spacing: 6,
              children: [
                if (showsAvatar)
                  DsAvatar(
                    initials: anchorName.isEmpty ? title : anchorName,
                    image: avatarUrl.isEmpty ? null : cachedImage(avatarUrl),
                    style: const DsAvatarStyle(diameter: 22),
                    semanticLabel: anchorName.isEmpty ? title : anchorName,
                  ),
                if (showsPlatform)
                  SizedBox.square(
                    dimension: 14,
                    child: Center(child: platformIcon ?? DsIcon(DsIcons.badge, size: 13, color: colors.textSubtle)),
                  ),
                if (showsAnchor)
                  Flexible(
                    child: Text(
                      anchorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ),
                if (showsStatus)
                  Flexible(
                    child: Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: live ? colors.accent : colors.textMuted),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The list row's fixed design: a round avatar, the title over a muted line
/// of platform, anchor and broadcast state, the audience figure and the
/// chevron. The row never carries a cover.
final class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.title,
    required this.anchorName,
    required this.avatarUrl,
    required this.platformName,
    required this.status,
    required this.replay,
    required this.figure,
    required this.visibility,
    required this.radius,
    required this.onOpen,
  });

  final String title;
  final String anchorName;
  final String avatarUrl;
  final String platformName;
  final String status;
  final bool replay;
  final int? figure;
  final RoomCardVisibility visibility;
  final BorderRadius radius;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final subtitle = [
      if (visibility.shows(RoomCardElement.platformBadge) && platformName.isNotEmpty) platformName,
      if (visibility.shows(RoomCardElement.anchorName) && anchorName.isNotEmpty) anchorName,
      if (visibility.shows(RoomCardElement.status) && status.isNotEmpty) status,
      if (visibility.shows(RoomCardElement.replayBadge) && replay) t.settings.roomCardReplay,
    ].join(' · ');
    return DsCard(
      onPressed: onOpen,
      style: DsCardStyle(padding: EdgeInsets.zero, borderRadius: radius),
      child: SizedBox(
        height: kRoomCardListDesignHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s8),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              if (visibility.shows(RoomCardElement.avatar))
                DsAvatar(
                  initials: anchorName.isEmpty ? title : anchorName,
                  image: avatarUrl.isEmpty ? null : cachedImage(avatarUrl),
                  size: DsSize.lg,
                  semanticLabel: anchorName.isEmpty ? title : anchorName,
                ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    if (visibility.shows(RoomCardElement.title))
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.bodyStrong.copyWith(color: colors.text),
                      ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                      ),
                  ],
                ),
              ),
              if (figure != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    DsIcon(DsIcons.flame, size: 14, color: colors.accent),
                    Text(
                      AudienceFormat.format(figure),
                      style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textMuted)),
                    ),
                  ],
                ),
              DsIcon(DsIcons.chevronRight, size: 16, color: colors.textSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

/// The grid card's cover, with its top corners following the card.
final class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url, required this.title, required this.radius});

  final String url;
  final String title;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DsImage(
      image: cachedImage(url),
      aspectRatio: 16 / 9,
      semanticLabel: title,
      fallback: _CoverFallback(title: title),
      style: DsImageStyle(borderRadius: BorderRadius.vertical(top: Radius.circular(radius))),
    );
  }
}

/// The cover's stand-in when the picture does not load: the room's title
/// over the surface color, so the card keeps its shape.
final class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return ColoredBox(
      color: colors.control,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DsTheme.of(context).typography.caption.copyWith(color: colors.textMuted),
          ),
        ),
      ),
    );
  }
}
