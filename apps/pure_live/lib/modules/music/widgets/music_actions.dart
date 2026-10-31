import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_downloads.dart';
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/music_playlists.dart';
import 'package:pure_live/modules/music/controller/music_settings.dart'
    show musicSettingsProvider, musicSourceDisplayName;
import 'package:pure_live/modules/music/controller/music_source.dart' show musicSourceListProvider;
import 'package:pure_live/modules/music/controller/music_source_swaps.dart' show musicSourceSwapsProvider;

/// Asks for a playlist name and makes one; null when cancelled or blank.
Future<MusicPlaylist?> showCreatePlaylistDialog(BuildContext context, WidgetRef ref) async {
  final t = context.t;
  final field = TextEditingController();
  final name = await showDsDialog<String>(
    context: context,
    builder: (context) => DsDialog(
      title: Text(t.music.playlistCreateTitle),
      icon: const DsIcon(DsIcons.listMusic),
      description: DsTextField(
        controller: field,
        autofocus: true,
        clearable: true,
        placeholder: t.music.playlistNameHint,
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
  if (name == null || name.trim().isEmpty) return null;
  return await ref.read(musicPlaylistsProvider.notifier).create(name);
}

/// Asks which playlist should take [tracks], offering a new one when there is
/// none; [listName] names the list when the caller already picked it.
///
/// The batch form of [showAddToPlaylistDialog]: one dialog, one save, and a
/// count of what was actually new.
Future<void> showAddTracksToPlaylistDialog(
  BuildContext context,
  WidgetRef ref,
  List<audio.MusicTrack> tracks, {
  String? listName,
}) async {
  if (tracks.isEmpty) return;
  final t = context.t;
  final playlist = await _choosePlaylist(context, ref, listName: listName);
  if (playlist == null || !context.mounted) return;
  final added = await ref.read(musicPlaylistsProvider.notifier).addTracks(playlist.id, tracks);
  if (!context.mounted) return;
  showDsToast(
    context: context,
    title: added == 0
        ? t.music.playlistAlreadyIn(name: playlist.name)
        : t.music.playlistAddedCount(count: added, name: playlist.name),
    status: added == 0 ? DsStatus.warning : DsStatus.success,
  );
}

/// The reference's 移动到: the [tracks] join the chosen list — deduped,
/// positioned by the addToTop preference — and leave [fromPlaylistId].
Future<void> showMoveTracksToPlaylistDialog(
  BuildContext context,
  WidgetRef ref,
  String fromPlaylistId,
  List<audio.MusicTrack> tracks,
) async {
  if (tracks.isEmpty) return;
  final t = context.t;
  final playlist = await _choosePlaylist(context, ref, excludeId: fromPlaylistId, title: t.music.selectionMoveTo);
  if (playlist == null || !context.mounted) return;
  final moved = await ref.read(musicPlaylistsProvider.notifier).moveTracks(fromPlaylistId, playlist.id, tracks);
  if (!context.mounted) return;
  showDsToast(
    context: context,
    title: moved == 0
        ? t.music.playlistAlreadyIn(name: playlist.name)
        : t.music.moveDoneCount(count: moved, name: playlist.name),
    status: moved == 0 ? DsStatus.warning : DsStatus.success,
  );
}

/// Asks which playlist should take [track], offering a new one when there is
/// none; [listName] names the list when the caller already picked it.
Future<void> showAddToPlaylistDialog(
  BuildContext context,
  WidgetRef ref,
  audio.MusicTrack track, {
  String? listName,
}) async {
  if (!context.mounted) return;
  final t = context.t;
  final playlist = await _choosePlaylist(context, ref, listName: listName);
  if (playlist == null || !context.mounted) return;
  final added = await ref.read(musicPlaylistsProvider.notifier).addTrack(playlist.id, track);
  if (!context.mounted) return;
  showDsToast(
    context: context,
    title: added ? t.music.playlistAdded(name: playlist.name) : t.music.playlistAlreadyIn(name: playlist.name),
    status: added ? DsStatus.success : DsStatus.warning,
  );
}

/// The picker both add-to-playlist paths share.
Future<MusicPlaylist?> _choosePlaylist(
  BuildContext context,
  WidgetRef ref, {
  String? listName,
  String? excludeId,
  String? title,
}) async {
  final t = context.t;
  final playlists = [
    for (final playlist in ref.read(musicPlaylistsProvider))
      if (playlist.id != excludeId) playlist,
  ];
  final choice =
      listName ??
      await showDsDialog<String>(
        context: context,
        builder: (context) => DsDialog(
          title: Text(title ?? t.music.addToPlaylist),
          icon: const DsIcon(DsIcons.listMusic),
          description: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              if (playlists.isEmpty)
                Text(t.music.playlistsEmptyTitle, style: DsTheme.of(context).typography.body)
              else
                DsListSection(
                  children: [
                    for (final playlist in playlists)
                      DsListRow(
                        leading: const DsIcon(DsIcons.listMusic),
                        title: Text(playlist.name),
                        description: Text(t.music.songsCount(count: playlist.tracks.length)),
                        showChevron: true,
                        onPressed: () => Navigator.of(context).pop(playlist.id),
                      ),
                  ],
                ),
            ],
          ),
          actions: [
            DsButton(
              variant: DsButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.common.cancel),
            ),
            if (playlists.isNotEmpty)
              DsButton(
                onPressed: () => Navigator.of(context).pop(t.music.playlistCreateTitle),
                child: Text(t.music.playlistCreate),
              ),
          ],
        ),
      );
  if (choice == null || !context.mounted) return null;
  if (choice == t.music.playlistCreateTitle) {
    return await showCreatePlaylistDialog(context, ref);
  }

  return ref.read(musicPlaylistsProvider.notifier).find(choice);
}

/// Downloads [track] and words what happened.
Future<void> downloadTrackWithToast(
  BuildContext context,
  WidgetRef ref,
  audio.MusicTrack track, {
  String? listName,
}) async {
  final t = context.t;
  final result = await ref.read(musicDownloadsProvider.notifier).download(track, listName: listName);
  if (!context.mounted) return;
  switch (result.outcome) {
    case MusicDownloadStart.queued:
      showDsToast(
        context: context,
        title: t.music.downloadQueued(title: track.title),
        status: DsStatus.success,
      );
    case MusicDownloadStart.duplicate:
      showDsToast(context: context, title: t.music.downloadDuplicate, status: DsStatus.warning);
    case MusicDownloadStart.unsupported:
      showDsToast(context: context, title: t.music.downloadUnsupported, status: DsStatus.warning);
    case MusicDownloadStart.failed:
      showDsToast(
        context: context,
        title: t.music.downloadFailed(error: result.error ?? ''),
        status: DsStatus.danger,
      );
  }
}

/// Asks which other platform should serve [track] instead — the reference's
/// 歌曲换源. The pick is remembered in the swap cache, and [onSwapped] lets a
/// containing list replace the song where it stands.
Future<void> showToggleSourceDialog(
  BuildContext context,
  WidgetRef ref,
  audio.MusicTrack track, {
  void Function(audio.MusicTrack swapped)? onSwapped,
}) async {
  final swapped = await showDsDialog<audio.MusicTrack>(
    context: context,
    builder: (context) => _ToggleSourceDialog(track: track),
  );
  if (swapped == null || !context.mounted) return;
  await ref.read(musicSourceSwapsProvider.notifier).set(track, swapped);
  onSwapped?.call(swapped);
  if (!context.mounted) return;
  showDsToast(context: context, title: context.t.music.toggleSourceDone, status: DsStatus.success);
}

/// The candidate picker: every platform is searched at once and each answer
/// gets a tab — the reference's MusicToggleModal.
final class _ToggleSourceDialog extends ConsumerStatefulWidget {
  const _ToggleSourceDialog({required this.track});

  final audio.MusicTrack track;

  @override
  ConsumerState<_ToggleSourceDialog> createState() => _ToggleSourceDialogState();
}

final class _ToggleSourceDialogState extends ConsumerState<_ToggleSourceDialog> {
  final Map<String, List<audio.MusicTrack>> _answers = {};
  String _source = '';
  audio.MusicTrack? _picked;
  bool _loading = true;
  bool _failed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    final sources = ref.read(musicSourceListProvider);
    final query = '${widget.track.title} ${widget.track.artist}';
    final answers = await Future.wait([
      for (final source in sources)
        source.search(query, pageSize: 10).then<MapEntry<String, List<audio.MusicTrack>?>>(
          (page) => MapEntry(source.id, page.items),
          onError: (_) => MapEntry(source.id, null),
        ),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = answers.every((answer) => answer.value == null);
      _answers.addAll({for (final answer in answers) answer.key: answer.value ?? const <audio.MusicTrack>[]});
      _source = _answers.keys.firstWhere((id) => _answers[id]!.isNotEmpty, orElse: () => '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final settings = ref.watch(musicSettingsProvider);
    final sourceNames = {
      for (final source in ref.watch(musicSourceListProvider))
        source.id: musicSourceDisplayName(t, settings.sourceNameType, source.id, source.name),
    };
    final candidates = _answers[_source] ?? const <audio.MusicTrack>[];
    return DsDialog(
      title: Text(t.music.toggleSource),
      icon: const DsIcon(DsIcons.arrowRightLeft),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          Text(
            '${widget.track.title} · ${widget.track.artist}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.caption.copyWith(color: colors.textSubtle),
          ),
          SizedBox(
            height: 44,
            child: DsTopNav<String>(
              value: _source,
              onChanged: (id) => setState(() {
                _source = id;
                _picked = null;
              }),
              items: [
                for (final entry in _answers.entries)
                  DsTopNavItem(value: entry.key, label: Text(sourceNames[entry.key] ?? entry.key)),
              ],
            ),
          ),
          SizedBox(
            height: 320,
            child: _loading
                ? const Center(child: DsSpinner())
                : candidates.isEmpty
                ? Center(
                    child: Text(
                      _failed ? t.music.toggleSourceFailed : t.music.toggleSourceEmpty,
                      style: theme.typography.body.copyWith(color: colors.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: candidates.length,
                    itemBuilder: (context, index) {
                      final candidate = candidates[index];
                      return DsListRow(
                        title: Text(candidate.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        description: Text(
                          [candidate.artist, if (candidate.album.isNotEmpty) candidate.album]
                              .where((part) => part.isNotEmpty)
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: _picked?.id == candidate.id && _picked?.sourceId == candidate.sourceId,
                        onPressed: () => setState(() => _picked = candidate),
                        trailing: DsButton.icon(
                          variant: DsButtonVariant.secondary,
                          size: DsSize.sm,
                          semanticLabel: t.music.play,
                          onPressed: () => unawaited(ref.read(musicPlayerProvider.notifier).play(candidate)),
                          icon: const DsIcon(DsIcons.play, size: 16),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(
          onPressed: _picked == null ? null : () => Navigator.of(context).pop(_picked),
          child: Text(t.common.confirm),
        ),
      ],
    );
  }
}
