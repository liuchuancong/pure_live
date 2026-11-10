import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_vod/live_vod.dart' show HuyaUploader;
import 'package:pure_live/app/app.dart' show browseSettingsProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/huya/controller/huya_video.dart';
import 'package:pure_live/modules/huya/widgets/huya_widgets.dart';
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart' show VodVideoCard, kVodCardInfoExtent;
import 'package:pure_live/shared/shared.dart';

/// The uploader page's surfaces, the way the station splits them.
enum _UploaderTab { home, videos, replays }

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
  final ScrollController _home = ScrollController();
  final ScrollController _videos = ScrollController();
  final ScrollController _replays = ScrollController();
  _UploaderTab _tab = _UploaderTab.home;

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
      setState(() => _tab = _UploaderTab.home);
      unawaited(ref.read(huyaUploaderProvider.notifier).open(widget.uid));
    }
  }

  @override
  void dispose() {
    _home.dispose();
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
    final videosLabel = uploader == null || uploader.videoCount <= 0
        ? t.huya.tabVideos
        : '${t.huya.tabVideos}(${uploader.videoCount})';
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
                  DsTab(value: _UploaderTab.home, label: Text(t.huya.profileHome)),
                  DsTab(value: _UploaderTab.videos, label: Text(videosLabel)),
                  DsTab(value: _UploaderTab.replays, label: Text(t.huya.tabReplays)),
                ],
              ),
            ),
            Expanded(
              child: switch (_tab) {
                _UploaderTab.home => _HomeTab(
                  scrollController: _home,
                  state: state,
                  onOpen: _openVideo,
                  onMoreVideos: () => _select(_UploaderTab.videos),
                  onRetry: () => unawaited(controller.refresh()),
                ),
                _UploaderTab.videos =>
                  uploader == null && state.error != null
                      ? HuyaLoadPanes(
                          loading: false,
                          error: state.error!.message,
                          onRetry: () => unawaited(controller.refresh()),
                          icon: DsIcons.circleUser,
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
                  videos: replay.videoRows,
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

/// The 主页 the station leads with: its 热门推荐 row over the 精彩视频 grid.
/// The videos here are the first page the owner page already asked for; 更多
/// walks to the whole 视频 list.
final class _HomeTab extends ConsumerWidget {
  const _HomeTab({
    required this.scrollController,
    required this.state,
    required this.onOpen,
    required this.onMoreVideos,
    required this.onRetry,
  });

  final ScrollController scrollController;
  final HuyaUploaderState state;
  final ValueChanged<String> onOpen;
  final VoidCallback onMoreVideos;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final uploader = state.uploader;
    if (uploader == null && state.error != null) {
      return HuyaLoadPanes(loading: false, error: state.error!.message, onRetry: onRetry, icon: DsIcons.circleUser);
    }
    if (uploader == null) {
      return const Center(child: DsSpinner());
    }
    final recommended = state.recommended;
    final videos = state.videos;
    final browse = ref.watch(browseSettingsProvider);
    Widget head(String title, {VoidCallback? more}) => Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.s12),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: theme.typography.title.copyWith(color: colors.text)),
          ),
          if (more != null)
            DsButton(variant: DsButtonVariant.secondary, size: DsSize.sm, onPressed: more, child: Text(t.huya.more)),
        ],
      ),
    );
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, DsSpace.s24),
      children: [
        if (recommended.isNotEmpty) ...[
          head(t.huya.hotRecommend),
          LayoutBuilder(
            builder: (context, constraints) {
              final content = constraints.hasBoundedWidth ? constraints.maxWidth : 0.0;
              if (content <= 0) return const SizedBox.shrink();
              final width = math.min(kBrowseCardMaxWidth, math.max(kBrowseCardMinWidth, content * 0.42));
              final height = width * 9 / 16 + kVodCardInfoExtent;
              return SizedBox(
                height: height,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: recommended.length,
                  separatorBuilder: (context, index) => const SizedBox(width: DsSpace.s12),
                  itemBuilder: (context, index) {
                    final video = recommended[index];
                    return SizedBox(
                      width: width,
                      child: VodVideoCard(video: video.asVideo(), onOpen: () => onOpen(video.id)),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: DsSpace.s24),
        ],
        head(t.huya.greatVideos, more: videos.isEmpty ? null : onMoreVideos),
        LayoutBuilder(
          builder: (context, constraints) {
            final content = constraints.hasBoundedWidth ? constraints.maxWidth : 0.0;
            if (content <= 0) return const SizedBox.shrink();
            final spacing = browse.crossSpacing;
            final columns = math.max(
              1,
              cappedColumnsForWidth(
                content,
                spacing: spacing,
                ceiling: browse.gridColumns,
                minWidth: kBrowseCardMinWidth,
              ),
            );
            final width = columnExtentForWidth(content, columns, spacing) - .01;
            final height = width * 9 / 16 + kVodCardInfoExtent;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final video in videos)
                  SizedBox(
                    width: width,
                    height: height,
                    child: VodVideoCard(video: video.asVideo(), onOpen: () => onOpen(video.id)),
                  ),
              ],
            );
          },
        ),
        if (videos.isEmpty && state.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: DsSpace.s24),
            child: Center(child: DsSpinner()),
          )
        else if (videos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.s24),
            child: Center(
              child: DsEmptyState(icon: const DsIcon(DsIcons.film), title: Text(t.common.empty)),
            ),
          ),
      ],
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
