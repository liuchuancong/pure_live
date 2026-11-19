import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_sites/live_sites.dart' show SiteIds;
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/vod_controller.dart';
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart'
    show VodVideoCard, VodVideoRow, kVodCardInfoExtent, kVodRowExtent;
import 'package:pure_live/shared/shared.dart';

/// One UP主's space page: who they are over the videos they have published —
/// the same identity head the Huya uploader's page wears, over the same dual
/// feed the station's own lists speak — row cards in the viewer's list
/// layout, cover cards otherwise, paged by scroll.
final class VodUploaderPage extends ConsumerStatefulWidget {
  /// The page for [mid].
  const VodUploaderPage({required this.mid, super.key});

  /// The uploader's numeric mid.
  final String mid;

  @override
  ConsumerState<VodUploaderPage> createState() => _VodUploaderPageState();
}

final class _VodUploaderPageState extends ConsumerState<VodUploaderPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(vodUploaderProvider.notifier).open(widget.mid));
    });
  }

  @override
  void didUpdateWidget(VodUploaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mid != oldWidget.mid) {
      unawaited(ref.read(vodUploaderProvider.notifier).open(widget.mid));
    }
  }

  void _openVideo(VodVideo video) {
    final bvid = video.bvid ?? video.id;
    if (bvid.isEmpty) return;
    unawaited(context.push('/vod/$bvid'));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final settings = ref.watch(browseSettingsProvider);
    final layout = ref.watch(browseLayoutProvider);
    final state = ref.watch(vodUploaderProvider);
    final controller = ref.read(vodUploaderProvider.notifier);
    final sites = ref.watch(sitesProvider).all.where((site) => site.manifest.id == SiteIds.bilibili);
    final platform = sites.isEmpty ? t.common.moduleVod : localizedSiteName(sites.first);
    final name = state.videos.isEmpty ? null : state.videos.first.uploader;
    final avatar = state.videos.isEmpty ? null : state.videos.first.uploaderAvatar;
    final error = switch (state.error) {
      VodFailure(:final message) => message,
      final Object? other => other?.toString(),
    };
    final loading = state.videos.isEmpty && state.loading;
    return PageSurface(
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(title: (name?.trim().isEmpty ?? true) ? t.common.moduleVod : name!),
            if (loading)
              const Expanded(child: _SpaceSkeleton())
            else ...[
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  LiveWindow.pageInset(MediaQuery.sizeOf(context).width),
                  DsSpace.s8,
                  DsSpace.s16,
                  0,
                ),
                child: _Head(name: name ?? t.common.moduleVod, avatar: avatar, total: state.total, platform: platform),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s16, DsSpace.s16, DsSpace.s16, DsSpace.s4),
                child: SectionHeader(title: t.vod.uploads, count: state.total),
              ),
              Expanded(
                child: PagedCardGrid<VodVideo>(
                  items: state.videos,
                  layout: layout,
                  listMainAxisExtent: kVodRowExtent,
                  listItemBuilder: (context, video) => VodVideoRow(video: video, onOpen: () => _openVideo(video)),
                  infoExtent: kVodCardInfoExtent,
                  crossSpacing: settings.crossSpacing,
                  mainSpacing: settings.mainSpacing,
                  isLoading: state.loading,
                  hasMore: state.hasMore,
                  onLoadMore: controller.loadMore,
                  error: error,
                  onRetry: () => unawaited(controller.refresh()),
                  onRefresh: controller.refresh,
                  refreshError: error,
                  emptyIcon: DsIcons.circleUser,
                  emptyTitle: t.vod.noResultsTitle,
                  emptyDescription: t.vod.noResultsDescription,
                  itemBuilder: (context, video) => VodVideoCard(video: video, onOpen: () => _openVideo(video)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The space's identity head: the uploader's face, name and platform badge
/// over the whole list's size — the shape the Huya uploader's page wears.
final class _Head extends StatelessWidget {
  const _Head({required this.name, required this.avatar, required this.total, required this.platform});

  final String name;
  final String? avatar;
  final int? total;
  final String platform;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Row(
      spacing: DsSpace.s12,
      children: [
        DsAvatar(
          initials: avatarInitials(name),
          image: (avatar?.isEmpty ?? true) ? null : cachedImage(avatar!, policy: ImageCachePolicies.avatar),
          size: DsSize.lg,
          semanticLabel: name,
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
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.title.copyWith(color: colors.text),
                    ),
                  ),
                  DsBadge(label: Text(platform), dot: false),
                ],
              ),
              if (total != null)
                Text(
                  '${AudienceFormat.format(total)} ${t.vod.uploads}',
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The space's loading shape: the head's face and words, then the rows the
/// list settles into.
final class _SpaceSkeleton extends StatelessWidget {
  const _SpaceSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(DsSpace.s16),
      itemCount: 7,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: DsSpace.s12),
        child: index == 0
            ? const Row(
                spacing: DsSpace.s12,
                children: [
                  DsSkeleton.circle(size: 56),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: DsSpace.s8,
                    children: [DsSkeleton(width: 180, height: 20), DsSkeleton(width: 120, height: 12)],
                  ),
                ],
              )
            : const Row(
                spacing: DsSpace.s12,
                children: [
                  DsSkeleton.block(width: 148, height: 83),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: DsSpace.s8,
                      children: [
                        DsSkeleton(width: double.infinity, height: 14),
                        DsSkeleton(width: 140, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
