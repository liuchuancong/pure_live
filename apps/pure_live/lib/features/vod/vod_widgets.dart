import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/images/app_image_cache.dart';
import 'package:pure_live/shared/utils/audience_format.dart' show AudienceFormat;

/// "12:34" or "1:02:03" for a video's length.
String vodDurationText(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '${duration.inMinutes}:$seconds';
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
    return DsPressable(
      onPressed: onOpen,
      semanticLabel: video.title,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return AnimatedContainer(
          duration: theme.motion.toneDuration,
          decoration: DsBoxDecoration(
            color: hovered ? colors.hover : colors.surface,
            borderRadius: BorderRadius.circular(theme.radii.card),
            shadows: hovered
                ? [DsShadow(color: colors.overlay, blur: DsSpace.s24, offset: const Offset(0, DsSpace.s8))]
                : theme.shadows.surface,
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
      },
    );
  }

  /// The cover, or the theme's stand-in.
  static Widget vodCover(VodVideo video, BuildContext context) {
    final fallback = _CoverFallback(title: video.title);
    final url = video.coverUrl;
    if (url == null || url.isEmpty) return fallback;
    return DsImage(image: cachedImage(url), aspectRatio: 16 / 9, semanticLabel: video.title, fallback: fallback);
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
    return DsPressable(
      onPressed: onOpen,
      semanticLabel: video.title,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return AnimatedContainer(
          duration: theme.motion.toneDuration,
          padding: const EdgeInsets.all(DsSpace.s8),
          decoration: DsBoxDecoration(
            color: hovered ? colors.hover : colors.surface,
            borderRadius: BorderRadius.circular(theme.radii.card),
            shadows: theme.shadows.surface,
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
                              style: theme.typography.numeric(
                                theme.typography.caption.copyWith(color: colors.textSubtle),
                              ),
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
      },
    );
  }
}

/// The cover's stand-in when the picture is missing.
final class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return ColoredBox(
      color: colors.control,
      child: Padding(
        padding: const EdgeInsets.all(DsSpace.s8),
        child: Align(
          alignment: AlignmentDirectional.bottomStart,
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
