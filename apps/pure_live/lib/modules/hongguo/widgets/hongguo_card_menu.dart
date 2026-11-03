import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:pure_live/app/app.dart' show RouteNames;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart'
    show hongguoClientProvider, hongguoFailureText;
import 'package:pure_live/modules/hongguo/controller/hongguo_downloads.dart'
    show HongguoDownloadEnqueue, hongguoDownloadQualityProvider, hongguoDownloadsProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_library.dart'
    show HongguoWatchProgress, hongguoLibraryProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart' show HongguoSeries, HongguoSeriesDetail;
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart' show kHongguoSite;
import 'package:pure_live/modules/hongguo/widgets/hongguo_widgets.dart'
    show hongguoResumeSeconds, hongguoSeriesSubtitle;

/// Whether a listing's row opens at all: the reservation shelf carries titles
/// the station has not published yet, whose id is the reservation's own.
bool hongguoSeriesOpenable(HongguoSeries series) =>
    series.seriesId.isNotEmpty && !series.seriesId.startsWith('reservation:');

/// The series card's window furniture, worn by every feed that lists titles:
/// the hover label that names the series in full — a card truncates its title
/// and leaves the rest to its poster — and the right-click / long-press menu.
///
/// The menu carries what a viewer does about a title: open its page, put the
/// picture on screen where this device stopped, keep or drop it on the local
/// shelf, hand one episode to the download queue, and copy its public page.
/// A page appends its own items after them (the history's removal).
///
/// The card keeps its own corner heart, which says the kept state; the menu is
/// where the title gets on the shelf in the first place, the way a followed
/// room is un-followed from its heart and followed from its menu.
final class HongguoCardMenu extends ConsumerWidget {
  /// Wraps [child] — the series' card or row — in the card's label and menu.
  /// [onOpen] opens the series' page; null leaves the card's own verb out of
  /// the menu, as an unopened reservation's row does.
  const HongguoCardMenu({required this.series, required this.child, this.onOpen, this.items = const [], super.key});

  /// The series the card shows.
  final HongguoSeries series;

  /// Opens the series; the card and the menu's first item both use it.
  final VoidCallback? onOpen;

  /// The page's own menu items, after the card's, behind a divider.
  final List<Widget> items;

  /// The card to wrap.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    // The page says whether this row opens at all: a title the station has not
    // published yet — a reservation, an upcoming related work — keeps the hover
    // label, loses every verb it cannot answer, and so reads nothing from the
    // local shelf either.
    final openable = onOpen != null && hongguoSeriesOpenable(series);
    final library = openable ? ref.watch(hongguoLibraryProvider) : null;
    final seen = library?.progressOf(series.seriesId);
    final favored = library?.isFavorite(series.seriesId) ?? false;
    final details = hongguoSeriesSubtitle(t, series, watched: seen);
    final actions = <Widget>[
      if (onOpen != null)
        DsMenuItem(leading: const DsIcon(DsIcons.listVideo), label: Text(t.hongguo.cardOpenSeries), onPressed: onOpen),
      if (openable)
        DsMenuItem(
          leading: const DsIcon(DsIcons.play),
          label: Text(hongguoResumeSeconds(seen) != null ? t.hongguo.continueWatching : t.hongguo.play),
          onPressed: () => _play(context, ref, seen),
        ),
      if (openable)
        DsMenuItem(
          leading: DsIcon(favored ? DsIcons.heartOff : DsIcons.heart),
          label: Text(favored ? t.hongguo.unfavorite : t.hongguo.favorite),
          destructive: favored,
          onPressed: () => _toggleFavorite(context, ref),
        ),
      if (openable)
        DsMenuItem(
          leading: const DsIcon(DsIcons.download),
          label: Text(t.hongguo.download),
          onPressed: () => unawaited(_startDownload(context, ref)),
        ),
      if (openable)
        DsMenuItem(
          leading: const DsIcon(DsIcons.link),
          label: Text(t.hongguo.cardCopyLink),
          onPressed: () => unawaited(_copyLink(context)),
        ),
    ];
    final menu = [...actions, if (actions.isNotEmpty && items.isNotEmpty) const DsMenuDivider(), ...items];
    final body = menu.isEmpty ? child : DsContextMenuRegion(semanticLabel: t.common.more, items: menu, child: child);
    return DsTooltip(
      message: details.isEmpty ? series.title : '${series.title}\n$details',
      side: DsSide.bottom,
      // The card already speaks its own content; the label is for the pointer,
      // not a second thing to hear.
      excludeFromSemantics: true,
      child: body,
    );
  }

  /// The picture on screen where this device stopped — the same checkpoint the
  /// card's corner and the shelf's head read, so the verb on the item and the
  /// position it opens at cannot disagree.
  void _play(BuildContext context, WidgetRef ref, HongguoWatchProgress? seen) {
    final vid = seen?.episodeVid ?? '';
    unawaited(
      context.push(
        RouteNames.hongguoPlayerFor(
          series.seriesId,
          vid: vid.isEmpty ? null : vid,
          resumeSeconds: hongguoResumeSeconds(seen),
        ),
      ),
    );
  }

  /// Keeps the title on this device's shelf, or drops it when it is kept.
  void _toggleFavorite(BuildContext context, WidgetRef ref) {
    final added = ref.read(hongguoLibraryProvider.notifier).toggleFavorite(series);
    showDsToast(
      context: context,
      title: added ? context.t.hongguo.favoriteToggleOn : context.t.hongguo.favoriteToggleOff,
    );
  }

  /// The series' public page, on the clipboard — the verb the player's own
  /// share runs, with the words the player already uses for it.
  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: '$kHongguoSite/detail?series_id=${Uri.encodeComponent(series.seriesId)}'),
    );
    if (!context.mounted) return;
    showDsToast(context: context, title: context.t.hongguo.shareCopied);
  }

  /// One episode to the app-wide queue. A card holds no episode list, so the
  /// menu reads the detail the series' own page reads and takes the episode
  /// this device stopped on — the first when it never got inside. The queue
  /// resolves its own ladder and proxy when the task's turn comes.
  Future<void> _startDownload(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final HongguoSeriesDetail detail;
    try {
      detail = await ref.read(hongguoClientProvider).detail(series.seriesId);
    } on Object catch (error) {
      if (!context.mounted) return;
      showDsToast(
        context: context,
        title: t.hongguo.downloadFailed,
        description: hongguoFailureText(error),
        status: DsStatus.danger,
      );
      return;
    }
    final episodes = detail.episodes;
    if (episodes.isEmpty) {
      if (!context.mounted) return;
      showDsToast(context: context, title: t.hongguo.cardNoEpisodes, status: DsStatus.danger);
      return;
    }
    final vid = ref.read(hongguoLibraryProvider).progressOf(series.seriesId)?.episodeVid ?? '';
    final position = episodes.indexWhere((episode) => episode.vid == vid);
    final chosen = position < 0 ? episodes.first : episodes[position];
    final result = await ref
        .read(hongguoDownloadsProvider.notifier)
        .download(
          vid: chosen.vid,
          seriesId: series.seriesId,
          title: detail.meta.title.isEmpty ? series.title : detail.meta.title,
          part: chosen.title.isEmpty ? t.hongguo.episodeLabel(index: chosen.index) : chosen.title,
          index: chosen.index > 0 ? chosen.index : position + 1,
          parts: episodes.length,
          maxHeight: ref.read(hongguoDownloadQualityProvider).maxHeight,
          cover: detail.meta.cover.isEmpty ? series.cover : detail.meta.cover,
        );
    if (!context.mounted) return;
    switch (result.outcome) {
      case HongguoDownloadEnqueue.queued:
        showDsToast(context: context, title: t.hongguo.downloadQueued, status: DsStatus.success);
      case HongguoDownloadEnqueue.duplicate:
        showDsToast(context: context, title: t.hongguo.downloadDuplicate);
      case HongguoDownloadEnqueue.failed:
        showDsToast(
          context: context,
          title: t.hongguo.downloadFailed,
          description: result.error,
          status: DsStatus.danger,
        );
    }
  }
}
