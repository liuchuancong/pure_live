import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/vod_pgc.dart';
import 'package:pure_live/modules/vod/widgets/vod_toolbar.dart' show VodFeedToolbar, kVodFeedTabsStyle;
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart' show VodSeasonCard, kVodSeasonTileAspect;
import 'package:pure_live/shared/shared.dart';

/// The cinema's six catalogues with the platform's own names — Bilibili's
/// season types, in the reference's tab order.
String vodPgcLabel(Translations t, int type) => switch (type) {
  1 => t.vod.pgcAnime,
  2 => t.vod.pgcMovie,
  3 => t.vod.pgcDocumentary,
  4 => t.vod.pgcGuochuang,
  5 => t.vod.pgcTv,
  7 => t.vod.pgcVariety,
  _ => '$type',
};

/// The station's 影视 page: the reference's PGC entry — one catalogue at a
/// time, its seasons in a poster grid that pages in by cursor.
final class VodPgcPage extends ConsumerStatefulWidget {
  /// The cinema page, opening on [type] (Bilibili's season type).
  const VodPgcPage({this.type = 1, super.key});

  /// The catalogue the page opens on.
  final int type;

  @override
  ConsumerState<VodPgcPage> createState() => _VodPgcPageState();
}

final class _VodPgcPageState extends ConsumerState<VodPgcPage> {
  late int _type = widget.type;
  final Map<int, ScrollController> _scrolls = {};

  @override
  void initState() {
    super.initState();
    _ensure(_type);
  }

  @override
  void didUpdateWidget(VodPgcPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.type != _type) _select(widget.type);
  }

  @override
  void dispose() {
    for (final controller in _scrolls.values) {
      controller.dispose();
    }
    _scrolls.clear();
    super.dispose();
  }

  ScrollController _scrollOf(int type) => _scrolls.putIfAbsent(type, ScrollController.new);

  void _ensure(int type) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(vodPgcProvider.notifier).open(type));
    });
  }

  void _select(int type) {
    if (type == _type) return;
    setState(() => _type = type);
    _ensure(type);
  }

  void _openSeason(VodSeason season) {
    unawaited(context.push('/vod/season/${season.seasonId}'));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
          // The cinema grid is posters alone — one form, so no layout switch
          // beside its tabs, only the reload the other feeds offer.
          child: VodFeedToolbar(
            owner: NavigationItem.vodPgc,
            tabs: DsTabs<int>(
              value: _type,
              onChanged: _select,
              style: kVodFeedTabsStyle,
              tabs: [for (final type in kVodPgcTypes) DsTab(value: type, label: Text(vodPgcLabel(t, type)))],
            ),
            showLayout: false,
            onRefresh: () => ref.read(vodPgcProvider.notifier).refresh(_type),
          ),
        ),
        Expanded(
          child: _PgcFeedView(type: _type, scrollController: _scrollOf(_type), onOpen: _openSeason),
        ),
      ],
    );
  }
}

/// One catalogue's cursor feed as the poster wall, its spacing the viewer's
/// browse settings say — posters are the wall's one form, so the grid never
/// grows a list shape and the measure stays the season tile's own.
final class _PgcFeedView extends ConsumerWidget {
  const _PgcFeedView({required this.type, required this.scrollController, required this.onOpen});

  final int type;
  final ScrollController scrollController;
  final ValueChanged<VodSeason> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final browse = ref.watch(browseSettingsProvider);
    final feed =
        ref.watch(vodPgcProvider.select((feeds) => feeds[type])) ??
        (seasons: const <VodSeason>[], cursor: 0, hasMore: true, loading: false, loaded: false, error: null);
    final controller = ref.read(vodPgcProvider.notifier);
    return PagedCardGrid<VodSeason>(
      key: ValueKey(type),
      scrollController: scrollController,
      items: feed.seasons,
      aspectRatio: kVodSeasonTileAspect,
      crossSpacing: browse.crossSpacing,
      mainSpacing: browse.mainSpacing,
      isLoading: feed.loading,
      hasMore: feed.hasMore,
      onLoadMore: () => controller.loadMore(type),
      error: feed.error?.message,
      onRetry: () => controller.refresh(type),
      onRefresh: () => controller.refresh(type),
      refreshError: feed.error?.message,
      emptyIcon: DsIcons.clapperboard,
      emptyTitle: t.common.empty,
      emptyDescription: t.vod.pgcEmptyDescription,
      itemBuilder: (context, season) => VodSeasonCard(season: season, onOpen: () => onOpen(season)),
    );
  }
}
