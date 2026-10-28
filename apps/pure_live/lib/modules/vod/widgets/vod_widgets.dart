import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// "12:34" or "1:02:03" for a video's length.
String vodDurationText(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '${duration.inMinutes}:$seconds';
}

/// A posting time as `MM-DD`, or `YYYY-MM-DD` once the year differs.
String vodDateText(DateTime time, {DateTime? now}) {
  String two(int value) => value.toString().padLeft(2, '0');
  final today = now ?? DateTime.now();
  final date = '${two(time.month)}-${two(time.day)}';
  return time.year == today.year ? date : '${time.year}-$date';
}

/// One Bilibili archive as a card in a browse or search grid.
///
/// The cover carries the length pill; beneath it the title, the uploader and
/// the play figure. The whole card is one press target.
final class VodVideoCard extends StatelessWidget {
  /// The card for [video]; [onOpen] opens its page.
  const VodVideoCard({required this.video, this.onOpen, this.rank, super.key});

  /// The archive shown.
  final VodVideo video;

  /// Opens the archive; null leaves the card inert.
  final VoidCallback? onOpen;

  /// A 1-based ranking position, shown over the cover when this is a board.
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final count = video.playCount;
    final plays = count == null || count <= 0 ? '' : AudienceFormat.format(count);
    return DsCard(
      onPressed: onOpen,
      semanticLabel: video.title,
      style: DsCardStyle(
        padding: EdgeInsets.zero,
        hovered: DsCardStyle(
          background: colors.hover,
          shadows: [DsShadow(color: colors.overlay, blur: DsSpace.s24, offset: const Offset(0, DsSpace.s8))],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s6,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(theme.radii.card)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  vodCover(video, context),
                  if (video.duration != null)
                    PositionedDirectional(
                      bottom: DsSpace.s6,
                      end: DsSpace.s6,
                      child: DsBadge(label: Text(vodDurationText(video.duration!)), dot: false),
                    ),
                  if (rank != null)
                    PositionedDirectional(
                      top: DsSpace.s6,
                      start: DsSpace.s6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s3),
                        decoration: DsBoxDecoration(
                          color: colors.accent,
                          borderRadius: BorderRadius.circular(theme.radii.control(22)),
                        ),
                        child: Text(
                          '$rank',
                          style: theme.typography.numeric(
                            theme.typography.caption.copyWith(color: colors.onAccent, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s4,
              children: [
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                ),
                Row(
                  spacing: DsSpace.s4,
                  children: [
                    if ((video.uploader ?? '').trim().isNotEmpty)
                      Flexible(
                        child: Text(
                          video.uploader!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.caption.copyWith(color: colors.textMuted),
                        ),
                      ),
                    const Spacer(),
                    if (plays.isNotEmpty)
                      Row(
                        spacing: DsSpace.s4,
                        children: [
                          DsIcon(DsIcons.eye, size: theme.sizes.iconXs, color: colors.textSubtle),
                          Text(
                            plays,
                            style: theme.typography.numeric(
                              theme.typography.caption.copyWith(color: colors.textSubtle),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: DsSpace.s6),
        ],
      ),
    );
  }

  /// The cover, or the theme's stand-in.
  static Widget vodCover(VodVideo video, BuildContext context) {
    final fallback = CoverFallback(title: video.title, padding: const EdgeInsets.all(DsSpace.s8));
    final url = video.coverUrl;
    if (url == null || url.isEmpty) return fallback;
    return DsImage(image: cachedImage(url), aspectRatio: 16 / 9, semanticLabel: video.title, fallback: fallback);
  }
}

/// One cinema title as a card: the poster, the title, the update line and the
/// score.
final class VodSeasonCard extends StatelessWidget {
  /// The card for [season]; [onOpen] opens its page.
  const VodSeasonCard({required this.season, this.onOpen, super.key});

  /// The season shown.
  final VodSeason season;

  /// Opens the season; null leaves the card inert.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final rating = season.rating;
    final fallback = CoverFallback(title: season.title, padding: const EdgeInsets.all(DsSpace.s8));
    final cover = season.coverUrl;
    return DsCard(
      onPressed: onOpen,
      semanticLabel: season.title,
      style: DsCardStyle(
        padding: EdgeInsets.zero,
        hovered: DsCardStyle(
          background: colors.hover,
          shadows: [DsShadow(color: colors.overlay, blur: DsSpace.s24, offset: const Offset(0, DsSpace.s8))],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s6,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(theme.radii.card)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover == null || cover.isEmpty)
                    fallback
                  else
                    DsImage(
                      image: cachedImage(cover),
                      aspectRatio: 3 / 4,
                      semanticLabel: season.title,
                      fallback: fallback,
                    ),
                  if (rating != null && rating.isNotEmpty)
                    PositionedDirectional(
                      bottom: DsSpace.s6,
                      end: DsSpace.s6,
                      child: DsBadge(label: Text(rating), dot: false),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s4,
              children: [
                Text(
                  season.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                ),
                if (season.subtitle.isNotEmpty)
                  Text(
                    season.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(height: DsSpace.s6),
        ],
      ),
    );
  }
}

/// One dynamic post as a full-width row: who posted it, when, the words, and
/// the archive it shares.
final class VodDynamicRow extends StatelessWidget {
  /// The row for [post]; [onOpen] opens the shared archive, when there is one.
  const VodDynamicRow({required this.post, this.onOpen, super.key});

  /// The post shown.
  final VodDynamic post;

  /// Opens the post's archive.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final avatar = post.avatar;
    final cover = post.coverUrl;
    final posted = post.publishedAt;
    return DsCard(
      onPressed: onOpen,
      semanticLabel: post.author,
      style: DsCardStyle(
        padding: const EdgeInsets.all(DsSpace.s12),
        hovered: DsCardStyle(background: colors.hover),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s12,
        children: [
          DsAvatar(
            initials: post.author,
            image: avatar == null || avatar.isEmpty ? null : cachedImage(avatar),
            size: DsSize.sm,
            toneIndex: DsAvatar.toneFor(post.author),
            semanticLabel: post.author,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s4,
              children: [
                Row(
                  spacing: DsSpace.s8,
                  children: [
                    Flexible(
                      child: Text(
                        post.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                      ),
                    ),
                    if (posted != null)
                      Text(
                        vodDateText(posted),
                        style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                      ),
                  ],
                ),
                if (post.text.isNotEmpty)
                  Text(
                    post.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.body.copyWith(color: colors.textMuted),
                  ),
              ],
            ),
          ),
          if (cover != null && cover.isNotEmpty)
            SizedBox(
              width: 112,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(theme.radii.control(72)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: DsImage(image: cachedImage(cover), aspectRatio: 16 / 9, semanticLabel: post.author),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One user search hit as a row: the avatar, the name, the signature and the
/// figures under it.
final class VodUserRow extends StatelessWidget {
  /// The row for [user].
  const VodUserRow({required this.user, super.key});

  /// The user shown.
  final VodUser user;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    final avatar = user.avatar;
    final fans = user.fans;
    final videos = user.videoCount;
    return DsCard(
      semanticLabel: user.name,
      style: const DsCardStyle(padding: EdgeInsets.all(DsSpace.s12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s12,
        children: [
          DsAvatar(
            initials: user.name,
            image: avatar == null || avatar.isEmpty ? null : cachedImage(avatar),
            size: DsSize.sm,
            toneIndex: DsAvatar.toneFor('${user.mid}'),
            semanticLabel: user.name,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s4,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                ),
                if (user.sign.isNotEmpty)
                  Text(
                    user.sign,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                  ),
                Wrap(
                  spacing: DsSpace.s16,
                  runSpacing: DsSpace.s4,
                  children: [
                    if (fans != null)
                      Text(
                        '${t.vod.fans} ${AudienceFormat.format(fans)}',
                        style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                      ),
                    if (videos != null)
                      Text(
                        '${t.vod.videoCount} ${AudienceFormat.format(videos)}',
                        style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One archive as a full-width row (the list layout of a browse feed).
final class VodVideoRow extends StatelessWidget {
  /// The row for [video]; [onOpen] opens its page.
  const VodVideoRow({required this.video, this.onOpen, super.key});

  /// The archive shown.
  final VodVideo video;

  /// Opens the archive; null leaves the row inert.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    final count = video.playCount;
    final plays = count == null || count <= 0 ? '' : AudienceFormat.format(count);
    return DsCard(
      onPressed: onOpen,
      semanticLabel: video.title,
      style: DsCardStyle(
        padding: const EdgeInsets.all(DsSpace.s8),
        hovered: DsCardStyle(background: colors.hover),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s12,
        children: [
          SizedBox(
            width: 148,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(theme.radii.control(84)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VodVideoCard.vodCover(video, context),
                    if (video.duration != null)
                      PositionedDirectional(
                        bottom: DsSpace.s4,
                        end: DsSpace.s4,
                        child: DsBadge(label: Text(vodDurationText(video.duration!)), dot: false),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: DsSpace.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: DsSpace.s4,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                  ),
                  if ((video.uploader ?? '').trim().isNotEmpty)
                    Text(
                      '${t.vod.up} · ${video.uploader}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  if (plays.isNotEmpty)
                    Row(
                      spacing: DsSpace.s4,
                      children: [
                        DsIcon(DsIcons.eye, size: theme.sizes.iconXs, color: colors.textSubtle),
                        Text(
                          plays,
                          style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
