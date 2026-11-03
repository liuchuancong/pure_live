import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// The information area under a vod card's cover: room for a two-line title
/// and the uploader line, taller than the room card's one-line block.
const double kVodCardInfoExtent = 72;

/// The information area under a season card's poster: room for a two-line
/// title, held at a fixed height so the posters of a row all end at the same
/// line whatever the column width, and the poster takes the height left.
const double kVodSeasonCardInfoExtent = 60;

/// The season tile's width over height — the measure every poster wall of the
/// station pages by, so a card draws its name block at
/// [kVodSeasonCardInfoExtent] and gives the poster the rest.
const double kVodSeasonTileAspect = 0.62;

/// One Bilibili archive as a card in a browse or search grid, drawn the way
/// the station's own home lays them out: the counts sit on the cover as
/// white ink with a soft shadow — plays and danmaku at its foot's start,
/// the length at its foot's end — and beneath it the title and the uploader.
/// The whole card is one press target. Which of those four pieces appears is
/// the card visibility setting's to say; the title is not one of them.
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
    final uploader = visibility.shows(VodCardElement.uploader) ? (video.uploader ?? '').trim() : '';
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
                  // The station's own cover ink: the play and danmaku figures
                  // at the foot's start, the length at its end, each plain
                  // white with a soft shadow instead of a capsule. Hidden
                  // pieces leave their slot, and with all three hidden the row
                  // is not drawn at all.
                  if (plays.isNotEmpty || danmaku.isNotEmpty || showsDuration)
                    PositionedDirectional(
                      start: DsSpace.s8,
                      end: DsSpace.s8,
                      bottom: DsSpace.s6,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: DsSpace.s8,
                              runSpacing: DsSpace.s3,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (plays.isNotEmpty) _CoverInk(icon: DsIcons.play, label: plays),
                                if (danmaku.isNotEmpty) _CoverInk(icon: DsIcons.captions, label: danmaku),
                              ],
                            ),
                          ),
                          if (showsDuration)
                            Text(
                              vodDurationText(video.duration!),
                              style: theme.typography.numeric(
                                theme.typography.caption.copyWith(
                                  color: const Color(0xFFFFFFFF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                    ),
                    const Spacer(),
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
    return DsImage(image: cachedImage(url), aspectRatio: 16 / 9, semanticLabel: video.title, fallback: fallback);
  }
}

/// One figure printed on a cover: a small glyph and its count in white with
/// the station's soft drop shadow — no capsule behind it.
final class _CoverInk extends StatelessWidget {
  const _CoverInk({required this.icon, required this.label});

  final DsIconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    const shadow = [Shadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 2)];
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s3,
      children: [
        DsIcon(icon, size: theme.sizes.iconXs, color: const Color(0xFFFFFFFF)),
        Text(
          label,
          style: theme.typography.numeric(
            theme.typography.caption.copyWith(
              color: const Color(0xFFFFFFFF),
              shadows: shadow,
            ),
          ),
        ),
      ],
    );
  }
}

/// The station's home opens with one archive drawn at head size — the feed's
/// first pick, its cover at the head's start and its name, figures and verbs
/// at its end — instead of starting mid-grid like every other row.
///
/// The figures are read once, here in words: a big cover carries the counts
/// as ink only where the card below it has nowhere else to put them.
final class VodFeedHero extends StatelessWidget {
  /// The head for [video]; [onOpen] opens the archive, [onSave] collects it or
  /// drops it, and [eyebrow] is the feed's own name rather than an invented one.
  const VodFeedHero({
    required this.video,
    required this.eyebrow,
    required this.onOpen,
    required this.saved,
    required this.onSave,
    super.key,
  });

  /// The archive the feed puts first.
  final VodVideo video;

  /// The feed this head belongs to, in the station's own words.
  final String eyebrow;

  /// Opens the archive.
  final VoidCallback onOpen;

  /// Whether the archive already sits in the station's collection.
  final bool saved;

  /// Collects the archive, or drops it when it is collected.
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final uploader = (video.uploader ?? '').trim();
    final plays = video.playCount;
    final danmaku = video.danmakuCount;
    final facts = [
      if (uploader.isNotEmpty) uploader,
      if (plays != null && plays > 0) '${AudienceFormat.format(plays)} ${t.vod.views}',
      if (danmaku != null && danmaku > 0) '${AudienceFormat.format(danmaku)} ${t.vod.danmaku}',
      if (video.duration != null) vodDurationText(video.duration!),
    ].join(' · ');
    return LayoutBuilder(
      builder: (context, constraints) {
        // The cover keeps its own 16:9 at every width: a head that filled the
        // whole page would crop a picture the station drew for four thirds of
        // its height again. Its width, then, is what sets the head's height.
        final coverWidth = (constraints.maxWidth * 0.4).clamp(280.0, 440.0);
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: coverWidth,
                  child: AspectRatio(aspectRatio: 16 / 9, child: VodVideoCard.vodCover(video, context)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s12, DsSpace.s16, DsSpace.s12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: DsSpace.s4,
                      children: [
                        Text(eyebrow, style: theme.typography.overline.copyWith(color: colors.textSubtle)),
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.heading.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                        ),
                        if (facts.isNotEmpty)
                          Text(
                            facts,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.caption.copyWith(color: colors.textMuted),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: DsSpace.s4),
                          child: Wrap(
                            spacing: DsSpace.s8,
                            runSpacing: DsSpace.s8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              DsButton(
                                variant: DsButtonVariant.primary,
                                size: DsSize.sm,
                                leading: const DsIcon(DsIcons.play, size: 14),
                                onPressed: onOpen,
                                child: Text(t.vod.play),
                              ),
                              DsButton(
                                variant: DsButtonVariant.secondary,
                                size: DsSize.sm,
                                onPressed: onSave,
                                leading: DsIcon(
                                  DsIcons.heart,
                                  size: 14,
                                  color: saved ? colors.accent : colors.textMuted,
                                ),
                                child: Text(saved ? t.vod.savedVideo : t.vod.saveVideo),
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
      },
    );
  }
}

/// One cinema title as a card: the poster carrying its update state and score,
/// the name on a fixed line block beneath it. Which of the two corner marks
/// appear is the card visibility setting's to say, the same table the archive
/// card reads — a title's name is not one of the pieces it can take away.
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
    final rating = visibility.shows(VodCardElement.seasonScore) ? season.rating : null;
    final stateMark = visibility.shows(VodCardElement.seasonState) ? season.subtitle : '';
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
                      image: cachedImage(cover),
                      aspectRatio: 3 / 4,
                      semanticLabel: season.title,
                      fallback: fallback,
                    ),
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(decoration: BoxDecoration(gradient: kRoomCoverScrim)),
                    ),
                  ),
                  // The poster's own corners carry a title's state, so the
                  // block under it keeps to the name.
                  if (stateMark.isNotEmpty)
                    PositionedDirectional(
                      top: DsSpace.s8,
                      end: DsSpace.s8,
                      child: RoomCoverChip(compact: true, text: stateMark),
                    ),
                  if (rating != null && rating.isNotEmpty)
                    PositionedDirectional(
                      bottom: DsSpace.s8,
                      end: DsSpace.s8,
                      child: RoomCoverChip(
                        text: rating,
                        style: theme.typography.numeric(
                          theme.typography.caption.copyWith(
                            color: const Color(0xFFFFFFFF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: kVodSeasonCardInfoExtent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s6, DsSpace.s12, DsSpace.s8),
                child: Text(
                  season.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
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
/// The name is written once, here. The card it came from keeps the state and
/// the score on the poster because it has nowhere else to put them; a detail
/// head has the column, so the figures belong in words.
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
    return DsImage(image: cachedImage(url), aspectRatio: 3 / 4, semanticLabel: season.title, fallback: fallback);
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
            initials: avatarInitials(user.name),
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

/// One archive as a full-width row: the list layout of a browse feed, and the
/// shape every collected list of the station draws — 稍后再看, 收藏 and the
/// player's own history are one archive read three ways, so they take one row.
///
/// The cover carries the archive's ink: its length at the foot's end, or the
/// watched stripe when the row is a way back to a half-finished archive.
/// [subtitle] is the line under the title — the uploader for an archive found
/// in a feed, the position for one the player stopped on. [stamp] sits at the
/// end of the title line and says when the row's record happened, for the
/// lists that are read by time rather than by what they hold.
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
                        child: RoomCoverChip(
                          compact: true,
                          text: vodDurationText(value),
                          style: theme.typography.numeric(
                            theme.typography.caption.copyWith(
                              fontSize: 10,
                              color: const Color(0xFFFFFFFF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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
                  if (note.isNotEmpty)
                    Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  if (plays.isNotEmpty || danmaku.isNotEmpty)
                    // The figures share the line with a fixed 148 px cover, so
                    // a narrow window leaves them too little for one line —
                    // they fold under instead of painting stripes.
                    Wrap(
                      spacing: DsSpace.s4,
                      runSpacing: DsSpace.s3,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (plays.isNotEmpty) ...[
                          DsIcon(DsIcons.play, size: theme.sizes.iconXs, color: colors.textSubtle),
                          Text(
                            plays,
                            style: theme.typography.numeric(
                              theme.typography.caption.copyWith(color: colors.textSubtle),
                            ),
                          ),
                        ],
                        if (danmaku.isNotEmpty) ...[
                          DsIcon(DsIcons.captions, size: theme.sizes.iconXs, color: colors.textSubtle),
                          Text(
                            danmaku,
                            style: theme.typography.numeric(
                              theme.typography.caption.copyWith(color: colors.textSubtle),
                            ),
                          ),
                        ],
                      ],
                    ),
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
