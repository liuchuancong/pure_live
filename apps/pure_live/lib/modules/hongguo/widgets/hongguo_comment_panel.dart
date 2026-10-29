import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_social.dart'
    show hongguoCommentsProvider, hongguoPublicReviewsProvider;
import 'package:pure_live/modules/hongguo/official/hongguo_public_reviews.dart' show HongguoPublicReview;

/// One episode's comments and the series' reviews, behind the reference's two
/// tabs: the list reads the next page as the viewer reaches its bottom, and
/// the panel itself never scrolls — the page it is docked in does.
final class HongguoCommentPanel extends ConsumerStatefulWidget {
  /// The panel for [seriesId]'s episode [episodeVid].
  const HongguoCommentPanel({required this.seriesId, required this.episodeVid, this.showTitle = true, super.key});

  /// The series the panel reads.
  final String seriesId;

  /// The episode whose comments the panel lists; empty until one is known.
  final String episodeVid;

  /// Whether the panel prints its own heading; a host that already names the
  /// area passes false.
  final bool showTitle;

  @override
  ConsumerState<HongguoCommentPanel> createState() => _HongguoCommentPanelState();
}

final class _HongguoCommentPanelState extends ConsumerState<HongguoCommentPanel> {
  /// Whether the list shows this episode's comments; the other tab is the
  /// series' own reviews, read off the website.
  bool _episodeTab = true;

  /// The reference's 到底自动续读: the next page is asked as the viewer nears
  /// the bottom of whatever scrollable the panel sits in.
  bool _onScroll(ScrollUpdateNotification notification) {
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical || !_episodeTab) return false;
    if (metrics.maxScrollExtent - metrics.pixels > 120) return false;
    final state = ref.read(hongguoCommentsProvider);
    if (state.loading || !state.hasMore) return false;
    unawaited(ref.read(hongguoCommentsProvider.notifier).loadMore());
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final comments = ref.watch(hongguoCommentsProvider);
    final reviews = ref.watch(hongguoPublicReviewsProvider).data;
    final title = _episodeTab ? t.hongguo.comments : t.hongguo.reviews;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        if (widget.showTitle)
          Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: Text(title, style: theme.typography.title.copyWith(color: colors.text)),
              ),
              if (_episodeTab && comments.total > 0)
                DsBadge(label: Text('${comments.total}'), dot: false)
              else if (!_episodeTab && reviews != null && reviews.rating > 0)
                DsBadge(
                  label: Text(
                    reviews.ratingCount > 0
                        ? '${t.hongguo.rating(score: reviews.rating.toStringAsFixed(1))} · ${t.hongguo.ratingCount(count: reviews.ratingCount)}'
                        : t.hongguo.rating(score: reviews.rating.toStringAsFixed(1)),
                  ),
                  dot: false,
                ),
            ],
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DsSegmentedControl<bool>(
            value: _episodeTab,
            onChanged: (value) => setState(() => _episodeTab = value),
            segments: [
              DsSegment(value: true, label: Text(t.hongguo.reviewsEpisode)),
              DsSegment(value: false, label: Text(t.hongguo.reviewsSeries)),
            ],
          ),
        ),
        NotificationListener<ScrollUpdateNotification>(
          onNotification: _onScroll,
          child: _episodeTab
              ? _CommentsList(seriesId: widget.seriesId, episodeVid: widget.episodeVid)
              : _ReviewsList(seriesId: widget.seriesId, episodeVid: widget.episodeVid),
        ),
      ],
    );
  }
}

/// The episode's own comments, paged by the server cursor, read-only.
final class _CommentsList extends ConsumerStatefulWidget {
  const _CommentsList({required this.seriesId, required this.episodeVid});

  final String seriesId;
  final String episodeVid;

  @override
  ConsumerState<_CommentsList> createState() => _CommentsListState();
}

final class _CommentsListState extends ConsumerState<_CommentsList> {
  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(_CommentsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seriesId != widget.seriesId || oldWidget.episodeVid != widget.episodeVid) _open();
  }

  /// Reads the pair once per mount or episode change — never from `build`,
  /// where every rebuild would ask again.
  void _open() {
    final episode = widget.episodeVid;
    if (!RegExp(r'^[0-9]{6,30}$').hasMatch(episode)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(hongguoCommentsProvider.notifier).open(widget.seriesId, episode));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final state = ref.watch(hongguoCommentsProvider);
    final episode = widget.episodeVid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        if (state.loading && state.items.isEmpty) const Center(child: DsSpinner()),
        if (state.error != null && state.items.isEmpty)
          Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: Text(state.error!, style: theme.typography.caption.copyWith(color: colors.textMuted)),
              ),
              DsButton(
                size: DsSize.sm,
                variant: DsButtonVariant.ghost,
                onPressed: () => unawaited(ref.read(hongguoCommentsProvider.notifier).retry()),
                child: Text(t.common.retry),
              ),
            ],
          ),
        if (!state.loading && state.items.isEmpty && state.error == null && episode.isNotEmpty)
          Text(t.hongguo.commentsEmpty, style: theme.typography.caption.copyWith(color: colors.textMuted)),
        for (final comment in state.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s8,
              children: [
                DsAvatar(
                  initials: comment.author.isEmpty ? 'HG' : comment.author,
                  size: DsSize.xs,
                  toneIndex: DsAvatar.toneFor(comment.id),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: DsSpace.s3,
                    children: [
                      Row(
                        spacing: DsSpace.s8,
                        children: [
                          Expanded(
                            child: Text(
                              comment.author.isEmpty ? '红果用户' : comment.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.caption.copyWith(color: colors.textMuted),
                            ),
                          ),
                          DsIcon(DsIcons.heart, size: theme.sizes.iconXs, color: colors.textSubtle),
                          Text(
                            '${comment.likes}',
                            style: theme.typography.numeric(
                              theme.typography.caption.copyWith(color: colors.textSubtle),
                            ),
                          ),
                        ],
                      ),
                      Text(comment.content, style: theme.typography.body.copyWith(color: colors.text)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (state.hasMore && state.loading) const Center(child: DsSpinner(style: DsSpinnerStyle(size: 20))),
      ],
    );
  }
}

/// The website's public reviews — this episode's, or the series' own, per the
/// tab. No account credential goes with the ask.
final class _ReviewsList extends ConsumerStatefulWidget {
  const _ReviewsList({required this.seriesId, required this.episodeVid});

  final String seriesId;
  final String episodeVid;

  @override
  ConsumerState<_ReviewsList> createState() => _ReviewsListState();
}

final class _ReviewsListState extends ConsumerState<_ReviewsList> {
  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(_ReviewsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seriesId != widget.seriesId || oldWidget.episodeVid != widget.episodeVid) _open();
  }

  /// Reads the pair once per mount or episode change; `build` never asks.
  void _open() {
    final episode = widget.episodeVid;
    if (!RegExp(r'^[0-9]{6,30}$').hasMatch(episode)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(hongguoPublicReviewsProvider.notifier).open(widget.seriesId, episode));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final state = ref.watch(hongguoPublicReviewsProvider);
    final data = state.data;
    final reviews = data?.series.items ?? const <HongguoPublicReview>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        if (state.loading && data == null) const Center(child: DsSpinner()),
        if (state.error != null && data == null)
          Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: Text(state.error!, style: theme.typography.caption.copyWith(color: colors.textMuted)),
              ),
              DsButton(
                size: DsSize.sm,
                variant: DsButtonVariant.ghost,
                onPressed: () => unawaited(ref.read(hongguoPublicReviewsProvider.notifier).retry()),
                child: Text(t.common.retry),
              ),
            ],
          ),
        if (data != null && reviews.isEmpty)
          Text(t.hongguo.reviewsEmpty, style: theme.typography.caption.copyWith(color: colors.textMuted)),
        for (final review in reviews)
          DsCard(
            style: const DsCardStyle(padding: EdgeInsets.all(DsSpace.s12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s12,
              children: [
                DsAvatar(
                  initials: review.author.isEmpty ? 'HG' : review.author,
                  size: DsSize.sm,
                  toneIndex: DsAvatar.toneFor(review.id),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: DsSpace.s4,
                    children: [
                      Row(
                        spacing: DsSpace.s8,
                        children: [
                          Expanded(
                            child: Text(
                              review.author.isEmpty ? '红果用户' : review.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.caption.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                            ),
                          ),
                          if (review.rating > 0)
                            Text(
                              review.rating.toStringAsFixed(1),
                              style: theme.typography.numeric(
                                theme.typography.caption.copyWith(color: colors.textSubtle),
                              ),
                            ),
                          DsIcon(DsIcons.heart, size: theme.sizes.iconXs, color: colors.textSubtle),
                          Text(
                            '${review.likes}',
                            style: theme.typography.numeric(
                              theme.typography.caption.copyWith(color: colors.textSubtle),
                            ),
                          ),
                        ],
                      ),
                      Text(review.content, style: theme.typography.body.copyWith(color: colors.text)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
