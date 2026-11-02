import 'dart:async' show unawaited;
import 'dart:io' show File;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker, FileType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/app/providers/boot/storage_providers.dart' show appPathsProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_downloads.dart' show musicDownloadsProvider;
import 'package:pure_live/modules/music/controller/music_library.dart' show musicFavouritesProvider;
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/music_playback_settings.dart'
    show musicPlaybackSettingsProvider, musicSourceDisplayName;
import 'package:pure_live/modules/music/controller/music_playlists.dart';
import 'package:pure_live/modules/music/controller/music_source.dart' show musicSourceListProvider;
import 'package:pure_live/modules/music/controller/sources/music_browse_source.dart' show musicCapabilityOf;
import 'package:pure_live/modules/music/controller/sources/online_playlist_models.dart'
    show MusicPlaylistInfo, OnlinePlaylists;
import 'package:pure_live/modules/music/pages/music_online_playlists_view.dart';
import 'package:pure_live/modules/music/pages/music_playlist_card.dart'
    show MusicCardMenuButton, MusicPlaylistCard, MusicPlaylistGrid;
import 'package:pure_live/modules/music/widgets/music_actions.dart';
import 'package:pure_live/modules/music/widgets/music_browse_widgets.dart' show MusicToolAction;
import 'package:pure_live/modules/music/widgets/music_widgets.dart';
import 'package:pure_live/shared/shared.dart' show CoverFallback, cachedImage;

final class MusicPlaylistsView extends ConsumerStatefulWidget {
  const MusicPlaylistsView({this.initialOnlineOpen, super.key});

  /// The online playlist a caller (the library's 歌单 search) asked to
  /// open; consumed once the view mounts.
  final MusicPlaylistInfo? initialOnlineOpen;

  @override
  ConsumerState<MusicPlaylistsView> createState() => MusicPlaylistsViewState();
}

final class MusicPlaylistsViewState extends ConsumerState<MusicPlaylistsView> {
  String? _openId;
  bool _selecting = false;
  final Set<audio.MusicTrack> _selected = <audio.MusicTrack>{};

  /// Whether a tap picks the span up to it — the reference's 区间 — instead
  /// of toggling one row (单选).
  bool _rangeMode = false;

  /// The row a span is measured from — the reference's prevSelectIndex.
  int? _anchor;

  /// Whether the in-list search bar (the reference's 列表内搜索) is open.
  bool _searching = false;
  TextEditingController? _searchField;

  /// Whether the view browses the source's online playlists (在线歌单)
  /// instead of the viewer's own lists; LX keeps both behind one rail.
  bool _online = false;

  /// The online playlist opened to its tracks; null shows the browse list.
  MusicPlaylistInfo? _onlineOpen;

  @override
  void initState() {
    super.initState();
    final open = widget.initialOnlineOpen;
    if (open != null) {
      _online = true;
      _onlineOpen = open;
    }
  }

  @override
  void dispose() {
    _searchField?.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      if (_searching) {
        _searching = false;
        final dead = _searchField;
        _searchField = null;
        if (dead != null) {
          // The field leaves the tree with this rebuild; dispose it after.
          WidgetsBinding.instance.addPostFrameCallback((_) => dead.dispose());
        }
      } else {
        _searching = true;
        _searchField = TextEditingController()..addListener(_onSearchChanged);
      }
    });
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _create() async {
    final playlist = await showCreatePlaylistDialog(context, ref);
    if (playlist != null && mounted) {
      setState(() {
        _openId = playlist.id;
        _selecting = false;
        _selected.clear();
      });
    }
  }

  /// The reference's 更新: the linked plaza is asked afresh and the list's
  /// tracks are overwritten with the answer.
  Future<void> _updateOnline(MusicPlaylist playlist) async {
    final t = context.t;
    final linked = playlist.source;
    final sourceListId = playlist.sourceListId;
    if (linked == null || sourceListId == null) return;
    final plaza = [
      for (final source in ref.read(musicSourceListProvider))
        if (source.id == linked) source,
    ].firstOrNull;
    if (!mounted) return;
    if (plaza == null) {
      showDsToast(context: context, title: t.music.onlineUpdateFailed, status: DsStatus.warning);
      return;
    }
    try {
      // The reference's syncSourceList: a board link re-routes to the
      // leaderboard fetcher, everything else to the plaza's detail — which
      // the platform carries under its lyric wrappers, so it is the walk's
      // answer that is asked, not the decorated source itself.
      final detail = musicCapabilityOf<OnlinePlaylists>(plaza);
      final tracks = await switch ((sourceListId.startsWith('board__'), detail)) {
        (true, _) =>
          plaza
              .catalogItems(
                audio.MusicCatalog(id: '$linked:${sourceListId.substring('board__'.length)}', name: playlist.name),
              )
              .then((answer) => answer.items),
        (false, final plazaDetail?) => plazaDetail.playlistDetail(sourceListId).then((entry) => entry.$2),
        (false, null) => throw StateError('${plaza.id} has no online playlists'),
      };
      final count = await ref.read(musicPlaylistsProvider.notifier).replaceTracks(playlist.id, tracks);
      if (!mounted) return;
      showDsToast(
        context: context,
        title: t.music.onlineUpdatedToast(name: playlist.name, count: count),
        status: DsStatus.success,
      );
    } on Object {
      if (!mounted) return;
      showDsToast(context: context, title: t.music.onlineUpdateFailed, status: DsStatus.warning);
    }
  }

  Future<void> _rename(MusicPlaylist playlist) async {
    final t = context.t;
    final field = TextEditingController(text: playlist.name);
    final name = await showDsDialog<String>(
      context: context,
      builder: (context) => DsDialog(
        title: Text(t.music.playlistRenameTitle),
        icon: const DsIcon(DsIcons.pencil),
        description: DsTextField(
          controller: field,
          autofocus: true,
          clearable: true,
          semanticLabel: t.music.playlistName,
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
    if (name == null || name.trim().isEmpty || !mounted) return;
    await ref.read(musicPlaylistsProvider.notifier).rename(playlist.id, name);
  }

  Future<void> _downloadAll(MusicPlaylist playlist) async {
    final t = context.t;
    final queued = await ref
        .read(musicDownloadsProvider.notifier)
        .downloadAll(playlist.tracks, listName: playlist.name);
    if (!mounted) return;
    showDsToast(
      context: context,
      title: t.music.downloadAllQueued(count: queued),
      status: queued > 0 ? DsStatus.success : DsStatus.warning,
    );
  }

  Future<void> _delete(MusicPlaylist playlist) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.music.playlistDeleteTitle(name: playlist.name),
      description: t.music.playlistDeleteDesc,
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(musicPlaylistsProvider.notifier).delete(playlist.id);
    if (mounted) {
      setState(() {
        _openId = null;
        _selecting = false;
        _selected.clear();
      });
    }
  }

  /// Reads a playlist file the viewer picked; a `.lxmc` list backup lands
  /// through the reference's merge rules, a module json as a new playlist.
  Future<void> _import() async {
    final t = context.t;
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: t.music.playlistImport,
        type: FileType.custom,
        allowedExtensions: const ['json', 'lxmc'],
      );
      final path = file?.path;
      if (!mounted || path == null) return;
      if (path.toLowerCase().endsWith('.lxmc')) {
        await _importLxmc(path);
        return;
      }
      final playlist = await ref.read(musicPlaylistsProvider.notifier).importFromFile(path);
      if (playlist == null) {
        // A json copy of an lx-music backup is plain JSON — route it too.
        await _importLxmc(path);
        return;
      }
      if (!mounted) return;
      showDsToast(
        context: context,
        title: t.music.playlistImportDone(name: playlist.name),
        status: DsStatus.success,
      );
      setState(() {
        _openId = playlist.id;
        _selecting = false;
        _selected.clear();
      });
    } on Object catch (failure) {
      if (mounted) {
        showDsToast(
          context: context,
          title: t.music.playlistImportFailed(error: '$failure'),
          status: DsStatus.danger,
        );
      }
    }
  }

  /// The reference's list-backup import: confirm the overwrite rule, then
  /// merge the backup's lists in.
  Future<void> _importLxmc(String path) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.music.playlistImport,
      description: t.music.playlistImportLxmcConfirm,
      confirmLabel: t.common.confirm,
      cancelLabel: t.common.cancel,
    );
    if (!confirmed || !mounted) return;
    final report = await ref.read(musicPlaylistsProvider.notifier).importLxmcFile(path);
    if (!mounted) return;
    if (report == null) {
      showDsToast(
        context: context,
        title: t.music.playlistImportFailed(error: t.music.playlistImportLxmcUnsupported),
        status: DsStatus.danger,
      );
      return;
    }
    showDsToast(
      context: context,
      title: t.music.playlistImportLxmcDone(lists: report.added + report.overwritten, songs: report.songs),
      status: DsStatus.success,
    );
  }

  /// Writes a playlist into the download folder the module already uses.
  Future<void> _export(MusicPlaylist playlist) async {
    final t = context.t;
    try {
      final directory = ref.read(appPathsProvider).music.path;
      final path = await ref.read(musicPlaylistsProvider.notifier).exportToDirectory(playlist, directory);
      if (mounted) {
        showDsToast(
          context: context,
          title: t.music.playlistExportDone(path: path),
          status: DsStatus.success,
        );
      }
    } on Object catch (failure) {
      if (mounted) {
        showDsToast(
          context: context,
          title: t.music.playlistExportFailed(error: '$failure'),
          status: DsStatus.danger,
        );
      }
    }
  }

  /// The reference's 重复歌曲 dialog: duplicate titles in one list, picked
  /// ones removable in place.
  Future<void> _showDuplicates(MusicPlaylist playlist) async {
    await showDsDialog<bool>(
      context: context,
      builder: (context) => _DuplicateTracksDialog(playlistId: playlist.id),
    );
  }

  /// The reference's 添加本地歌曲: the audio files picked in the dialog join
  /// the list, with the local library's own scan semantics.
  Future<void> _addLocalSongs(MusicPlaylist playlist) async {
    final t = context.t;
    final picked = await FilePicker.pickFiles(
      dialogTitle: t.music.playlistAddLocalDesc,
      type: FileType.custom,
      allowedExtensions: audio.LocalMusicSource.defaultExtensions,
    );
    final paths = [for (final file in picked) ?file.path];
    if (paths.isEmpty || !mounted) return;
    final tracks = [for (final path in paths) await _localTrackFromFile(path)];
    final added = await ref.read(musicPlaylistsProvider.notifier).addTracks(playlist.id, tracks);
    if (!mounted) return;
    if (added > 0) {
      showDsToast(
        context: context,
        title: t.music.playlistAddLocalDone(count: added),
        status: DsStatus.success,
      );
    } else {
      showDsToast(context: context, title: t.music.playlistAddLocalNone, status: DsStatus.warning);
    }
  }

  /// Builds a track from a local file the way the local library's scanner
  /// does: tags name it, the file name answers when the tags are missing or
  /// unreadable — a picked file is never dropped.
  Future<audio.MusicTrack> _localTrackFromFile(String path) async {
    final separator = path.lastIndexOf(RegExp(r'[\\/]'));
    final fileName = separator >= 0 ? path.substring(separator + 1) : path;
    final dot = fileName.lastIndexOf('.');
    final title = dot > 0 ? fileName.substring(0, dot) : fileName;

    audio.AudioTag tag;
    try {
      tag = await const audio.AudioTagReader().read(File(path));
    } on Object {
      tag = audio.AudioTag.empty;
    }
    String? clean(String? value) {
      final trimmed = value?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    }

    return audio.MusicTrack(
      id: path,
      sourceId: audio.MusicTrack.localSourceId,
      localPath: path,
      title: clean(tag.title) ?? title,
      artist: clean(tag.artist) ?? '',
      album: clean(tag.album) ?? '',
      duration: tag.duration,
      metadata: <String, Object?>{
        if (tag.trackNumber != null) 'trackNumber': tag.trackNumber,
        if (tag.year != null) 'year': tag.year,
      },
    );
  }

  /// Enters or leaves the reference's multi-selection.
  void _setSelecting({required bool selecting}) {
    setState(() {
      _selecting = selecting;
      if (!selecting) {
        _rangeMode = false;
        _anchor = null;
        _selected.clear();
      }
    });
  }

  void _toggleSelected(audio.MusicTrack track, int index) {
    setState(() {
      if (!_selected.remove(track)) _selected.add(track);
      _anchor = index;
    });
  }

  /// The reference's 区间 tap: it replaces the selection with the span from
  /// the anchor to the tapped row; the first tap just picks one and a tap on
  /// the anchor itself clears — and only those two move the anchor.
  void _selectRange(List<audio.MusicTrack> tracks, int index) {
    setState(() {
      final anchor = _anchor;
      if (anchor == null || _selected.isEmpty) {
        _selected
          ..clear()
          ..add(tracks[index]);
        _anchor = index;
      } else if (anchor == index) {
        _selected.clear();
      } else {
        final start = anchor < index ? anchor : index;
        final end = anchor < index ? index : anchor;
        _selected
          ..clear()
          ..addAll(tracks.sublist(start, end + 1));
      }
    });
  }

  /// The reference's 全选/反选 toggle: with everything picked, the tap clears.
  void _toggleSelectAll(MusicPlaylist playlist) {
    setState(() {
      if (_selected.length == playlist.tracks.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(playlist.tracks);
      }
    });
  }

  /// The reference's 调整位置: a position number moves the selection there.
  Future<void> _moveSelected(MusicPlaylist playlist) async {
    final tracks = List<audio.MusicTrack>.of(_selected);
    if (tracks.isEmpty) return;
    final t = context.t;
    final field = TextEditingController();
    final answer = await showDsDialog<String>(
      context: context,
      builder: (context) => DsDialog(
        title: Text(t.music.repositionTitle(count: tracks.length)),
        icon: const DsIcon(DsIcons.arrowUpDown),
        description: DsTextField(
          controller: field,
          autofocus: true,
          clearable: true,
          placeholder: t.music.repositionHint,
          semanticLabel: t.music.selectionReposition,
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
    final position = int.tryParse(answer?.trim() ?? '');
    if (position == null || !mounted) return;
    await ref.read(musicPlaylistsProvider.notifier).moveTracksTo(playlist.id, tracks, position);
    if (!mounted) return;
    _setSelecting(selecting: false);
  }

  Future<void> _removeSelected(MusicPlaylist playlist) async {
    final tracks = List<audio.MusicTrack>.of(_selected);
    if (tracks.isEmpty) return;
    final t = context.t;
    await ref.read(musicPlaylistsProvider.notifier).removeTracks(playlist.id, tracks);
    if (!mounted) return;
    showDsToast(
      context: context,
      title: t.music.selectionRemoveDone(count: tracks.length),
      status: DsStatus.success,
    );
    _setSelecting(selecting: false);
  }

  Future<void> _downloadSelected(MusicPlaylist playlist) async {
    final tracks = List<audio.MusicTrack>.of(_selected);
    if (tracks.isEmpty) return;
    final t = context.t;
    final queued = await ref.read(musicDownloadsProvider.notifier).downloadAll(tracks, listName: playlist.name);
    if (!mounted) return;
    showDsToast(
      context: context,
      title: t.music.downloadAllQueued(count: queued),
      status: queued > 0 ? DsStatus.success : DsStatus.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final playlists = ref.watch(musicPlaylistsProvider);
    final open = _openId == null ? null : playlists.where((playlist) => playlist.id == _openId).firstOrNull;
    if (open != null) return _playlistDetail(open);
    if (_onlineOpen != null) {
      return MusicOnlinePlaylistDetail(info: _onlineOpen!, onBack: () => setState(() => _onlineOpen = null));
    }
    if (_online) {
      return MusicOnlinePlaylistBrowse(
        mineCount: playlists.length,
        onOpen: (info) => setState(() => _onlineOpen = info),
        onBackToMine: () => setState(() => _online = false),
      );
    }

    final tabs = MusicSonglistTabs(
      online: _online,
      mineCount: playlists.length,
      onChanged: (online) {
        setState(() {
          _online = online;
          _onlineOpen = null;
        });
      },
    );

    // One toolbar row, the areas page's measure: the tabs take the leftover
    // width, the count and the verbs close the row.
    final Widget toolbar = SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s4),
        child: Row(
          spacing: DsSpace.s8,
          children: [
            Expanded(child: tabs),
            if (!_online)
              Text(
                t.music.playlistsCount(count: playlists.length),
                style: theme.typography.caption.copyWith(color: colors.textSubtle),
              ),
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              leading: const DsIcon(DsIcons.arrowDownToLine, size: 16),
              onPressed: () => unawaited(_import()),
              child: Text(t.music.playlistImport),
            ),
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              leading: const DsIcon(DsIcons.plus, size: 16),
              onPressed: () => unawaited(_create()),
              child: Text(t.music.playlistCreate),
            ),
          ],
        ),
      ),
    );

    if (playlists.isEmpty && !_online) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          toolbar,
          Expanded(
            child: Center(
              child: DsEmptyState(
                icon: const DsIcon(DsIcons.listMusic),
                title: Text(t.music.playlistsEmptyTitle),
                description: Text(t.music.playlistsEmptyDescription),
                actions: [
                  DsButton(
                    leading: const DsIcon(DsIcons.plus, size: 16),
                    onPressed: () => unawaited(_create()),
                    child: Text(t.music.playlistCreate),
                  ),
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    leading: const DsIcon(DsIcons.arrowDownToLine, size: 16),
                    onPressed: () => unawaited(_import()),
                    child: Text(t.music.playlistImport),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        toolbar,
        Expanded(
          child: MusicPlaylistGrid<MusicPlaylist>(
            items: playlists,
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
            itemBuilder: (context, playlist) => MusicPlaylistCard.own(
              playlist: playlist,
              onOpen: () => setState(() {
                _openId = playlist.id;
                _selecting = false;
                _selected.clear();
              }),
              menuBuilder: (context) => MusicCardMenuButton(
                semanticLabel: t.music.moreActions,
                items: [
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.play),
                    label: Text(t.music.play),
                    onPressed: playlist.tracks.isEmpty
                        ? null
                        : () => unawaited(ref.read(musicPlayerProvider.notifier).playAll(playlist.tracks)),
                  ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.pencil),
                    label: Text(t.music.playlistRename),
                    onPressed: () => unawaited(_rename(playlist)),
                  ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.arrowUpFromLine),
                    label: Text(t.music.playlistExport),
                    onPressed: playlist.tracks.isEmpty ? null : () => unawaited(_export(playlist)),
                  ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.copy),
                    label: Text(t.music.duplicateTracks),
                    onPressed: playlist.tracks.isEmpty ? null : () => unawaited(_showDuplicates(playlist)),
                  ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.folderPlus),
                    label: Text(t.music.playlistAddLocal),
                    onPressed: () => unawaited(_addLocalSongs(playlist)),
                  ),
                  if (playlist.source != null && playlist.sourceListId != null)
                    DsMenuItem(
                      leading: const DsIcon(DsIcons.refreshCw),
                      label: Text(t.music.playlistUpdateOnline),
                      onPressed: () => unawaited(_updateOnline(playlist)),
                    ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.trash2),
                    label: Text(t.music.playlistDelete),
                    destructive: true,
                    onPressed: () => unawaited(_delete(playlist)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _playlistDetail(MusicPlaylist playlist) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final playingId = ref.watch(musicPlayerProvider.select((state) => state.track?.id));
    final player = ref.read(musicPlayerProvider.notifier);
    final favourites = ref.watch(musicFavouritesProvider);
    final favouritesController = ref.read(musicFavouritesProvider.notifier);
    final controller = ref.read(musicPlaylistsProvider.notifier);
    final first = playlist.tracks.firstOrNull;
    final total = playlist.tracks.fold<Duration>(Duration.zero, (sum, song) => sum + (song.duration ?? Duration.zero));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s8, 0, DsSpace.s20, 0),
          child: Row(
            spacing: DsSpace.s8,
            children: [
              DsButton.icon(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                semanticLabel: t.common.back,
                onPressed: () => setState(() {
                  _openId = null;
                  _selecting = false;
                  _selected.clear();
                }),
                icon: const DsIcon(DsIcons.chevronLeft),
              ),
              const Spacer(),
              MusicToolAction(
                label: t.music.listSearch,
                icon: DsIcons.search,
                available: playlist.tracks.isNotEmpty,
                onPressed: _toggleSearch,
              ),
              MusicToolAction(
                label: _selecting ? t.music.selectionCancel : t.music.selectionStart,
                icon: _selecting ? DsIcons.x : DsIcons.listChecks,
                available: playlist.tracks.isNotEmpty,
                onPressed: () => _setSelecting(selecting: !_selecting),
              ),
              DsMenuAnchor(
                semanticLabel: t.music.moreActions,
                items: [
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.download),
                    label: Text(t.music.downloadAll),
                    onPressed: playlist.tracks.isEmpty ? null : () => unawaited(_downloadAll(playlist)),
                  ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.upload),
                    label: Text(t.music.playlistExport),
                    onPressed: playlist.tracks.isEmpty ? null : () => unawaited(_export(playlist)),
                  ),
                  DsMenuItem.submenu(
                    leading: const DsIcon(DsIcons.arrowUpDown),
                    label: Text(t.music.playlistSort),
                    submenu: [
                      DsMenuItem(
                        label: Text(t.music.sortByTitle),
                        onPressed: () => unawaited(controller.sortTracks(playlist.id, MusicPlaylistSort.title)),
                      ),
                      DsMenuItem(
                        label: Text(t.music.sortByArtist),
                        onPressed: () => unawaited(controller.sortTracks(playlist.id, MusicPlaylistSort.artist)),
                      ),
                      DsMenuItem(
                        label: Text(t.music.sortByAlbum),
                        onPressed: () => unawaited(controller.sortTracks(playlist.id, MusicPlaylistSort.album)),
                      ),
                      DsMenuItem(
                        label: Text(t.music.sortByDuration),
                        onPressed: () => unawaited(controller.sortTracks(playlist.id, MusicPlaylistSort.duration)),
                      ),
                      DsMenuItem(
                        label: Text(t.music.sortByShuffle),
                        onPressed: () => unawaited(controller.sortTracks(playlist.id, MusicPlaylistSort.shuffle)),
                      ),
                    ],
                  ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.pencil),
                    label: Text(t.music.playlistRename),
                    onPressed: () => unawaited(_rename(playlist)),
                  ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.x),
                    label: Text(t.music.playlistClear),
                    onPressed: () => unawaited(controller.clear(playlist.id)),
                  ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.trash2),
                    label: Text(t.music.playlistDelete),
                    destructive: true,
                    onPressed: () => unawaited(_delete(playlist)),
                  ),
                ],
                builder: (context, controller, _) => DsButton.icon(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  semanticLabel: t.music.moreActions,
                  onPressed: controller.toggle,
                  icon: const DsIcon(DsIcons.ellipsisVertical, size: 16),
                ),
              ),
            ],
          ),
        ),
        // The album page's header, the module's dialect: the art leads, the
        // name and its numbers follow, and the play verbs close the block —
        // the toolbar above keeps the list's own verbs.
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s8),
          child: Row(
            spacing: DsSpace.s16,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(theme.radii.card),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: first == null
                      ? CoverFallback(title: playlist.name)
                      : DsImage(
                          image: first.coverUri == null ? null : cachedImage(first.coverUri.toString()),
                          aspectRatio: 1,
                          semanticLabel: playlist.name,
                          fallback: CoverFallback(title: first.title),
                        ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s4,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.heading.copyWith(color: colors.text),
                    ),
                    Text(
                      total > Duration.zero
                          ? '${t.music.songsCount(count: playlist.tracks.length)} · ${musicDurationText(total)}'
                          : t.music.songsCount(count: playlist.tracks.length),
                      style: theme.typography.caption.copyWith(color: colors.textSubtle),
                    ),
                    Row(
                      spacing: DsSpace.s8,
                      children: [
                        DsButton(
                          variant: DsButtonVariant.primary,
                          size: DsSize.sm,
                          leading: const DsIcon(DsIcons.play, size: 16),
                          onPressed: playlist.tracks.isEmpty ? null : () => unawaited(player.playAll(playlist.tracks)),
                          child: Text(t.music.playAll),
                        ),
                        DsButton(
                          variant: DsButtonVariant.secondary,
                          size: DsSize.sm,
                          leading: const DsIcon(DsIcons.shuffle, size: 16),
                          onPressed: playlist.tracks.isEmpty
                              ? null
                              : () => unawaited(player.playAll([...playlist.tracks]..shuffle(math.Random()))),
                          child: Text(t.music.modeRandom),
                        ),
                        // The reference's header row: the whole list can be
                        // taken offline from here, not only from the menu.
                        DsButton(
                          variant: DsButtonVariant.secondary,
                          size: DsSize.sm,
                          leading: const DsIcon(DsIcons.download, size: 16),
                          onPressed: playlist.tracks.isEmpty ? null : () => unawaited(_downloadAll(playlist)),
                          child: Text(t.music.downloadAll),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
            child: DsTextField(
              controller: _searchField,
              autofocus: true,
              clearable: true,
              placeholder: t.music.listSearch,
              semanticLabel: t.music.listSearch,
            ),
          ),
        if (_selecting)
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
            // The selection's verbs wrap: the mode switch and six labelled
            // buttons never share one row down to the window's 300 px floor.
            child: Wrap(
              spacing: DsSpace.s8,
              runSpacing: DsSpace.s8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DsSegmentedControl<bool>(
                  value: _rangeMode,
                  onChanged: (value) => setState(() => _rangeMode = value),
                  segments: [
                    DsSegment(value: false, label: Text(t.music.selectionSingle)),
                    DsSegment(value: true, label: Text(t.music.selectionRange)),
                  ],
                ),
                Text(
                  t.music.selectionCount(count: _selected.length),
                  style: theme.typography.caption.copyWith(color: colors.textSubtle),
                ),
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () => _toggleSelectAll(playlist),
                  child: Text(
                    _selected.length == playlist.tracks.length ? t.music.selectionInvert : t.music.selectionAll,
                  ),
                ),
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.listMusic, size: 16),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => unawaited(showAddTracksToPlaylistDialog(context, ref, _selected.toList())),
                  child: Text(t.music.addToPlaylist),
                ),
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.download, size: 16),
                  onPressed: _selected.isEmpty ? null : () => unawaited(_downloadSelected(playlist)),
                  child: Text(t.music.selectionDownload),
                ),
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.arrowRightLeft, size: 16),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => unawaited(showMoveTracksToPlaylistDialog(context, ref, playlist.id, _selected.toList())),
                  child: Text(t.music.selectionMoveTo),
                ),
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: _selected.isEmpty ? null : () => unawaited(_moveSelected(playlist)),
                  child: Text(t.music.selectionReposition),
                ),
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: _selected.isEmpty ? null : () => unawaited(_removeSelected(playlist)),
                  child: Text(t.music.selectionRemove),
                ),
              ],
            ),
          ),
        Expanded(
          child: Builder(
            builder: (context) {
              final query = _searching ? (_searchField?.text.trim() ?? '') : '';
              final hits = query.isEmpty ? null : searchPlaylistTrackIndexes(playlist.tracks, query);
              if (playlist.tracks.isEmpty) {
                return Center(
                  child: DsEmptyState(
                    icon: const DsIcon(DsIcons.listMusic),
                    title: Text(t.music.playlistEmptyTitle),
                    description: Text(t.music.playlistEmptyDescription),
                  ),
                );
              }
              if (hits != null && hits.isEmpty) {
                return Center(
                  child: DsEmptyState(icon: const DsIcon(DsIcons.searchX), title: Text(t.music.listSearchEmpty)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: DsSpace.s16),
                itemCount: (hits?.length ?? playlist.tracks.length) + 1,
                itemBuilder: (context, offset) {
                  if (offset == 0) return const MusicSongTableHeader();
                  final position = offset - 1;
                  final index = hits?[position] ?? position;
                  final song = playlist.tracks[index];
                  final searching = hits != null;
                  return MusicSongRow(
                    track: song,
                    number: position + 1,
                    playing: playingId == song.id,
                    favourite: favourites.contains(song),
                    selecting: _selecting,
                    selected: _selected.contains(song),
                    onSelected: _rangeMode
                        ? () => _selectRange(playlist.tracks, index)
                        : () => _toggleSelected(song, index),
                    onPlay: () => unawaited(player.playAll(playlist.tracks, index: index)),
                    onFavourite: () => unawaited(favouritesController.toggle(song)),
                    onRemove: () => unawaited(controller.removeTrack(playlist.id, song)),
                    onPlayNext: () => unawaited(player.playNext(song)),
                    onAddToPlaylist: () => unawaited(showAddToPlaylistDialog(context, ref, song)),
                    onDownload: () => unawaited(downloadTrackWithToast(context, ref, song, listName: playlist.name)),
                    onToggleSource: () => unawaited(
                      showToggleSourceDialog(
                        context,
                        ref,
                        song,
                        onSwapped: (swapped) => unawaited(controller.replaceTrack(playlist.id, song, swapped)),
                      ),
                    ),
                    onMoveUp: searching || index == 0
                        ? null
                        : () => unawaited(controller.moveTrack(playlist.id, index, index - 1)),
                    onMoveDown: searching || index == playlist.tracks.length - 1
                        ? null
                        : () => unawaited(controller.moveTrack(playlist.id, index, index + 1)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The 歌单 rail's two tabs: the viewer's own lists and the source's online
/// playlists (在线歌单), the way LX keeps both behind one view.
final class _DuplicateTracksDialog extends ConsumerStatefulWidget {
  const _DuplicateTracksDialog({required this.playlistId});

  final String playlistId;

  @override
  ConsumerState<_DuplicateTracksDialog> createState() => _DuplicateTracksDialogState();
}

final class _DuplicateTracksDialogState extends ConsumerState<_DuplicateTracksDialog> {
  Future<void> _remove(List<audio.MusicTrack> tracks) async {
    final count = tracks.length;
    if (count == 0) return;
    await ref.read(musicPlaylistsProvider.notifier).removeTracks(widget.playlistId, tracks);
    if (!mounted) return;
    showDsToast(
      context: context,
      title: context.t.music.selectionRemoveDone(count: count),
      status: DsStatus.success,
    );
  }

  void _play(audio.MusicTrack track, List<audio.MusicTrack> tracks) {
    final index = tracks.indexOf(track);
    if (index >= 0) unawaited(ref.read(musicPlayerProvider.notifier).playAll(tracks, index: index));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    MusicPlaylist? playlist;
    for (final candidate in ref.watch(musicPlaylistsProvider)) {
      if (candidate.id == widget.playlistId) playlist = candidate;
    }
    final tracks = playlist?.tracks ?? const <audio.MusicTrack>[];
    final groups = duplicateTrackGroups(tracks);
    final duplicates = [for (final group in groups) ...group];
    final extras = [for (final group in groups) ...group.skip(1)];
    final settings = ref.watch(musicPlaybackSettingsProvider);
    final sourceNames = {
      for (final source in ref.watch(musicSourceListProvider))
        source.id: musicSourceDisplayName(t, settings.sourceNameType, source.id, source.name),
    };
    final playingId = ref.watch(musicPlayerProvider.select((state) => state.track?.id));
    final favourites = ref.watch(musicFavouritesProvider);
    return DsDialog(
      title: Text(playlist?.name ?? t.music.duplicateTracks),
      icon: const DsIcon(DsIcons.copy),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          Text(
            t.music.duplicatesFound(count: duplicates.length),
            style: theme.typography.caption.copyWith(color: colors.textSubtle),
          ),
          SizedBox(
            height: 360,
            child: duplicates.isEmpty
                ? Center(
                    child: Text(t.music.duplicatesNone, style: theme.typography.body.copyWith(color: colors.textMuted)),
                  )
                : ListView.builder(
                    itemCount: duplicates.length,
                    itemBuilder: (context, index) {
                      final track = duplicates[index];
                      final source = sourceNames[track.sourceId] ?? '';
                      final subtitle = [
                        track.artist,
                        if (source.isNotEmpty) source,
                      ].where((part) => part.isNotEmpty).join(' · ');
                      return MusicSongRow(
                        track: track,
                        number: index + 1,
                        playing: playingId == track.id,
                        favourite: favourites.contains(track),
                        subtitle: subtitle.isEmpty ? null : subtitle,
                        onPlay: () => _play(track, tracks),
                        onFavourite: () => unawaited(ref.read(musicFavouritesProvider.notifier).toggle(track)),
                        onRemove: () => unawaited(_remove([track])),
                      );
                    },
                  ),
          ),
        ],
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: extras.isEmpty ? null : () => unawaited(_remove(extras)),
          child: Text(t.music.duplicatesRemoveAll),
        ),
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.close),
        ),
      ],
    );
  }
}
