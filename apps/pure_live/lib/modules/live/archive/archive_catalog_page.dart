import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/archive/archive_catalog_controller.dart';
import 'package:pure_live/modules/live/archive/archive_navigation.dart';
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart' show VodVideoCard, VodVideoRow, kVodCardInfoExtent;
import 'package:pure_live/shared/shared.dart';

/// A creator's replay catalog, opened by an offline room: the collections
/// the platform labels as broadcast recordings, the selected one's
/// recordings, and the walk into the video station's player. In pick-only
/// mode it hands the chosen recording back to the invoking page instead.
final class ArchiveCatalogPage extends ConsumerStatefulWidget {
  /// Builds the page for [arguments]; the room inside carries the creator.
  const ArchiveCatalogPage({required this.arguments, super.key});

  /// The invoking room's ownership callbacks (never serialized).
  final ArchiveArguments arguments;

  @override
  ConsumerState<ArchiveCatalogPage> createState() => _ArchiveCatalogPageState();
}

final class _ArchiveCatalogPageState extends ConsumerState<ArchiveCatalogPage> {
  String _siteId = '';
  String _creator = '';

  @override
  void initState() {
    super.initState();
    // The creator's own id — a Bilibili uid, a SOOP broadcaster handle, or
    // the Douyu room the presenter owns — names the catalog; the room's
    // platform picks the source.
    final room = widget.arguments.room;
    _siteId = room?.ref.platform ?? '';
    _creator = (room?.anchor?.anchorId ?? '').trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(archiveCatalogProvider.notifier).start(siteId: _siteId, creator: _creator));
      }
    });
  }

  Future<void> _pick(ArchivePick pick) async {
    final arguments = widget.arguments;
    if (arguments.pickOnly) {
      Navigator.of(context).pop(pick);
      return;
    }
    // The covered live decoder goes quiet before another player opens; the
    // invoking room resumes once the whole walk has settled.
    await arguments.beforePlay?.call();
    if (!mounted) return;
    final bilibili = pick.bilibili;
    if (bilibili != null) {
      unawaited(context.push(RouteNames.vodVideo.replaceFirst(':bvid', bilibili.bvid)));
      return;
    }
    final soop = pick.soop;
    if (soop != null) {
      unawaited(
        context.push(
          RouteNames.archivePlayer,
          extra: ArchivePlayerRequest(soop: soop, arguments: arguments),
        ),
      );
      return;
    }
    final huya = pick.huya;
    if (huya != null) {
      unawaited(
        context.push(
          RouteNames.archivePlayer,
          extra: ArchivePlayerRequest(huya: huya, arguments: arguments),
        ),
      );
      return;
    }
    final douyu = pick.douyu;
    if (douyu != null) {
      unawaited(
        context.push(
          RouteNames.archivePlayer,
          extra: ArchivePlayerRequest(douyu: douyu, arguments: arguments),
        ),
      );
    }
  }

  /// The recording's own day, the identity a replay catalog reads by.
  String _dayOf(ArchivePick pick) {
    final at = pick.bilibili?.publishedAt ?? pick.soop?.publishedAt ?? pick.douyu?.publishedAt;
    if (at == null) return '';
    final month = '${at.month}'.padLeft(2, '0');
    final day = '${at.day}'.padLeft(2, '0');
    return '${at.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(archiveCatalogProvider);
    final controller = ref.read(archiveCatalogProvider.notifier);
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final name = (widget.arguments.room?.anchor?.name ?? '').trim();

    final Widget body;
    if (state.opening) {
      body = const Center(child: DsSpinner());
    } else if (state.openingError != null) {
      body = Center(
        child: DsAlert(
          status: DsStatus.danger,
          title: Text(t.room.replayFailed),
          action: DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            onPressed: state.selectedKey == null
                ? () => unawaited(controller.start(siteId: _siteId, creator: _creator))
                : controller.reload,
            child: Text(t.common.retry),
          ),
        ),
      );
    } else if (state.collections.isEmpty) {
      body = Center(
        child: Text(
          t.room.replayEmpty,
          style: theme.typography.body.copyWith(color: colors.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    } else {
      body = PagedCardGrid<ArchivePick>(
        items: state.recordings,
        itemBuilder: (context, pick) => VodVideoCard(video: pick.display, onOpen: () => unawaited(_pick(pick))),
        layout: ref.watch(browseLayoutProvider),
        listMainAxisExtent: 104,
        listItemBuilder: (context, pick) =>
            VodVideoRow(video: pick.display, subtitle: _dayOf(pick), onOpen: () => unawaited(_pick(pick))),
        infoExtent: kVodCardInfoExtent,
        isLoading: state.loading || state.loadingMore,
        hasMore: state.hasMore,
        onLoadMore: controller.loadMore,
        error: state.error == null ? null : t.room.replayFailed,
        onRetry: controller.reload,
        onRefresh: controller.reload,
        refreshError: state.error == null ? null : t.room.replayFailed,
        emptyIcon: DsIcons.film,
        emptyTitle: t.room.replayEmpty,
      );
    }

    return PageSurface(
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: name.isEmpty ? t.room.replayCatalog : name,
              actions: [
                if (state.selectedKey != null)
                  DsButton.icon(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    semanticLabel: t.common.refresh,
                    loading: state.loading,
                    onPressed: state.loading ? null : () => unawaited(controller.reload()),
                    icon: const DsIcon(DsIcons.refreshCw, size: 16),
                  ),
              ],
            ),
            // A creator usually labels one collection; the selector only
            // exists when there is a choice to make.
            if (state.collections.length > 1)
              Padding(
                padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s4),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DsSegmentedControl<String>(
                    value: state.selectedKey ?? state.collections.first.key,
                    semanticLabel: t.room.replayCollections,
                    onChanged: (key) => unawaited(controller.select(key)),
                    segments: [
                      for (final collection in state.collections)
                        DsSegment(value: collection.key, label: Text(collection.name)),
                    ],
                  ),
                ),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
