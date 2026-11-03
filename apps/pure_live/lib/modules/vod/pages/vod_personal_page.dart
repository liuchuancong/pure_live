import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/features/account/account.dart' show showBilibiliWebLoginPage;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/vod_library.dart';
import 'package:pure_live/modules/vod/controller/vod_social.dart';
import 'package:pure_live/modules/vod/widgets/vod_toolbar.dart' show VodFeedAction, VodFeedToolbar, kVodFeedTabsStyle;
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart'
    show VodSeasonCard, VodVideoRow, kVodSeasonTileAspect, vodDurationText, vodWatchStamp;
import 'package:pure_live/shared/shared.dart';

/// The video station's 个人 page: the four lists the reference offers.
enum VodPersonalTab {
  /// The signed-in viewer's 稍后再看 list, as the platform holds it.
  toView,

  /// Archives the player has a position for, newest first.
  history,

  /// Archives the viewer collected in this module.
  favourites,

  /// The seasons the signed-in viewer follows, the reference's 追番.
  following;

  /// The tab's words.
  String label(Translations t) => switch (this) {
    VodPersonalTab.toView => t.vod.personalToView,
    VodPersonalTab.history => t.vod.personalHistory,
    VodPersonalTab.favourites => t.vod.personalFavourites,
    VodPersonalTab.following => t.vod.personalFollowing,
  };

  /// The tab's icon.
  DsIconData get icon => switch (this) {
    VodPersonalTab.toView => DsIcons.clock3,
    VodPersonalTab.history => DsIcons.history,
    VodPersonalTab.favourites => DsIcons.heart,
    VodPersonalTab.following => DsIcons.tvMinimal,
  };

  /// Whether the list lives on the platform and needs a sign-in.
  bool get needsLogin => this == VodPersonalTab.toView || this == VodPersonalTab.following;
}

/// The station's personal page: 稍后再看 / 历史 / 收藏 / 追番.
///
/// Two of the lists are the platform's (a sign-in is asked for them), two are
/// the module's own — a collected archive and a playback position this app
/// writes. Nothing here borrows the live rooms' favourites or history.
final class VodPersonalPage extends ConsumerStatefulWidget {
  /// The personal page, opening on [tab].
  const VodPersonalPage({this.tab = VodPersonalTab.toView, super.key});

  /// The tab the page opens on.
  final VodPersonalTab tab;

  @override
  ConsumerState<VodPersonalPage> createState() => _VodPersonalPageState();
}

final class _VodPersonalPageState extends ConsumerState<VodPersonalPage> {
  late VodPersonalTab _tab = widget.tab;

  /// The season type the 追番 tab lists: 1 番剧, 2 影视.
  int _seasonType = 1;

  @override
  void didUpdateWidget(VodPersonalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab != _tab) setState(() => _tab = widget.tab);
  }

  void _open(String bvid) {
    if (bvid.isEmpty) return;
    unawaited(context.push('/vod/$bvid'));
  }

  void _openSeason(int seasonId) => unawaited(context.push('/vod/season/$seasonId'));

  /// The watched fraction a history row draws along its cover: nothing at all
  /// when the archive is finished (the line under the title says so), when it
  /// has no length to be a fraction of, or when it has not really started — an
  /// empty stripe under a cover is not a piece of information.
  double? _watched(VodHistoryEntry entry) {
    if (entry.completed) return null;
    final total = entry.video.durationSeconds;
    if (total == null || total <= 0) return null;
    final fraction = (entry.positionSeconds / total).clamp(0.0, 1.0);
    return fraction > 0 ? fraction : null;
  }

  /// The row-end action that drops one archive from the list it was read out
  /// of, named by [label].
  Widget _drop(String label, Future<void> Function() onRemove) => DsButton.icon(
    variant: DsButtonVariant.secondary,
    size: DsSize.sm,
    semanticLabel: label,
    onPressed: () => unawaited(onRemove()),
    icon: const DsIcon(DsIcons.x, size: 16),
  );

  Future<void> _clearHistory() async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.vod.clearHistoryTitle,
      description: t.vod.clearHistoryDesc,
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(vodHistoryProvider.notifier).clear();
  }

  /// Whether the head's reload has something to re-ask: the platform's two
  /// lists answer to it, while the module's own two are written by the player,
  /// and re-reading what this device already holds draws the same rows.
  bool get _reloadable => _tab == VodPersonalTab.toView || _tab == VodPersonalTab.following;

  /// Asks the list the head is showing again.
  Future<void> _refreshCurrent() async {
    switch (_tab) {
      case VodPersonalTab.toView:
        ref.invalidate(vodWatchLaterProvider);
      case VodPersonalTab.following:
        ref.invalidate(vodFollowingSeasonsProvider(_seasonType));
      case VodPersonalTab.history:
      case VodPersonalTab.favourites:
        return;
    }
  }

  /// The scope the 追番 list reads under, in that list's own words.
  String _scopeLabel(Translations t) => _seasonType == 2 ? t.vod.followingCinema : t.vod.followingBangumi;

  /// 番剧 or 影视 — the one condition the 追番 list reads under, behind the
  /// head's entry rather than as a second standing tab row.
  Future<void> _openSeasonFilter() => showDsPanel<void>(
    context: context,
    builder: (context) => _SeasonTypePanel(
      seasonType: _seasonType,
      onPick: (type) {
        if (type != _seasonType) setState(() => _seasonType = type);
      },
    ),
  );

  /// The player's own history, read by the day it happened: 今天, 昨天, then
  /// everything before — the three tiers this repo's two other archive pages
  /// (live 历史, IPTV 最近观看) already cut at, and the three a viewer counts in
  /// when asking which video they left half-watched. Each tier answers with its
  /// own head, so a long record is scanned by day rather than as one flat run;
  /// a tier with nothing in it is not announced, since a head over no rows
  /// explains a list that is not there.
  Widget _historyList(List<VodHistoryEntry> history, double inset) {
    final sections = _daySections(context.t, history, DateTime.now());
    return CustomScrollView(
      slivers: [
        for (final section in sections) ...[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s4),
            sliver: SliverToBoxAdapter(
              child: _DayHeader(label: section.label, count: section.entries.length),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s4),
            sliver: SliverList.separated(
              itemCount: section.entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: DsSpace.s4),
              itemBuilder: (context, index) => _historyRow(section.entries[index], namedDay: section.namedDay),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: DsSpace.s20)),
      ],
    );
  }

  /// One record: the station's row, its position under the title, the break
  /// along the cover's foot, and the minute it happened on at the end of its
  /// title — the date travels with the clock once the head above no longer
  /// names the day, so one day is not written in two places.
  Widget _historyRow(VodHistoryEntry entry, {required bool namedDay}) {
    final t = context.t;
    final position = vodDurationText(Duration(milliseconds: (entry.positionSeconds * 1000).round()));
    final total = entry.video.durationSeconds == null
        ? ''
        : vodDurationText(Duration(milliseconds: (entry.video.durationSeconds! * 1000).round()));
    return VodVideoRow(
      video: entry.video.video,
      subtitle: entry.completed
          ? t.vod.historyCompleted
          : total.isEmpty
          ? position
          : t.vod.historyProgress(position: position, total: total),
      progress: _watched(entry),
      stamp: vodWatchStamp(entry.video.updatedAt, namedDay: namedDay),
      onOpen: () => _open(entry.bvid),
      trailing: _drop(t.vod.historyRemove, () => ref.read(vodHistoryProvider.notifier).remove(entry.bvid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final account = ref.watch(vodAccountProvider);
    final loggedIn = account.value?.isLogin ?? false;
    final name = account.value?.name;
    final history = ref.watch(vodHistoryProvider);
    final favourites = ref.watch(vodFavouritesProvider);
    final toView = ref.watch(vodWatchLaterProvider).value ?? const <VodVideo>[];
    final following = ref.watch(vodFollowingSeasonsProvider(_seasonType)).value;
    final count = switch (_tab) {
      VodPersonalTab.toView => toView.length,
      VodPersonalTab.history => history.length,
      VodPersonalTab.favourites => favourites.length,
      VodPersonalTab.following => following?.seasons.length ?? 0,
    };
    // The 追番 sub-list is only a choice once the platform's answer is on the
    // screen; a guest gets the sign-in invitation, and an entry that opens an
    // empty panel is not a choice.
    final seasonFilter = _tab == VodPersonalTab.following && loggedIn;
    final actions = <VodFeedAction>[
      if (seasonFilter)
        VodFeedAction(
          icon: DsIcons.listFilter,
          label: t.vod.searchFilterTitle,
          onPressed: () => unawaited(_openSeasonFilter()),
        ),
      if (_tab == VodPersonalTab.history && history.isNotEmpty)
        VodFeedAction(icon: DsIcons.trash2, label: t.vod.clearHistory, onPressed: () => unawaited(_clearHistory())),
    ];
    final summary = <String>[
      if (seasonFilter) _scopeLabel(t),
      ?name,
      if (loggedIn || !_tab.needsLogin) t.vod.personalCount(count: count),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, summary.isEmpty ? DsSpace.s8 : DsSpace.s4),
          // The station's feed head, the same 44 the three browse pages and
          // the search results use: the four lists at its start, their scope
          // entry, cleanup and reload at its end — and on a narrow window one
          // more icon carrying the same. The rail already names this page, so
          // the head writes no title of its own over the lists, and the 追番
          // scope reads from this head instead of adding a second tab row that
          // pushes the list down.
          child: VodFeedToolbar(
            tabs: DsTabs<VodPersonalTab>(
              value: _tab,
              onChanged: (tab) => setState(() => _tab = tab),
              semanticLabel: t.vod.personalTitle,
              style: kVodFeedTabsStyle,
              tabs: [for (final tab in VodPersonalTab.values) DsTab(value: tab, label: Text(tab.label(t)))],
            ),
            showLayout: false,
            actions: actions,
            onRefresh: loggedIn && _reloadable ? _refreshCurrent : null,
          ),
        ),
        if (summary.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
            child: Text(
              summary.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(color: colors.textMuted),
            ),
          ),
        Expanded(
          child: !loggedIn && _tab.needsLogin
              ? _SignInState(tab: _tab)
              : switch (_tab) {
                  VodPersonalTab.toView => _RemoteVideoList(
                    videos: toView,
                    loading: ref.watch(vodWatchLaterProvider).isLoading,
                    error: ref.watch(vodWatchLaterProvider).error,
                    onOpen: _open,
                    onRetry: () => ref.invalidate(vodWatchLaterProvider),
                    emptyIcon: DsIcons.clock3,
                    emptyTitle: t.vod.toViewEmptyTitle,
                    emptyDescription: t.vod.toViewEmptyDescription,
                  ),
                  VodPersonalTab.history =>
                    history.isEmpty
                        ? Center(
                            child: DsEmptyState(
                              icon: const DsIcon(DsIcons.history),
                              title: Text(t.vod.historyEmptyTitle),
                              description: Text(t.vod.historyEmptyDescription),
                            ),
                          )
                        : _historyList(history, inset),
                  VodPersonalTab.favourites =>
                    favourites.isEmpty
                        ? Center(
                            child: DsEmptyState(
                              icon: const DsIcon(DsIcons.heart),
                              title: Text(t.vod.favouritesEmptyTitle),
                              description: Text(t.vod.favouritesEmptyDescription),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s24),
                            itemCount: favourites.length,
                            itemBuilder: (context, index) {
                              final video = favourites[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: DsSpace.s4),
                                child: VodVideoRow(
                                  video: video.video,
                                  onOpen: () => _open(video.bvid),
                                  trailing: _drop(
                                    t.vod.favouriteRemove,
                                    () => ref.read(vodFavouritesProvider.notifier).remove(video.bvid),
                                  ),
                                ),
                              );
                            },
                          ),
                  VodPersonalTab.following => _FollowingList(
                    page: following,
                    loading: ref.watch(vodFollowingSeasonsProvider(_seasonType)).isLoading,
                    error: ref.watch(vodFollowingSeasonsProvider(_seasonType)).error,
                    onOpen: _openSeason,
                    onRetry: () => ref.invalidate(vodFollowingSeasonsProvider(_seasonType)),
                  ),
                },
        ),
      ],
    );
  }
}

/// One day of the player's record: the words over it, whether those words
/// already name the calendar day the rows fell on, and the rows themselves.
typedef _DaySection = ({bool namedDay, String label, List<VodHistoryEntry> entries});

/// Midnight the record fell on.
DateTime _startOfDay(DateTime time) => DateTime(time.year, time.month, time.day);

/// The record cut at the days it happened. The list arrives newest first, so
/// each tier keeps that order and the tiers keep it between themselves.
List<_DaySection> _daySections(Translations t, List<VodHistoryEntry> history, DateTime now) {
  final today = _startOfDay(now);
  final yesterday = today.subtract(const Duration(days: 1));
  final buckets = <_DaySection>[
    (namedDay: true, label: t.vod.today, entries: []),
    (namedDay: true, label: t.vod.yesterday, entries: []),
    (namedDay: false, label: t.vod.earlier, entries: []),
  ];
  for (final entry in history) {
    final day = _startOfDay(entry.video.updatedAt);
    final index = day == today
        ? 0
        : day == yesterday
        ? 1
        : 2;
    buckets[index].entries.add(entry);
  }
  return [
    for (final section in buckets)
      if (section.entries.isNotEmpty) section,
  ];
}

/// One tier's head: the day it covers and how many records it holds — the pair
/// every archive page of this app puts over its days.
final class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Row(
      spacing: DsSpace.s8,
      children: [
        Text(label, style: theme.typography.labelStrong.copyWith(color: colors.text)),
        DsBadge(label: Text('$count'), dot: false),
      ],
    );
  }
}

/// The sign-in invitation the platform-only lists show to a guest.
final class _SignInState extends StatelessWidget {
  const _SignInState({required this.tab});

  final VodPersonalTab tab;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Center(
      child: DsEmptyState(
        icon: DsIcon(tab.icon),
        title: Text(t.vod.signInNeededTitle),
        description: Text(t.vod.signInNeededDescription),
        actions: [
          DsButton(
            variant: DsButtonVariant.primary,
            onPressed: () => unawaited(showBilibiliWebLoginPage(context)),
            child: Text(t.vod.signIn),
          ),
        ],
      ),
    );
  }
}

/// A platform list of archives (稍后再看), read as rows.
final class _RemoteVideoList extends StatelessWidget {
  const _RemoteVideoList({
    required this.videos,
    required this.loading,
    required this.error,
    required this.onOpen,
    required this.onRetry,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyDescription,
  });

  final List<VodVideo> videos;
  final bool loading;
  final Object? error;
  final ValueChanged<String> onOpen;
  final VoidCallback onRetry;
  final DsIconData emptyIcon;
  final String emptyTitle;
  final String emptyDescription;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    if (error != null && videos.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(t.vod.loadFailed),
          description: Text('$error'),
          actions: [DsButton(onPressed: onRetry, child: Text(t.vod.retry))],
        ),
      );
    }
    if (loading && videos.isEmpty) return const Center(child: DsSpinner());
    if (videos.isEmpty) {
      return Center(
        child: DsEmptyState(icon: DsIcon(emptyIcon), title: Text(emptyTitle), description: Text(emptyDescription)),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s24),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: DsSpace.s4),
          child: VodVideoRow(video: video, onOpen: () => onOpen(video.bvid ?? video.id)),
        );
      },
    );
  }
}

/// The followed seasons as a poster grid.
final class _FollowingList extends StatelessWidget {
  const _FollowingList({
    required this.page,
    required this.loading,
    required this.error,
    required this.onOpen,
    required this.onRetry,
  });

  final VodSeasonPage? page;
  final bool loading;
  final Object? error;
  final ValueChanged<int> onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final seasons = page?.seasons ?? const <VodSeason>[];
    if (error != null && seasons.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(t.vod.loadFailed),
          description: Text('$error'),
          actions: [DsButton(onPressed: onRetry, child: Text(t.vod.retry))],
        ),
      );
    }
    if (loading && seasons.isEmpty) return const Center(child: DsSpinner());
    if (seasons.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.tvMinimal),
          title: Text(t.vod.followingEmptyTitle),
          description: Text(t.vod.followingEmptyDescription),
        ),
      );
    }
    return CardGrid<VodSeason>(
      items: seasons,
      aspectRatio: kVodSeasonTileAspect,
      itemBuilder: (context, season) => VodSeasonCard(season: season, onOpen: () => onOpen(season.seasonId)),
    );
  }
}

/// The 追番 list's scope in one panel behind the head's entry: 番剧 and 影视 as
/// two chips, each applying where it is touched — a chooser rather than a set
/// of conditions to submit, which is why it has no footer.
final class _SeasonTypePanel extends StatelessWidget {
  const _SeasonTypePanel({required this.seasonType, required this.onPick});

  /// The type the list reads under now.
  final int seasonType;

  /// Moves the list to the chosen type.
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsPanel(
      title: Text(t.vod.personalFollowing),
      child: Wrap(
        spacing: DsSpace.s8,
        runSpacing: DsSpace.s8,
        children: [
          for (final (type, label) in [(1, t.vod.followingBangumi), (2, t.vod.followingCinema)])
            DsChip(
              label: Text(label),
              selected: type == seasonType,
              onChanged: (on) {
                if (!on) return;
                onPick(type);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}
