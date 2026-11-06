import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/vod_card_settings.dart';
import 'package:pure_live/shared/shared.dart';

/// "12:34" or "1:02:03" for a video's length.
String vodDurationText(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '${duration.inMinutes}:$seconds';
}

/// A history row's moment, at the end of its title line: the clock alone under
/// a head that already names the day, the date with it once the list runs
/// across more than one day.
String vodWatchStamp(DateTime time, {required bool namedDay}) {
  String two(int value) => value.toString().padLeft(2, '0');
  final clock = '${two(time.hour)}:${two(time.minute)}';
  return namedDay ? clock : '${vodDateText(time)} $clock';
}

/// A posting time as `MM-DD`, or `YYYY-MM-DD` once the year differs.
String vodDateText(DateTime time, {DateTime? now}) {
  String two(int value) => value.toString().padLeft(2, '0');
  final today = now ?? DateTime.now();
  final date = '${two(time.month)}-${two(time.day)}';
  return time.year == today.year ? date : '${time.year}-$date';
}

/// The information area under a vod card's cover: the uploader's picture at
/// its start with the name and the uploader beside it, the same block the
/// live module's room card keeps — one measure for both stations' tiles.
const double kVodCardInfoExtent = 56;

/// The information area under a season card's poster: room for a two-line
/// title and the state line under it, held at a fixed height so the posters
/// of a row all end at the same line whatever the column width, and the
/// poster takes the height left.
const double kVodSeasonCardInfoExtent = 76;

/// The season tile's width over height — the measure every poster wall of the
/// station pages by, so a card draws its name block at
/// [kVodSeasonCardInfoExtent] and gives the poster the rest. The figure keeps
/// the poster itself near the station's 3:4 once the name block is paid for.
const double kVodSeasonTileAspect = 0.56;

/// One Bilibili archive as a card in a browse or search grid, drawn in the
/// live module's card language so the two stations read as one design: the
/// counts sit on the cover's foot as dark capsules, the length closes the
/// foot in the same shape, and beneath the cover the uploader's picture leads
/// a one-line title with the uploader under it. The whole card is one press
/// target. Which of those pieces appears is the card visibility setting's to
/// say; the title is not one of them.
final class VodVideoCard extends ConsumerWidget {
  /// The card for [video]; [onOpen] opens its page.
  const VodVideoCard({required this.video, this.onOpen, this.rank, super.key});

  /// The archive shown.
  final VodVideo video;

  /// Opens the archive; null leaves the card inert.
  final VoidCallback? onOpen;

  /// A 1-based ranking position, shown over the cover when this is a board.
  final int? rank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final visibility = ref.watch(vodCardSettingsProvider);
    final count = video.playCount;
    final plays = !visibility.shows(VodCardElement.plays) || count == null || count <= 0
        ? ''
        : AudienceFormat.format(count);
    final uploaderName = (video.uploader ?? '').trim();
    final uploader = visibility.shows(VodCardElement.uploader) ? uploaderName : '';
    final avatarUrl = (video.uploaderAvatar ?? '').trim();
    final danmaku = switch (video.danmakuCount) {
      final value? when value > 0 && visibility.shows(VodCardElement.danmaku) => AudienceFormat.format(value),
      _ => '',
    };
    final showsDuration = visibility.shows(VodCardElement.duration) && video.duration != null;
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.radii.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  vodCover(video, context),
                  // Darkens the cover's lower edge so the counts keep their
                  // contrast over a bright picture — the room cover's scrim.
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(decoration: BoxDecoration(gradient: kRoomCoverScrim)),
                    ),
                  ),
                  if (rank != null)
                    PositionedDirectional(
                      top: DsSpace.s8,
                      start: DsSpace.s8,
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
                  // The cover's corner ink, worn the way the live module's
                  // card wears it: the counts in dark capsules at the foot's
                  // start, the length closing the foot in its own capsule.
                  // Hidden pieces leave their slot, and with all three hidden
                  // the row is not drawn at all.
                  if (plays.isNotEmpty || danmaku.isNotEmpty || showsDuration)
                    PositionedDirectional(
                      start: DsSpace.s8,
                      end: DsSpace.s8,
                      bottom: DsSpace.s8,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: DsSpace.s6,
                              runSpacing: DsSpace.s3,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (plays.isNotEmpty) _CoverChip(icon: DsIcons.play, label: plays),
                                if (danmaku.isNotEmpty) _CoverChip(icon: DsIcons.captions, label: danmaku),
                              ],
                            ),
                          ),
                          if (showsDuration) _VodDurationBadge(duration: video.duration!),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // The information area, in the live card's shape: the uploader's
            // picture at its start, then the name and the uploader aligned
            // beside it, both beginning at the same edge.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                child: Row(
                  spacing: DsSpace.s8,
                  children: [
                    if (visibility.shows(VodCardElement.avatar))
                      DsAvatar(
                        initials: avatarInitials(uploaderName.isEmpty ? video.title : uploaderName),
                        image: avatarUrl.isEmpty ? null : cachedImage(avatarUrl, policy: ImageCachePolicies.avatar),
                        size: DsSize.md,
                        semanticLabel: uploaderName.isEmpty ? video.title : uploaderName,
                      ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: DsSpace.s3,
                        children: [
                          Text(
                            video.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.bodyStrong.copyWith(color: colors.text),
                          ),
                          if (uploader.isNotEmpty)
                            Text(
                              uploader,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.caption.copyWith(color: colors.textMuted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The cover, or the theme's stand-in.
  static Widget vodCover(VodVideo video, BuildContext context) {
    final fallback = CoverFallback(title: video.title, padding: const EdgeInsets.all(DsSpace.s8));
    final url = video.coverUrl;
    if (url == null || url.isEmpty) return fallback;
    return DsImage(
      image: cachedImage(url, policy: ImageCachePolicies.videoCover),
      aspectRatio: 16 / 9,
      semanticLabel: video.title,
      fallback: fallback,
    );
  }
}

/// One figure printed on a cover: a small glyph and its count in a dark
/// capsule, the shape the live module's cards use for the same corner.
final class _CoverChip extends StatelessWidget {
  const _CoverChip({required this.icon, required this.label});

  final DsIconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return RoomCoverChip(
      compact: true,
      icon: icon,
      text: label,
      maxWidth: 120,
      style: theme.typography.numeric(
        theme.typography.caption.copyWith(fontSize: 10, color: const Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// The archive's length in a dark capsule at a cover's foot's end — the
/// station's own duration mark, its digits tabular so the count holds its
/// width while it plays. The card and the row close their covers with the
/// same capsule.
final class _VodDurationBadge extends StatelessWidget {
  const _VodDurationBadge({required this.duration});

  /// The length shown.
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return RoomCoverChip(
      compact: true,
      text: vodDurationText(duration),
      style: theme.typography.numeric(
        theme.typography.caption.copyWith(fontSize: 10, color: const Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// The row's one meta line: the uploader — or the page's own line in its
/// place — opens it, then the play and danmaku figures with their glyphs, as
/// the station's own search row reads. One line with an ellipsis rather than
/// a fold: a narrow window shortens the line instead of letting it stripe.
final class _VodRowMeta extends StatelessWidget {
  const _VodRowMeta({required this.note, required this.plays, required this.danmaku});

  /// The line's opening words; empty leaves them out.
  final String note;

  /// The formatted play count; empty leaves it out.
  final String plays;

  /// The formatted danmaku count; empty leaves it out.
  final String danmaku;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final style = theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textMuted));
    const gap = WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: SizedBox(width: DsSpace.s12),
    );
    WidgetSpan figure(DsIconData icon, String label) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s3,
        children: [
          DsIcon(icon, size: theme.sizes.iconXs, color: colors.textSubtle),
          Text(label, style: style),
        ],
      ),
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (note.isNotEmpty) TextSpan(text: note),
          if (plays.isNotEmpty) ...[if (note.isNotEmpty) gap, figure(DsIcons.play, plays)],
          if (danmaku.isNotEmpty) ...[if (note.isNotEmpty || plays.isNotEmpty) gap, figure(DsIcons.captions, danmaku)],
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

/// One cinema title as a card, drawn the way the station's own poster wall
/// lays them out: the 3:4 poster carries one corner mark at its top-start —
/// the score in the accent's ink when there is one, otherwise the state in a
/// dark capsule — and beneath the poster the name on a fixed block with the
/// state line under it. A score on the poster pushes the state down to that
/// line, so the two never crowd one corner. Which of the pieces appear is the
/// card visibility setting's to say, the same table the archive card reads —
/// a title's name is not one of the pieces it can take away.
final class VodSeasonCard extends ConsumerWidget {
  /// The card for [season]; [onOpen] opens its page.
  const VodSeasonCard({required this.season, this.onOpen, super.key});

  /// The season shown.
  final VodSeason season;

  /// Opens the season; null leaves the card inert.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final visibility = ref.watch(vodCardSettingsProvider);
    final rating = visibility.shows(VodCardElement.seasonScore) ? (season.rating ?? '').trim() : '';
    final stateMark = visibility.shows(VodCardElement.seasonState) ? season.subtitle.trim() : '';
    // The score takes the corner whenever it exists; the state then reads off
    // the poster, from the line under the name. Without a score the state
    // keeps the corner it came from, and the line stays empty rather than
    // say the name twice.
    final showsScore = rating.isNotEmpty;
    final showsState = stateMark.isNotEmpty;
    final stateOnLine = showsScore && showsState;
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.radii.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The tile's height is a ratio of its width, so a name block of
            // its own content height would overflow a narrow column and float
            // in a wide one. The poster takes the height the fixed block
            // leaves instead.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover == null || cover.isEmpty)
                    fallback
                  else
                    DsImage(
                      image: cachedImage(cover, policy: ImageCachePolicies.videoCover),
                      aspectRatio: 3 / 4,
                      semanticLabel: season.title,
                      fallback: fallback,
                    ),
                  // The poster's one corner mark, at its top start: the score
                  // in the accent's ink, or the state in the capsule the
                  // archive's ink uses.
                  if (showsScore)
                    PositionedDirectional(
                      top: DsSpace.s6,
                      start: DsSpace.s6,
                      child: DsBadge(
                        label: Text(rating),
                        dot: false,
                        style: DsBadgeStyle(
                          height: 18,
                          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s6, vertical: DsSpace.s3),
                          background: colors.accent,
                          foreground: colors.onAccent,
                          borderRadius: BorderRadius.circular(theme.radii.control(18)),
                          textStyle: theme.typography.numeric(
                            theme.typography.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    )
                  else if (showsState)
                    PositionedDirectional(
                      top: DsSpace.s6,
                      start: DsSpace.s6,
                      child: RoomCoverChip(compact: true, text: stateMark),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: kVodSeasonCardInfoExtent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s6, DsSpace.s12, DsSpace.s8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s3,
                  children: [
                    Text(
                      season.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                    ),
                    if (stateOnLine)
                      Text(
                        stateMark,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One cinema season as the page opens with it: the poster at its own size and,
/// beside it, everything the wall's card had no room for — where the season
/// stands, its score and its crowd's figures, the episode on the picture and
/// the tags the source files it under — with the blurb underneath, whole.
///
/// The name is written once, here. The card it came from keeps the score in
/// its corner and the state on its one spare line, because that is all the
/// room a wall tile has; a detail head has the column, so the figures belong
/// in words.
final class VodSeasonHead extends StatelessWidget {
  /// The head for [season]; [episode] is the one the page plays, and
  /// [showDetails] is the station's own switch for the figures and the blurb.
  const VodSeasonHead({required this.season, this.episode, this.showDetails = true, super.key});

  /// The season shown.
  final VodSeasonDetail season;

  /// The episode the page is playing, when one is.
  final VodEpisode? episode;

  /// Whether the score, the counts and the blurb appear.
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final plays = season.viewCount;
    final danmaku = season.danmakuCount;
    final uploaded = season.publishedAt;
    // A film's state line is its release day (`2023年03月31日上映`), which
    // already says the year; a series' (`更新至第1278话`) does not, so only
    // then does the line carry it.
    final stateNamesYear = season.subtitle.contains(RegExp(r'\d{4}'));
    final facts = [
      if (season.subtitle.isNotEmpty) season.subtitle,
      if (showDetails && season.rating.isNotEmpty) '${t.vod.score} ${season.rating}',
      if (showDetails && plays != null && plays > 0) '${AudienceFormat.format(plays)} ${t.vod.views}',
      if (showDetails && danmaku != null && danmaku > 0) '${AudienceFormat.format(danmaku)} ${t.vod.danmaku}',
      if (showDetails && uploaded != null && !stateNamesYear) '${uploaded.year}',
    ];
    final tags = [if (season.area.isNotEmpty) season.area, ...season.styles];
    final current = episode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s12,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: DsSpace.s16,
          children: [
            // The poster at the size a detail page carries one, keeping the
            // source's own 3:4 so the wall and the page draw the same art.
            SizedBox(
              width: 104,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(theme.radii.card),
                child: AspectRatio(aspectRatio: 3 / 4, child: _seasonCover(season, context)),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: DsSpace.s6,
                children: [
                  Row(
                    spacing: DsSpace.s8,
                    children: [
                      Expanded(
                        child: Text(
                          season.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.heading.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                        ),
                      ),
                      if (season.followed) DsBadge(label: Text(t.vod.following), dot: false),
                    ],
                  ),
                  if (current != null)
                    Row(
                      spacing: DsSpace.s6,
                      children: [
                        Flexible(child: DsBadge(label: Text(current.index), dot: false)),
                        Expanded(
                          child: Text(
                            current.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.body.copyWith(color: colors.text),
                          ),
                        ),
                      ],
                    ),
                  if (facts.isNotEmpty)
                    Text(
                      facts.join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  if (tags.isNotEmpty)
                    Wrap(
                      spacing: DsSpace.s6,
                      runSpacing: DsSpace.s6,
                      children: [for (final tag in tags) DsBadge(label: Text(tag), dot: false)],
                    ),
                ],
              ),
            ),
          ],
        ),
        if (showDetails && season.evaluate.isNotEmpty) _VodSeasonBlurb(text: season.evaluate),
      ],
    );
  }

  /// The season's poster, or the theme's stand-in.
  static Widget _seasonCover(VodSeasonDetail season, BuildContext context) {
    final fallback = CoverFallback(title: season.title, padding: const EdgeInsets.all(DsSpace.s8));
    final url = season.coverUrl;
    if (url == null || url.isEmpty) return fallback;
    return DsImage(
      image: cachedImage(url, policy: ImageCachePolicies.videoCover),
      aspectRatio: 3 / 4,
      semanticLabel: season.title,
      fallback: fallback,
    );
  }
}

/// The season's blurb, folded to four lines until the viewer asks for the
/// rest — the switch the video page gives its own description, measured the
/// same way so it only appears when the words really run past the fold.
final class _VodSeasonBlurb extends StatefulWidget {
  const _VodSeasonBlurb({required this.text});

  final String text;

  @override
  State<_VodSeasonBlurb> createState() => _VodSeasonBlurbState();
}

final class _VodSeasonBlurbState extends State<_VodSeasonBlurb> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final style = DsTheme.of(context).typography.body.copyWith(color: colors.textMuted);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 4,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        if (!overflows) return Text(widget.text, style: style);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: DsSpace.s4,
          children: [
            Text(
              widget.text,
              maxLines: _expanded ? null : 4,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: style,
            ),
            DsButton(
              variant: DsButtonVariant.ghost,
              size: DsSize.sm,
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? t.vod.collapse : t.vod.expand),
            ),
          ],
        );
      },
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
            initials: avatarInitials(post.author),
            image: avatar == null || avatar.isEmpty ? null : cachedImage(avatar, policy: ImageCachePolicies.avatar),
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
                  child: DsImage(
                    image: cachedImage(cover, policy: ImageCachePolicies.videoCover),
                    aspectRatio: 16 / 9,
                    semanticLabel: post.author,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One user search hit as a row: the avatar, the name, the signature and the
/// figures under it. The station's user tab only presents the hit — there is
/// no space page behind it — so [onOpen] stays null there and the row reads
/// as plain text; a caller that does open on a press sets it and the row
/// turns into one press target with a chevron at its end.
final class VodUserRow extends StatelessWidget {
  /// The row for [user]; [onOpen] opens the user, when there is a place to
  /// open them at.
  const VodUserRow({required this.user, this.onOpen, super.key});

  /// The user shown.
  final VodUser user;

  /// Opens the user; null leaves the row inert, a display line.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    final avatar = user.avatar;
    final fans = user.fans;
    final videos = user.videoCount;
    return DsCard(
      onPressed: onOpen,
      semanticLabel: user.name,
      style: DsCardStyle(
        padding: const EdgeInsets.all(DsSpace.s12),
        hovered: onOpen == null ? null : DsCardStyle(background: colors.hover),
      ),
      child: Row(
        spacing: DsSpace.s12,
        children: [
          DsAvatar(
            initials: avatarInitials(user.name),
            image: avatar == null || avatar.isEmpty ? null : cachedImage(avatar, policy: ImageCachePolicies.userAvatar),
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
          // The chevron is the press's own signpost: a row that opens
          // nowhere points nowhere.
          if (onOpen != null) DsIcon(DsIcons.chevronRight, size: theme.sizes.iconSm, color: colors.textSubtle),
        ],
      ),
    );
  }
}

/// One archive as a full-width row, drawn the way the station's own search
/// lays its hits out: the fixed-width cover on the left with the length
/// closing its foot in a dark capsule — or the watched stripe when the row is
/// a way back to a half-finished archive — and on the right the title with
/// one meta line under it: the uploader, or the page's own line in its place
/// ([subtitle]), then the play and danmaku figures with their glyphs.
/// [stamp] sits at the end of the title line and says when the row's record
/// happened, for the lists that are read by time rather than by what they
/// hold. Which of the meta pieces appear is the card visibility setting's to
/// say, the same table the grid card reads.
final class VodVideoRow extends ConsumerWidget {
  /// The row for [video]; [onOpen] opens its page and [trailing] is the row's
  /// own action.
  const VodVideoRow({
    required this.video,
    this.onOpen,
    this.subtitle,
    this.progress,
    this.stamp,
    this.trailing,
    super.key,
  });

  /// The archive shown.
  final VodVideo video;

  /// Opens the archive; null leaves the row inert.
  final VoidCallback? onOpen;

  /// The line under the title, in the uploader's place: what this row is being
  /// read for.
  final String? subtitle;

  /// The watched fraction (0..1) along the cover's foot. A row with one leaves
  /// the length chip out — the same figure already stands in [subtitle].
  final double? progress;

  /// The row's moment at the end of its title line; empty or null leaves the
  /// title the whole width.
  final String? stamp;

  /// The row's action at its end: the way to drop the archive from the list
  /// it is being read out of.
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final visibility = ref.watch(vodCardSettingsProvider);
    final count = video.playCount;
    final plays = !visibility.shows(VodCardElement.plays) || count == null || count <= 0
        ? ''
        : AudienceFormat.format(count);
    final danmaku = switch (video.danmakuCount) {
      final value? when value > 0 && visibility.shows(VodCardElement.danmaku) => AudienceFormat.format(value),
      _ => '',
    };
    // A page's own line under the title is what that list is read for, so it
    // stays; only the uploader this row falls back to answers to the switch.
    final note = (subtitle ?? (visibility.shows(VodCardElement.uploader) ? video.uploader ?? '' : '')).trim();
    final length = visibility.shows(VodCardElement.duration) ? video.duration : null;
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
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(decoration: BoxDecoration(gradient: kRoomCoverScrim)),
                      ),
                    ),
                    // An archive the player stopped on carries its position at
                    // the cover's foot; the length then stays out of the ink,
                    // since the line under the title already gives it.
                    if (progress case final value?)
                      PositionedDirectional(
                        bottom: 0,
                        start: 0,
                        end: 0,
                        child: DsProgressBar(value: value, animate: false, style: const DsProgressBarStyle(height: 3)),
                      )
                    else if (length case final value?)
                      PositionedDirectional(
                        bottom: DsSpace.s4,
                        end: DsSpace.s4,
                        child: _VodDurationBadge(duration: value),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: DsSpace.s8,
                    children: [
                      Expanded(
                        child: Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                        ),
                      ),
                      if (stamp case final value? when value.isNotEmpty)
                        // The record's moment keeps its own digits in a line of
                        // words, the way the station's own history rows do.
                        Text(
                          value,
                          maxLines: 1,
                          softWrap: false,
                          style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                        ),
                    ],
                  ),
                  if (note.isNotEmpty || plays.isNotEmpty || danmaku.isNotEmpty)
                    _VodRowMeta(note: note, plays: plays, danmaku: danmaku),
                ],
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
