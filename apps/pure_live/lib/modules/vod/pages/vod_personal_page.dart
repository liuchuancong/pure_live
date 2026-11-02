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
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart'
    show VodSeasonCard, VodVideoRow, kVodSeasonTileAspect, vodDurationText;
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

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final account = ref.watch(vodAccountProvider);
    final loggedIn = account.value?.isLogin ?? false;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s8,
            children: [
              Row(
                spacing: DsSpace.s12,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: DsSpace.s3,
                      children: [
                        Text(
                          t.vod.personalTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.title.copyWith(color: colors.text),
                        ),
                        Text(
                          account.value?.name == null
                              ? t.vod.personalCount(count: count)
                              : '${account.value!.name} · ${t.vod.personalCount(count: count)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.caption.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (_tab == VodPersonalTab.history && history.isNotEmpty)
                    DsButton.icon(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      semanticLabel: t.vod.clearHistory,
                      onPressed: () => unawaited(_clearHistory()),
                      icon: const DsIcon(DsIcons.trash2, size: 16),
                    ),
                ],
              ),
              SizedBox(
                height: 40,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DsSegmentedControl<VodPersonalTab>(
                    value: _tab,
                    onChanged: (tab) => setState(() => _tab = tab),
                    semanticLabel: t.vod.personalTitle,
                    segments: [
                      for (final tab in VodPersonalTab.values)
                        DsSegment(value: tab, icon: DsIcon(tab.icon), label: Text(tab.label(t))),
                    ],
                  ),
                ),
              ),
              if (_tab == VodPersonalTab.following)
                SizedBox(
                  height: 36,
                  child: DsSegmentedControl<int>(
                    value: _seasonType,
                    onChanged: (type) => setState(() => _seasonType = type),
                    semanticLabel: t.vod.personalFollowing,
                    segments: [
                      DsSegment(value: 1, label: Text(t.vod.followingBangumi)),
                      DsSegment(value: 2, label: Text(t.vod.followingCinema)),
                    ],
                  ),
                ),
            ],
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
                        ? DsEmptyState(
                            icon: const DsIcon(DsIcons.history),
                            title: Text(t.vod.historyEmptyTitle),
                            description: Text(t.vod.historyEmptyDescription),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s24),
                            itemCount: history.length,
                            itemBuilder: (context, index) {
                              final entry = history[index];
                              final position = vodDurationText(
                                Duration(milliseconds: (entry.positionSeconds * 1000).round()),
                              );
                              final total = entry.video.durationSeconds == null
                                  ? ''
                                  : vodDurationText(
                                      Duration(milliseconds: (entry.video.durationSeconds! * 1000).round()),
                                    );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: DsSpace.s4),
                                child: VodVideoRow(
                                  video: entry.video.video,
                                  subtitle: entry.completed
                                      ? t.vod.historyCompleted
                                      : total.isEmpty
                                      ? position
                                      : t.vod.historyProgress(position: position, total: total),
                                  progress: _watched(entry),
                                  onOpen: () => _open(entry.bvid),
                                  trailing: _drop(
                                    t.vod.historyRemove,
                                    () => ref.read(vodHistoryProvider.notifier).remove(entry.bvid),
                                  ),
                                ),
                              );
                            },
                          ),
                  VodPersonalTab.favourites =>
                    favourites.isEmpty
                        ? DsEmptyState(
                            icon: const DsIcon(DsIcons.heart),
                            title: Text(t.vod.favouritesEmptyTitle),
                            description: Text(t.vod.favouritesEmptyDescription),
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
