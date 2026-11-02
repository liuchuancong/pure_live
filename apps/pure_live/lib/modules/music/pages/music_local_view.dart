import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_library.dart' show musicFavouritesProvider;
import 'package:pure_live/modules/music/controller/music_local.dart' show musicLocalProvider;
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/widgets/music_actions.dart';
import 'package:pure_live/modules/music/widgets/music_browse_widgets.dart' show MusicToolAction;
import 'package:pure_live/modules/music/widgets/music_tag_edit.dart';
import 'package:pure_live/modules/music/widgets/music_widgets.dart';

/// 本地音乐: the folders the viewer added, the files they hold, and the way
/// to add or drop a folder.
final class MusicLocalView extends ConsumerStatefulWidget {
  const MusicLocalView({super.key});

  @override
  ConsumerState<MusicLocalView> createState() => MusicLocalViewState();
}

final class MusicLocalViewState extends ConsumerState<MusicLocalView> {
  bool _selecting = false;
  final Set<audio.MusicTrack> _selected = <audio.MusicTrack>{};

  /// Whether a tap picks the span up to it — the reference's 区间 — instead
  /// of toggling one row (单选).
  bool _rangeMode = false;

  /// The row a span is measured from — the reference's prevSelectIndex.
  int? _anchor;

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
  void _toggleSelectAll(List<audio.MusicTrack> tracks) {
    setState(() {
      if (_selected.length == tracks.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(tracks);
      }
    });
  }

  /// The selected rows, in the list's own order.
  List<audio.MusicTrack> _picked(List<audio.MusicTrack> tracks) => [
    for (final track in tracks)
      if (_selected.contains(track)) track,
  ];

  Future<void> _playSelected(List<audio.MusicTrack> tracks) async {
    final picked = _picked(tracks);
    if (picked.isEmpty) return;
    await ref.read(musicPlayerProvider.notifier).playAll(picked);
    if (mounted) _setSelecting(selecting: false);
  }

  Future<void> _addFolder(BuildContext context) async {
    final t = context.t;
    try {
      final selected = await FilePicker.getDirectoryPath(dialogTitle: t.music.localAddFolder);
      if (selected == null || selected.trim().isEmpty || !mounted) return;
      await ref.read(musicLocalProvider.notifier).addRoot(selected);
    } on Object catch (failure) {
      if (context.mounted) {
        showDsToast(
          context: context,
          title: t.music.localFolderFailed(error: '$failure'),
          status: DsStatus.danger,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final state = ref.watch(musicLocalProvider);
    final controller = ref.read(musicLocalProvider.notifier);
    final playingId = ref.watch(musicPlayerProvider.select((state) => state.track?.id));
    final player = ref.read(musicPlayerProvider.notifier);
    final favourites = ref.watch(musicFavouritesProvider);
    final favouritesController = ref.read(musicFavouritesProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
          child: Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: Text(
                  state.tracks.isEmpty ? t.music.localHint : t.music.localFiles(count: state.tracks.length),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textSubtle),
                ),
              ),
              MusicToolAction(
                label: _selecting ? t.music.selectionCancel : t.music.selectionStart,
                icon: _selecting ? DsIcons.x : DsIcons.listChecks,
                available: state.tracks.isNotEmpty,
                onPressed: () => _setSelecting(selecting: !_selecting),
              ),
              MusicToolAction(
                label: t.music.localRescan,
                icon: DsIcons.refreshCw,
                available: state.roots.isNotEmpty,
                onPressed: state.loading ? null : () => unawaited(controller.rescan()),
              ),
              MusicToolAction(
                label: t.music.localAddFolder,
                icon: DsIcons.folderPlus,
                available: true,
                onPressed: () => unawaited(_addFolder(context)),
              ),
            ],
          ),
        ),
        if (_selecting)
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
            // The selection's verbs wrap, as the playlist detail's do: the
            // window's floor is 300 px and the row's controls never fit it.
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
                  onPressed: () => _toggleSelectAll(state.tracks),
                  child: Text(_selected.length == state.tracks.length ? t.music.selectionInvert : t.music.selectionAll),
                ),
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.play, size: 16),
                  onPressed: _selected.isEmpty ? null : () => unawaited(_playSelected(state.tracks)),
                  child: Text(t.music.playAll),
                ),
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.listMusic, size: 16),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => unawaited(showAddTracksToPlaylistDialog(context, ref, _picked(state.tracks))),
                  child: Text(t.music.addToPlaylist),
                ),
              ],
            ),
          ),
        if (state.roots.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
            child: DsListSection(
              header: Text(t.music.localFolders),
              children: [
                for (final root in state.roots)
                  DsListRow(
                    leading: const DsIcon(DsIcons.folder),
                    title: Text(root, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: DsButton.icon(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      semanticLabel: t.music.localRemoveFolder,
                      onPressed: () => unawaited(controller.removeRoot(root)),
                      icon: const DsIcon(DsIcons.x, size: 16),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: state.loading
              ? const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28)))
              : state.error != null
              ? Center(
                  child: DsEmptyState(
                    icon: const DsIcon(DsIcons.folderOpen),
                    title: Text(t.music.localFailed),
                    description: Text(state.error!),
                    actions: [DsButton(onPressed: () => unawaited(controller.rescan()), child: Text(t.common.retry))],
                  ),
                )
              : state.tracks.isEmpty
              ? Center(
                  child: DsEmptyState(
                    icon: const DsIcon(DsIcons.folderOpen),
                    title: Text(t.music.localEmptyTitle),
                    description: Text(t.music.localEmptyDescription),
                    actions: [
                      DsButton(
                        leading: const DsIcon(DsIcons.folderPlus, size: 16),
                        onPressed: () => unawaited(_addFolder(context)),
                        child: Text(t.music.localAddFolder),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: DsSpace.s16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: DsButton(
                          variant: DsButtonVariant.secondary,
                          size: DsSize.sm,
                          leading: const DsIcon(DsIcons.play, size: 16),
                          onPressed: () => unawaited(player.playAll(state.tracks)),
                          child: Text(t.music.playAll),
                        ),
                      ),
                    ),
                    DsListSection(
                      children: [
                        const MusicSongTableHeader(),
                        for (final (index, song) in state.tracks.indexed)
                          MusicSongRow(
                            track: song,
                            number: index + 1,
                            playing: playingId == song.id,
                            favourite: favourites.contains(song),
                            selecting: _selecting,
                            selected: _selected.contains(song),
                            onSelected: _rangeMode
                                ? () => _selectRange(state.tracks, index)
                                : () => _toggleSelected(song, index),
                            // Tags name the song; the file name is the fallback
                            // for the files that carry none.
                            subtitle: song.artist.isNotEmpty
                                ? (song.album.isEmpty ? null : '${song.artist} · ${song.album}')
                                : song.localPath == null
                                ? null
                                : musicFileNameOf(song.localPath!),
                            onPlay: () => unawaited(player.playAll(state.tracks, index: index)),
                            onFavourite: () => unawaited(favouritesController.toggle(song)),
                            onPlayNext: () => unawaited(player.playNext(song)),
                            onAddToPlaylist: () => unawaited(showAddToPlaylistDialog(context, ref, song)),
                            onEditTags: song.isLocal
                                ? () => unawaited(showEditTrackTagsDialog(context, ref, song))
                                : null,
                          ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// 下载: the queue's tasks with their progress and the verbs each state has.
/// 下载管理: the queue as a library — a summary of what is on disk, the three
/// filters the station's own manager carries, and one row per file (its art,
/// its facts and, once it is on disk, its play verb).
