import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_vod/live_vod.dart' show HuyaUploader, HuyaVideo;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/huya/controller/huya_video.dart';
import 'package:pure_live/modules/huya/widgets/huya_widgets.dart';
import 'package:pure_live/shared/shared.dart';

/// The uploader page's two lists, the way the station splits them.
enum _UploaderTab {
  videos,
  replays,
}

/// One uploader's public page: who they are, the videos they posted and the
/// broadcasts they recorded, each paged by scroll.
final class HuyaUploaderPage extends ConsumerStatefulWidget {
  /// The page for [uid].
  const HuyaUploaderPage({required this.uid, super.key});

  /// The station's uploader id.
  final String uid;

  @override
  ConsumerState<HuyaUploaderPage> createState() => _HuyaUploaderPageState();
}

final class _HuyaUploaderPageState extends ConsumerState<HuyaUploaderPage> {
  final ScrollController _videos = ScrollController();
  final ScrollController _replays = ScrollController();
  _UploaderTab _tab = _UploaderTab.videos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(huyaUploaderProvider.notifier).open(widget.uid));
    });
  }

  @override
  void didUpdateWidget(HuyaUploaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.uid != oldWidget.uid) {
      setState(() => _tab = _UploaderTab.videos);
      unawaited(ref.read(huyaUploaderProvider.notifier).open(widget.uid));
    }
  }

  @override
  void dispose() {
    _videos.dispose();
    _replays.dispose();
    super.dispose();
  }

  void _openVideo(String id) {
    if (id.isEmpty) return;
    unawaited(context.push('/huya/$id'));
  }

  void _select(_UploaderTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    if (tab == _UploaderTab.replays) {
      unawaited(ref.read(huyaReplayProvider.notifier).open(widget.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final state = ref.watch(huyaUploaderProvider);
    final controller = ref.read(huyaUploaderProvider.notifier);
    final replay = ref.watch(huyaReplayProvider);
    final replayController = ref.read(huyaReplayProvider.notifier);
    final uploader = state.uploader;
    return PageSurface(
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(title: uploader?.name ?? t.common.moduleHuya),
            if (uploader != null)
              Padding(
                padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, DsSpace.s8),
                child: _Head(uploader: uploader),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
              child: DsTabs<_UploaderTab>(
                value: _tab,
                onChanged: _select,
                tabs: [
                  DsTab(value: _UploaderTab.videos, label: Text(t.huya.tabVideos)),
                  DsTab(value: _UploaderTab.replays, label: Text(t.huya.tabReplays)),
                ],
              ),
            ),
            Expanded(
              child: switch (_tab) {
                _UploaderTab.videos => uploader == null && state.error != null
                    ? Center(
                        child: DsEmptyState(
                          icon: const DsIcon(DsIcons.circleUser),
                          title: Text(t.huya.errorTitle),
                          description: Text(state.error!.message),
                          actions: [
                            DsButton(
                              variant: DsButtonVariant.secondary,
                              onPressed: () => unawaited(controller.refresh()),
                              child: Text(t.common.retry),
                            ),
                          ],
                        ),
                      )
                    : HuyaVideoGrid(
                        scrollController: _videos,
                        videos: state.videos,
                        loading: state.loading,
                        hasMore: state.hasMore,
                        onLoadMore: controller.loadMore,
                        onOpen: _openVideo,
                        error: state.error?.message,
                        onRetry: () => unawaited(controller.refresh()),
                        onRefresh: controller.refresh,
                      ),
                _UploaderTab.replays => HuyaVideoGrid(
                  scrollController: _replays,
                  videos: [
                    for (final record in replay.videos)
                      HuyaVideo(
                        id: record.id,
                        title: record.title,
                        cover: record.cover,
                        duration: record.duration,
                        uploaderId: record.authorId,
                        uploaderName: record.authorName,
                      ),
                  ],
                  loading: replay.loading,
                  hasMore: replay.hasMore,
                  onLoadMore: replayController.loadMore,
                  onOpen: _openVideo,
                  error: replay.error?.message,
                  onRetry: () => unawaited(replayController.open(widget.uid)),
                  onRefresh: () => replayController.open(widget.uid),
                  emptyTitle: t.huya.replayEmpty,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The uploader's own block: the picture, the name, what they say about
/// themselves and the counts the station prints.
final class _Head extends StatelessWidget {
  const _Head({required this.uploader});

  final HuyaUploader uploader;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final lines = [
      if (uploader.videoCount > 0) '${AudienceFormat.format(uploader.videoCount)} ${t.huya.videoCount}',
      if (uploader.playCount > 0) '${AudienceFormat.format(uploader.playCount)} ${t.huya.views}',
      if (uploader.subscriberCount > 0) '${AudienceFormat.format(uploader.subscriberCount)} ${t.huya.fans}',
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s12,
      children: [
        DsAvatar(
          initials: avatarInitials(uploader.name.isEmpty ? uploader.id : uploader.name),
          image: uploader.avatar.isEmpty ? null : cachedImage(uploader.avatar, policy: ImageCachePolicies.avatar),
          size: DsSize.lg,
          semanticLabel: uploader.name,
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
                      uploader.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.title.copyWith(color: colors.text),
                    ),
                  ),
                  if (uploader.isLiving) DsBadge(label: Text(t.huya.live), status: DsStatus.success),
                ],
              ),
              if (uploader.intro.isNotEmpty)
                Text(
                  uploader.intro,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
              if (lines.isNotEmpty)
                Text(lines.join(' · '), style: theme.typography.caption.copyWith(color: colors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}
