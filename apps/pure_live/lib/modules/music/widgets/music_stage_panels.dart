import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_comments.dart' show MusicComment, musicCommentsProvider;
import 'package:pure_live/modules/music/controller/music_library.dart' show musicRecentProvider;
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/widgets/music_lyric_panel.dart';
import 'package:pure_live/modules/music/widgets/music_queue_panel.dart' show MusicQueuePanel;
import 'package:pure_live/modules/music/widgets/music_widgets.dart';
import 'package:pure_live/shared/shared.dart' show avatarInitials, cachedImage;

/// The player's side panels: lyrics, the current song's comments, the queue
/// and the recent list, behind one row of tabs. The wide player keeps them
/// beside the stage; a phone summons the same panel as a sheet, so the two
/// layouts share this one widget rather than a copy each.
/// The panel beside the stage: lyrics and the queue behind one pair of
/// tabs, so neither pushes the other off the page.
final class MusicStagePanels extends ConsumerStatefulWidget {
  /// The panel row itself; the host decides where it lives.
  const MusicStagePanels({super.key});

  @override
  ConsumerState<MusicStagePanels> createState() => MusicStagePanelsState();
}

final class MusicStagePanelsState extends ConsumerState<MusicStagePanels> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Center(
          child: DsTabs<int>(
            value: _tab,
            onChanged: (value) => setState(() => _tab = value),
            style: kMusicFeedTabsStyle,
            tabs: [
              DsTab<int>(value: 0, label: Text(t.music.lyrics)),
              DsTab<int>(value: 1, label: Text(t.music.queueTitle)),
              DsTab<int>(value: 2, label: Text(t.music.comments)),
              DsTab<int>(value: 3, label: Text(t.music.mineRecent)),
            ],
            semanticLabel: t.music.lyrics,
          ),
        ),
        Expanded(
          child: switch (_tab) {
            0 => const MusicLyricsPanel(),
            1 => const MusicQueuePanel(),
            2 => const _CommentsTab(),
            _ => const _RecentPanel(),
          },
        ),
      ],
    );
  }
}

/// The current song's comments in the panel; nothing when nothing plays.
final class _CommentsTab extends ConsumerWidget {
  const _CommentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(musicPlayerProvider.select((state) => state.track));
    if (track == null) return const SizedBox.shrink();
    return _CommentsPanel(track: track);
  }
}

/// The songs played lately, alone in the panel — the reference stage's
/// 最近播放 tab, each row stepping back into its own play.
final class _RecentPanel extends ConsumerWidget {
  const _RecentPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final recent = ref.watch(musicRecentProvider);
    final recentController = ref.read(musicRecentProvider.notifier);
    final player = ref.read(musicPlayerProvider.notifier);
    final playingId = ref.watch(musicPlayerProvider.select((state) => state.track?.id));
    return DsSurface(
      decoration: DsBoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
      padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s12, DsSpace.s4, DsSpace.s4),
      child: recent.isEmpty
          ? Center(
              child: DsEmptyState(icon: const DsIcon(DsIcons.clock), title: Text(t.music.recentEmpty)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s8,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: DsSpace.s8),
                  child: Row(
                    spacing: DsSpace.s4,
                    children: [
                      Expanded(
                        child: Text(
                          '${t.music.mineRecent} · ${t.music.songsCount(count: recent.length)}',
                          style: theme.typography.caption.copyWith(color: colors.textSubtle),
                        ),
                      ),
                      DsButton.icon(
                        variant: DsButtonVariant.ghost,
                        size: DsSize.sm,
                        semanticLabel: t.music.clearRecent,
                        onPressed: () => unawaited(recentController.clear()),
                        icon: const DsIcon(DsIcons.trash2, size: 16),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      DsListSection(
                        children: [
                          for (final (index, song) in recent.indexed)
                            DsListRow(
                              leading: MusicArtwork(track: song),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.body.copyWith(
                                  color: song.id == playingId ? colors.accent : colors.text,
                                  fontWeight: song.id == playingId ? FontWeight.w600 : null,
                                ),
                              ),
                              description: song.artist.isEmpty
                                  ? null
                                  : Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: DsSpace.s4,
                                children: [
                                  if (song.id == playingId) DsIcon(DsIcons.audioLines, size: 14, color: colors.accent),
                                  if (song.duration case final length?)
                                    Text(
                                      musicDurationText(length),
                                      style: theme.typography.numeric(
                                        theme.typography.caption.copyWith(color: colors.textSubtle),
                                      ),
                                    ),
                                ],
                              ),
                              onPressed: () => unawaited(player.playAll(recent, index: index)),
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

/// One song's comments, inside the player's side panel: the hot tab first,
/// then the newest, with the paging the reference offers. The panel fills
/// whatever room it is given; the dialog wraps it at a fixed height.
final class _CommentsPanel extends ConsumerStatefulWidget {
  const _CommentsPanel({required this.track});

  final audio.MusicTrack track;

  @override
  ConsumerState<_CommentsPanel> createState() => _CommentsPanelState();
}

final class _CommentsPanelState extends ConsumerState<_CommentsPanel> {
  bool _hot = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(musicCommentsProvider.notifier).load(widget.track, hot: _hot));
    });
  }

  @override
  void didUpdateWidget(_CommentsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another song on air means another comment thread.
    if (oldWidget.track.id != widget.track.id || oldWidget.track.sourceId != widget.track.sourceId) {
      unawaited(ref.read(musicCommentsProvider.notifier).load(widget.track, hot: _hot));
    }
  }

  void _selectTab(bool hot) {
    if (_hot == hot) return;
    setState(() => _hot = hot);
    unawaited(ref.read(musicCommentsProvider.notifier).load(widget.track, hot: hot));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final state = ref.watch(musicCommentsProvider);
    final comments = state.comments;
    final controller = ref.read(musicCommentsProvider.notifier);
    final hasTail = state.hasMore || state.error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Row(
          children: [
            DsSegmentedControl<bool>(
              value: _hot,
              onChanged: _selectTab,
              segments: [
                DsSegment(value: true, label: Text(t.music.commentsHot)),
                DsSegment(value: false, label: Text(t.music.commentsNew)),
              ],
            ),
            const Spacer(),
            if (comments.isNotEmpty)
              Text(
                t.music.commentsCount(count: comments.length),
                style: theme.typography.caption.copyWith(color: colors.textSubtle),
              ),
          ],
        ),
        Expanded(
          child: state.loading && comments.isEmpty
              ? const Center(child: DsSpinner())
              : state.error != null && comments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: DsSpace.s8,
                    children: [
                      Text(
                        t.music.commentsFailed(error: state.error!),
                        textAlign: TextAlign.center,
                        style: theme.typography.caption.copyWith(color: colors.danger.text),
                      ),
                      DsButton(
                        variant: DsButtonVariant.secondary,
                        size: DsSize.sm,
                        onPressed: () => unawaited(controller.retry()),
                        child: Text(t.common.retry),
                      ),
                    ],
                  ),
                )
              : comments.isEmpty
              ? Center(
                  child: Text(t.music.commentsEmpty, style: theme.typography.body.copyWith(color: colors.textMuted)),
                )
              : ListView.builder(
                  itemCount: comments.length + (hasTail ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < comments.length) return _CommentTile(comment: comments[index]);
                    if (state.loading) {
                      return const Padding(
                        padding: EdgeInsets.all(DsSpace.s12),
                        child: Center(child: DsSpinner()),
                      );
                    }
                    if (state.error != null) {
                      return Padding(
                        padding: const EdgeInsets.all(DsSpace.s12),
                        child: Center(
                          child: DsButton(
                            variant: DsButtonVariant.secondary,
                            size: DsSize.sm,
                            onPressed: () => unawaited(controller.retry()),
                            child: Text(t.common.retry),
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.all(DsSpace.s12),
                      child: Center(
                        child: DsButton(
                          variant: DsButtonVariant.secondary,
                          size: DsSize.sm,
                          onPressed: () => unawaited(controller.loadMore()),
                          child: Text(t.music.loadMore),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// The same thread in a dialog, from the stage's 评论 pill.
final class MusicCommentsDialog extends StatelessWidget {
  /// The dialog for [track]'s thread.
  const MusicCommentsDialog({required this.track, super.key});

  final audio.MusicTrack track;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsDialog(
      title: Text(t.music.comments),
      icon: const DsIcon(DsIcons.messageCircle),
      description: SizedBox(height: 360, child: _CommentsPanel(track: track)),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.close),
        ),
      ],
    );
  }
}

/// A comment's moment, in the local wall clock.
String _commentTime(DateTime? time) {
  if (time == null) return '';
  final local = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

/// One comment row inside [_CommentsPanel].
final class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final MusicComment comment;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final avatar = comment.avatar;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s8, horizontal: DsSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s8,
        children: [
          DsAvatar(
            initials: avatarInitials(comment.userName),
            image: avatar == null ? null : cachedImage(avatar),
            size: DsSize.md,
            semanticLabel: comment.userName,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s3,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textSubtle),
                      ),
                    ),
                    if (comment.likedCount > 0) ...[
                      DsIcon(DsIcons.heart, size: 12, color: colors.textSubtle),
                      Text('${comment.likedCount}', style: theme.typography.caption.copyWith(color: colors.textSubtle)),
                    ],
                  ],
                ),
                Text(
                  comment.text,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(color: colors.text),
                ),
                if (comment.replies.isNotEmpty)
                  Text(
                    t.music.commentsReplies(count: comment.replies.length),
                    style: theme.typography.caption.copyWith(color: colors.accent),
                  ),
                if (comment.time != null)
                  Text(_commentTime(comment.time), style: theme.typography.caption.copyWith(color: colors.textSubtle)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
