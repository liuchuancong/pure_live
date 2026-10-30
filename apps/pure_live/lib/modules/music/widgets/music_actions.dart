import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_downloads.dart';
import 'package:pure_live/modules/music/controller/music_playlists.dart';

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
