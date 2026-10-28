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

/// Asks which playlist should take [track], offering a new one when there is
/// none; [listName] names the list when the caller already picked it.
Future<void> showAddToPlaylistDialog(
  BuildContext context,
  WidgetRef ref,
  audio.MusicTrack track, {
  String? listName,
}) async {
  final t = context.t;
  final playlists = ref.read(musicPlaylistsProvider);
  final choice =
      listName ??
      await showDsDialog<String>(
        context: context,
        builder: (context) => DsDialog(
          title: Text(t.music.addToPlaylist),
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
  if (choice == null || !context.mounted) return;
  MusicPlaylist? playlist;
  if (choice == t.music.playlistCreateTitle) {
    playlist = await showCreatePlaylistDialog(context, ref);
    if (playlist == null) return;
  } else {
    playlist = ref.read(musicPlaylistsProvider.notifier).find(choice);
  }
  if (playlist == null) return;
  final added = await ref.read(musicPlaylistsProvider.notifier).addTrack(playlist.id, track);
  if (!context.mounted) return;
  showDsToast(
    context: context,
    title: added ? t.music.playlistAdded(name: playlist.name) : t.music.playlistAlreadyIn(name: playlist.name),
    status: added ? DsStatus.success : DsStatus.warning,
  );
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
