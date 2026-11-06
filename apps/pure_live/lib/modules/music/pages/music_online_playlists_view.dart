import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_library.dart' show musicFavouritesProvider;
import 'package:pure_live/modules/music/controller/music_online_playlists.dart'
    show
        musicOnlineHotTagsProvider,
        musicOnlinePlaylistDetailProvider,
        musicOnlinePlaylistsProvider,
        musicPlaylistSortLabel,
        musicPlaylistSortsProvider,
        musicPlaylistTagGroupsProvider;
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/music_playlists.dart' show musicPlaylistsProvider;
import 'package:pure_live/modules/music/controller/music_source.dart' show musicSourceProvider;
import 'package:pure_live/modules/music/controller/sources/music_browse_source.dart' show musicCapabilityOf;
import 'package:pure_live/modules/music/controller/sources/online_playlist_models.dart'
    show MusicPlaylistInfo, MusicPlaylistPage, MusicPlaylistTag, MusicPlaylistTagGroup, MusicPlazaSort, OnlinePlaylists;
import 'package:pure_live/modules/music/music_page.dart' show MusicView;
import 'package:pure_live/modules/music/pages/music_playlist_card.dart' show MusicPlaylistCard, MusicPlaylistGrid;
import 'package:pure_live/modules/music/widgets/music_actions.dart';
import 'package:pure_live/modules/music/widgets/music_browse_widgets.dart' show MusicToolAction;
import 'package:pure_live/modules/music/widgets/music_widgets.dart';
import 'package:pure_live/shared/shared.dart' show AudienceFormat, CoverFallback, LiveWindow, cachedImage;

final class MusicSonglistTabs extends ConsumerWidget {
  const MusicSonglistTabs({
    required this.online,
    required this.mineCount,
    required this.onChanged,
    this.actions = const <Widget>[],
    super.key,
  });

  final bool online;
  final int mineCount;
  final ValueChanged<bool> onChanged;

  /// The controls beside the tabs, shown with them on the row's end.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return Row(
      spacing: DsSpace.s8,
      children: [
        Expanded(
          child: DsTabs<bool>(
            value: online,
            onChanged: onChanged,
            style: kMusicFeedTabsStyle,
            tabs: [
              DsTab<bool>(value: false, label: Text(t.music.songlistTabMine), count: mineCount),
              DsTab<bool>(value: true, label: Text(t.music.songlistTabOnline)),
            ],
            semanticLabel: t.music.songlistTabMine,
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// The 44px back row both playlist details share, on the browse header's
/// anatomy: back, then the page's name start-aligned, and the detail's verbs
/// following it — no spacer carries them to the far end.
final class MusicDetailBackRow extends StatelessWidget {
  /// The back row under [title], leaving to [onBack], carrying [actions].
  const MusicDetailBackRow({required this.title, required this.onBack, this.actions = const <Widget>[], super.key});

  /// The page's name, the kind of thing being browsed.
  final String title;

  /// The tap that walks back.
  final VoidCallback onBack;

  /// The detail's own verbs, drawn beside the title.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s4, DsSpace.s20, DsSpace.s4),
        child: Row(
          spacing: DsSpace.s8,
          children: [
            DsButton.icon(
              variant: DsButtonVariant.ghost,
              semanticLabel: t.common.back,
              onPressed: onBack,
              icon: const DsIcon(DsIcons.chevronLeft),
            ),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.title.copyWith(color: colors.text),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// The 在线歌单 browser: hot tags as chips, one page row per fetched page,
/// a load-more at the end. A source without the capability says so plainly
/// instead of showing an empty list.
///
/// The 歌单 page shows it under the 我的/在线 tabs; 精选 shows the same
/// browser on its own, with a heading in their place.
final class MusicOnlinePlaylistBrowse extends ConsumerStatefulWidget {
  const MusicOnlinePlaylistBrowse({
    required this.onOpen,
    this.mineCount = 0,
    this.onBackToMine,
    this.showTabs = true,
    this.heading,
    super.key,
  });

  final ValueChanged<MusicPlaylistInfo> onOpen;

  /// The 我的歌单 tab's count, beside the tabs.
  final int mineCount;

  /// Called when the tabs move back to the viewer's own lists.
  final VoidCallback? onBackToMine;

  /// Whether the 我的/在线 tab row leads the page; 精选 names a heading
  /// instead.
  final bool showTabs;

  /// The heading shown in the tabs' place.
  final String? heading;

  @override
  ConsumerState<MusicOnlinePlaylistBrowse> createState() => MusicOnlinePlaylistBrowseState();
}

final class MusicOnlinePlaylistBrowseState extends ConsumerState<MusicOnlinePlaylistBrowse> {
  /// The sort tab in browse; null waits for the sorts to name the first.
  String? _order;

  /// The category group in browse; empty is the hot tags.
  String _group = '';

  /// The tag in browse; null waits for the chips to name the first.
  String? _tag;

  /// How many pages are wanted; the family provider caches each one, so
  /// widening this range re-reads, it does not re-fetch.
  int _page = 1;

  /// The reference's 打开歌单 dialog: the pasted link or id, opened as the
  /// playlist's detail once confirmed.
  Future<void> _openByLink() async {
    final t = context.t;
    final theme = DsTheme.of(context);
    final field = TextEditingController();
    final opened = await showDsDialog<String>(
      context: context,
      builder: (context) => DsDialog(
        title: Text(t.music.openPlaylistTitle),
        icon: const DsIcon(DsIcons.listMusic),
        description: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsTextField(
              controller: field,
              autofocus: true,
              clearable: true,
              placeholder: t.music.openPlaylistHint,
              semanticLabel: t.music.openPlaylistTitle,
            ),
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.s8),
              child: Text(t.music.openPlaylistTip, style: theme.typography.caption),
            ),
          ],
        ),
        actions: [
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.cancel),
          ),
          DsButton(onPressed: () => Navigator.of(context).pop(field.text), child: Text(t.common.confirm)),
        ],
      ),
    );
    field.dispose();
    final target = opened?.trim();
    if (target == null || target.isEmpty || !mounted) return;
    widget.onOpen(MusicPlaylistInfo(id: target, name: target, cover: '', author: '', trackCount: 0));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // The page's gutter, the same measure the live module's pages keep.
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final hotTags = ref.watch(musicOnlineHotTagsProvider);
    final tree = ref.watch(musicPlaylistTagGroupsProvider);
    final sorts = ref.watch(musicPlaylistSortsProvider);
    final supported = musicCapabilityOf<OnlinePlaylists>(ref.watch(musicSourceProvider)) != null;

    final order = _order ?? sorts.firstOrNull?.id ?? '';
    final tagGroups = tree.value ?? const <MusicPlaylistTagGroup>[];
    final hotValues = [
      // The platform's own pair: the chip shows the name, the page asks by id.
      for (final tag in hotTags.value ?? const <MusicPlaylistTag>[])
        if (tag.name.trim().isNotEmpty && tag.id.isNotEmpty) tag,
    ];
    final chips = _group.isEmpty
        ? hotValues
        : tagGroups.where((group) => group.name == _group).firstOrNull?.tags ?? const <MusicPlaylistTag>[];
    final effectiveTag = _tag ?? chips.firstOrNull?.id;

    final pages = <AsyncValue<MusicPlaylistPage>>[
      if (effectiveTag != null)
        for (var page = 1; page <= _page; page++)
          ref.watch(musicOnlinePlaylistsProvider((tag: effectiveTag, order: order, page: page))),
    ];
    final items = <MusicPlaylistInfo>[
      for (final page in pages)
        if (page.value != null) ...page.value!.items,
    ];
    final loading = pages.any((page) => page.isLoading);
    final error = pages.where((page) => page.hasError).firstOrNull;
    final total = pages.lastOrNull?.value?.total ?? 0;
    // Both signals have to agree before the grid asks again: the source's word
    // on whether its answer ran out, and the count it gave — netease hands the
    // same window back past its own horizon, so an empty page alone would keep
    // appending duplicates.
    final statedMore = pages.lastOrNull?.value?.hasMore;

    // The reference's 打开歌单: a pasted link or bare id opens the
    // playlist's detail on the current source. A source that cannot serve the
    // plaza has no detail to open, so it does not get the verb either.
    final openButton = MusicToolAction(
      label: t.music.openPlaylistTitle,
      icon: DsIcons.link,
      available: supported,
      onPressed: () => unawaited(_openByLink()),
    );

    // The plaza's three condition rows — the sorts, the categories and the
    // tags — now live in one panel behind a head entry, the find page's
    // shape: the grid keeps the window's height, and what is chosen reads as
    // one line under the head. Nothing to choose is no entry at all, not a
    // greyed one.
    final hasFilters = supported && (sorts.length > 1 || tagGroups.isNotEmpty || hotValues.isNotEmpty);
    final groupLabel = _group.isEmpty ? t.music.playlistHotTags : _group;
    final summary = [
      if (sorts.length > 1)
        musicPlaylistSortLabel(t, sorts.firstWhere((sort) => sort.id == order, orElse: () => sorts.first)),
      if (tagGroups.isNotEmpty) groupLabel,
      chips.where((tag) => tag.id == effectiveTag).firstOrNull?.name ?? '',
    ].where((part) => part.isNotEmpty).join(' · ');
    final headActions = [
      openButton,
      MusicToolAction(
        label: t.music.plazaFilterTitle,
        icon: DsIcons.listFilter,
        available: hasFilters,
        onPressed: () => unawaited(
          showDsPanel<void>(
            context: context,
            builder: (_) => MusicPlazaFilterPanel(
              sorts: sorts,
              groups: tagGroups,
              hotTags: hotValues,
              order: order,
              group: _group,
              tag: effectiveTag,
              onChanged: (order, group, tag) => setState(() {
                _order = order;
                _group = group;
                _tag = tag;
                _page = 1;
              }),
            ),
          ),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: Padding(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s4),
            child: widget.showTabs
                ? MusicSonglistTabs(
                    online: true,
                    mineCount: widget.mineCount,
                    onChanged: (online) {
                      if (!online) widget.onBackToMine?.call();
                    },
                    actions: headActions,
                  )
                : Row(
                    spacing: DsSpace.s8,
                    children: [
                      Expanded(
                        child: Text(
                          widget.heading ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DsTheme.of(context).typography.title.copyWith(color: DsTheme.of(context).colors.text),
                        ),
                      ),
                      ...headActions,
                    ],
                  ),
          ),
        ),
        if (supported && summary.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
            child: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsTheme.of(context).typography.caption.copyWith(color: DsTheme.of(context).colors.textMuted),
            ),
          ),
        if (!supported)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s16, inset, DsSpace.s16),
            child: Center(
              child: DsEmptyState(icon: DsIcon(MusicView.songlists.icon), title: Text(t.music.onlineUnsupported)),
            ),
          )
        else
          Expanded(
            child: switch ((effectiveTag, hotTags, error, loading, items.isEmpty)) {
              // The tags have not named a board yet: the first page waits
              // for them, loading or honestly failed.
              (null, AsyncValue(:final isLoading), _, _, _) when isLoading => const Center(
                child: DsSpinner(style: DsSpinnerStyle(size: 28)),
              ),
              (null, AsyncValue(hasError: true), _, _, _) => Center(
                child: DsEmptyState(
                  icon: DsIcon(MusicView.songlists.icon),
                  title: Text(t.music.onlineLoadFailed),
                  actions: [
                    DsButton(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      onPressed: () => ref.invalidate(musicOnlineHotTagsProvider),
                      child: Text(t.common.retry),
                    ),
                  ],
                ),
              ),
              (_, _, _, true, _) || (_, _, _, false, false) => MusicPlaylistGrid<MusicPlaylistInfo>(
                items: items,
                isLoading: loading,
                hasMore: (statedMore ?? true) && (total == 0 || items.length < total),
                onLoadMore: () async {
                  setState(() => _page += 1);
                },
                onRefresh: () async {
                  final tag = effectiveTag;
                  if (tag == null) {
                    ref
                      ..invalidate(musicOnlineHotTagsProvider)
                      ..invalidate(musicPlaylistTagGroupsProvider);
                    return;
                  }
                  for (var page = 1; page <= _page; page++) {
                    ref.invalidate(musicOnlinePlaylistsProvider((tag: tag, order: order, page: page)));
                  }
                  setState(() => _page = 1);
                },
                itemBuilder: (context, playlist) =>
                    MusicPlaylistCard.online(info: playlist, onOpen: () => widget.onOpen(playlist)),
              ),
              (_, _, final pageError, false, true) => Center(
                child: DsEmptyState(
                  icon: DsIcon(MusicView.songlists.icon),
                  title: Text(pageError != null ? t.music.onlineLoadFailed : t.music.onlineEmpty),
                  actions: [
                    if (pageError != null)
                      DsButton(
                        variant: DsButtonVariant.secondary,
                        size: DsSize.sm,
                        onPressed: () {
                          final tag = effectiveTag;
                          if (tag == null) return;
                          for (var page = 1; page <= _page; page++) {
                            ref.invalidate(musicOnlinePlaylistsProvider((tag: tag, order: order, page: page)));
                          }
                        },
                        child: Text(t.common.retry),
                      ),
                  ],
                ),
              ),
            },
          ),
      ],
    );
  }
}

/// The plaza's conditions in one panel over the grid: the sorts, the
/// categories and the group's tags, each as its own chip row — the shape the
/// find page's selector panel uses. A pick lands in the browse at once, so
/// the grid is already thinned when the panel closes.
final class MusicPlazaFilterPanel extends StatefulWidget {
  /// The panel over the plaza listing [order] under [group] and [tag].
  const MusicPlazaFilterPanel({
    required this.sorts,
    required this.groups,
    required this.hotTags,
    required this.order,
    required this.group,
    required this.tag,
    required this.onChanged,
    super.key,
  });

  /// The plaza's sort tabs.
  final List<MusicPlazaSort> sorts;

  /// The plaza's categories, each with its tags.
  final List<MusicPlaylistTagGroup> groups;

  /// The hot tags, the category row's own first group.
  final List<MusicPlaylistTag> hotTags;

  /// The sort, category and tag the browse is on now; a null [tag] is the
  /// group's first one.
  final String order;
  final String group;
  final String? tag;

  /// Hands the browse the whole choice: the sort, the category and the tag,
  /// null when the category changed and the tag has to fall back.
  final void Function(String order, String group, String? tag) onChanged;

  @override
  State<MusicPlazaFilterPanel> createState() => _MusicPlazaFilterPanelState();
}

final class _MusicPlazaFilterPanelState extends State<MusicPlazaFilterPanel> {
  late String _order = widget.order;
  late String _group = widget.group;
  late String? _tag = widget.tag;

  /// The tags the current category names: the hot ones, then that group's.
  List<MusicPlaylistTag> get _chips => _group.isEmpty
      ? widget.hotTags
      : widget.groups.where((group) => group.name == _group).firstOrNull?.tags ?? const <MusicPlaylistTag>[];

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final effectiveTag = _tag ?? _chips.firstOrNull?.id;

    Widget row(String label, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s6,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
          ),
          Wrap(spacing: DsSpace.s8, runSpacing: DsSpace.s8, children: chips),
        ],
      ),
    );

    return DsPanel(
      title: Text(t.music.plazaFilterTitle),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [DsButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.music.plazaFilterDone))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.sorts.length > 1)
            row(t.music.plazaFilterSorts, [
              for (final sort in widget.sorts)
                DsChip(
                  label: Text(musicPlaylistSortLabel(t, sort)),
                  selected: sort.id == _order,
                  onChanged: (on) {
                    if (!on) return;
                    setState(() => _order = sort.id);
                    widget.onChanged(sort.id, _group, _tag);
                  },
                ),
            ]),
          if (widget.groups.isNotEmpty)
            row(t.music.plazaFilterGroups, [
              DsChip(
                label: Text(t.music.playlistHotTags),
                selected: _group.isEmpty,
                onChanged: (on) {
                  if (!on) return;
                  setState(() {
                    _group = '';
                    _tag = null;
                  });
                  widget.onChanged(_order, '', null);
                },
              ),
              for (final group in widget.groups)
                DsChip(
                  label: Text(group.name),
                  selected: group.name == _group,
                  onChanged: (on) {
                    if (!on) return;
                    setState(() {
                      _group = group.name;
                      _tag = null;
                    });
                    widget.onChanged(_order, group.name, null);
                  },
                ),
            ]),
          row(t.music.plazaFilterTags, [
            for (final tag in _chips)
              DsChip(
                label: Text(tag.name),
                selected: tag.id == effectiveTag,
                onChanged: (on) {
                  if (!on) return;
                  setState(() => _tag = tag.id);
                  widget.onChanged(_order, _group, tag.id);
                },
              ),
          ]),
        ],
      ),
    );
  }
}

/// One online playlist opened to its tracks: import it into the viewer's
/// own lists (LX's behaviour — the online list lands as a local one), or
/// play straight from here.
final class MusicOnlinePlaylistDetail extends ConsumerWidget {
  const MusicOnlinePlaylistDetail({required this.info, required this.onBack, super.key});

  final MusicPlaylistInfo info;
  final VoidCallback onBack;

  Future<void> _import(BuildContext context, WidgetRef ref, List<audio.MusicTrack> tracks) async {
    final t = context.t;
    final controller = ref.read(musicPlaylistsProvider.notifier);
    final sourceId = ref.read(musicSourceProvider).id;
    // The reference's duplicate check: a second 收藏 of the same online
    // list offers to refresh what is already there.
    final existing = controller.findLinked(sourceId, info.id);
    if (existing != null) {
      final confirmed = await showDsDialog<bool>(
        context: context,
        builder: (context) => DsDialog(
          title: Text(t.music.playlistUpdateOnline),
          description: Text(t.music.duplicateListTip(name: existing.name)),
          actions: [
            DsButton(
              variant: DsButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t.common.cancel),
            ),
            DsButton(onPressed: () => Navigator.of(context).pop(true), child: Text(t.common.confirm)),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      ref.invalidate(musicOnlinePlaylistDetailProvider(info.id));
      final (_, fresh) = await ref.read(musicOnlinePlaylistDetailProvider(info.id).future);
      final count = await controller.replaceTracks(existing.id, fresh);
      if (!context.mounted) return;
      showDsToast(
        context: context,
        title: t.music.onlineUpdatedToast(name: existing.name, count: count),
        status: DsStatus.success,
      );
      return;
    }
    final playlist = await controller.create(info.name);
    if (playlist == null) return;
    // The reference's collected list carries its origin (`source` +
    // `sourceListId`) so a later pass can pull the online list afresh.
    await controller.linkSource(playlist.id, source: sourceId, sourceListId: info.id);
    final added = await controller.addTracks(playlist.id, tracks);
    if (!context.mounted) return;
    showDsToast(
      context: context,
      title: t.music.onlineImported(name: playlist.name, count: added),
      status: added > 0 ? DsStatus.success : DsStatus.warning,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    // The page's gutter, the same measure the live module's pages keep.
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final detail = ref.watch(musicOnlinePlaylistDetailProvider(info.id));
    final player = ref.read(musicPlayerProvider.notifier);
    final favourites = ref.watch(musicFavouritesProvider);
    final favouritesController = ref.read(musicFavouritesProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The back row the playlist details share: back, the rail's name,
        // and the import verb following — it only draws once the platform
        // has answered with tracks to take.
        MusicDetailBackRow(
          title: t.music.songlistTabOnline,
          onBack: onBack,
          actions: [
            detail.when(
              skipLoadingOnReload: true,
              data: (entry) {
                final (_, tracks) = entry;
                return MusicToolAction(
                  label: t.music.onlineImport,
                  icon: DsIcons.plus,
                  available: tracks.isNotEmpty,
                  onPressed: () => unawaited(_import(context, ref, tracks)),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (error, stackTrace) => const SizedBox.shrink(),
            ),
          ],
        ),
        Expanded(
          child: detail.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28))),
            error: (error, stackTrace) => Center(
              child: DsEmptyState(icon: DsIcon(MusicView.songlists.icon), title: Text(t.music.onlineLoadFailed)),
            ),
            data: (entry) {
              final (info, tracks) = entry;
              if (tracks.isEmpty) {
                return Center(
                  child: DsEmptyState(icon: DsIcon(MusicView.songlists.icon), title: Text(t.music.onlineEmpty)),
                );
              }
              final first = tracks.firstOrNull;
              final total = tracks.fold<Duration>(Duration.zero, (sum, song) => sum + (song.duration ?? Duration.zero));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The detail head's rhythm, the mockup's measure: the
                  // cover leads, the name and its facts line follow, and the
                  // play verbs close the block — bottom-set so the verbs sit
                  // on the cover's edge.
                  Padding(
                    padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      spacing: DsSpace.s16,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(theme.radii.card),
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: first == null
                                ? CoverFallback(title: info.name)
                                : DsImage(
                                    image: first.coverUri == null ? null : cachedImage(first.coverUri.toString()),
                                    aspectRatio: 1,
                                    semanticLabel: info.name,
                                    fallback: CoverFallback(title: first.title),
                                  ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: DsSpace.s4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: DsSpace.s6,
                              children: [
                                Text(
                                  info.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.typography.heading.copyWith(color: colors.text),
                                ),
                                Text(
                                  // Creator, plays, size, length — each part only
                                  // when the platform said it, so the line never
                                  // opens with a bare separator.
                                  [
                                    if (info.author.isNotEmpty) info.author,
                                    if (info.playCount > 0)
                                      t.music.playsCount(count: AudienceFormat.format(info.playCount)),
                                    t.music.songsCount(count: tracks.length),
                                    if (total > Duration.zero) musicDurationText(total),
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                                ),
                                const SizedBox(height: DsSpace.s4),
                                Wrap(
                                  spacing: DsSpace.s8,
                                  runSpacing: DsSpace.s8,
                                  children: [
                                    DsButton(
                                      variant: DsButtonVariant.primary,
                                      size: DsSize.sm,
                                      leading: const DsIcon(DsIcons.play, size: 16),
                                      onPressed: () => unawaited(player.playAll(tracks)),
                                      child: Text(t.music.playAll),
                                    ),
                                    DsButton(
                                      variant: DsButtonVariant.secondary,
                                      size: DsSize.sm,
                                      leading: const DsIcon(DsIcons.shuffle, size: 16),
                                      onPressed: () => unawaited(player.playAll([...tracks]..shuffle(math.Random()))),
                                      child: Text(t.music.modeRandom),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: DsSpace.s16),
                      itemCount: tracks.length + 1,
                      itemBuilder: (context, offset) {
                        if (offset == 0) return const MusicSongTableHeader();
                        final index = offset - 1;
                        final song = tracks[index];
                        return MusicSongRow(
                          track: song,
                          number: index + 1,
                          playing: false,
                          favourite: favourites.contains(song),
                          subtitle: musicTrackCredits(song),
                          onPlay: () => unawaited(player.playAll(tracks, index: index)),
                          onFavourite: () => unawaited(favouritesController.toggle(song)),
                          onAddToPlaylist: () => unawaited(showAddToPlaylistDialog(context, ref, song)),
                          onDownload: () => unawaited(downloadTrackWithToast(context, ref, song, listName: info.name)),
                          onToggleSource: () => unawaited(showToggleSourceDialog(context, ref, song)),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The reference's 重复歌曲 dialog: duplicate titles in one playlist, each
/// removable in place, with a sweep that keeps the first of every group.
