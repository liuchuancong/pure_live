import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_dislikes.dart' show musicDislikesProvider;
import 'package:pure_live/modules/music/controller/music_library.dart' show musicTrackKey;
import 'package:pure_live/modules/music/controller/music_local.dart' show musicLocalCoverProvider;
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/shared/shared.dart' show cachedImage;

/// A song's album art: its cover, or the title's initials on a tone when the
/// platform gave none.
///
/// Streamed tracks carry a cover URI; a local file carries its picture inside
/// its own tags, read on demand and drawn from memory.
final class MusicArtwork extends ConsumerWidget {
  /// The art of [track].
  const MusicArtwork({required this.track, this.size = DsSize.sm, super.key});

  final audio.MusicTrack track;
  final DsSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = track.isLocal ? ref.watch(musicLocalCoverProvider(track)).value : null;

    return DsAvatar(
      initials: track.title,
      image: local != null
          ? MemoryImage(local)
          : track.coverUri == null
          ? null
          : cachedImage(track.coverUri.toString()),
      size: size,
      toneIndex: DsAvatar.toneFor(track.id),
      semanticLabel: track.title,
    );
  }
}

/// One song in a list: its art, name and artist, the favourite heart, and the
/// remove verb on the lists that collect songs.
///
/// A row is the play control: the reference plays a song by choosing its row,
/// so a separate play button would be a second way to say the same thing.
final class MusicSongRow extends ConsumerWidget {
  /// A song row for [track].
  const MusicSongRow({
    required this.track,
    required this.playing,
    required this.favourite,
    required this.onPlay,
    required this.onFavourite,
    this.onRemove,
    this.onPlayNext,
    this.onAddToPlaylist,
    this.onDownload,
    this.onMoveUp,
    this.onMoveDown,
    this.subtitle,
    this.selecting = false,
    this.selected = false,
    this.onSelected,
    super.key,
  });

  final audio.MusicTrack track;

  /// Whether this is the song on air.
  final bool playing;

  /// Whether the song is in the viewer's collection.
  final bool favourite;

  final VoidCallback onPlay;
  final VoidCallback onFavourite;

  /// Removes the song from the list it is drawn in, when the list owns one.
  final VoidCallback? onRemove;

  /// Puts the song right after the one on air.
  final VoidCallback? onPlayNext;

  /// Adds the song to one of the viewer's playlists.
  final VoidCallback? onAddToPlaylist;

  /// Downloads the song.
  final VoidCallback? onDownload;

  /// Moves the song one place up in its list.
  final VoidCallback? onMoveUp;

  /// Moves the song one place down in its list.
  final VoidCallback? onMoveDown;

  /// A line under the title; the artist by default.
  final String? subtitle;

  /// Whether the row shows a selection box instead of its actions.
  final bool selecting;

  /// Whether this row is picked, while [selecting].
  final bool selected;

  /// Picks or unpicks the row; tapping the row does the same while selecting.
  final VoidCallback? onSelected;

  /// Puts the song's display name on the clipboard.
  Future<void> _copyName(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: track.displayName));

    if (context.mounted) {
      showDsToast(context: context, title: context.t.music.copiedSongName, status: DsStatus.success);
    }
  }

  /// Shows what the track knows about itself — the reference's 歌曲详情.
  void _showDetails(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final empty = t.music.songDetailEmpty;

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s12,
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
          ),
          Expanded(child: Text(value.isEmpty ? empty : value, style: theme.typography.body)),
        ],
      ),
    );

    unawaited(
      showDsDialog<void>(
        context: context,
        builder: (context) => DsDialog(
          title: Text(t.music.songDetails),
          icon: const DsIcon(DsIcons.info),
          description: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row(t.music.songDetailTitle, track.title),
              row(t.music.songDetailArtist, track.artist),
              row(t.music.songDetailAlbum, track.album),
              row(t.music.songDetailDuration, _durationText(track.duration)),
              row(t.music.songDetailSource, track.sourceId),
              if (track.localPath != null) row(t.music.songDetailPath, track.localPath!),
            ],
          ),
          actions: [DsButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.common.close))],
        ),
      ),
    );
  }

  static String _durationText(Duration? duration) {
    if (duration == null || duration.inMilliseconds <= 0) return '';
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');

    return hours > 0 ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds' : '$minutes:$seconds';
  }

  /// Adds or removes the dislike rule and words the answer.
  Future<void> _toggleDislike(BuildContext context, WidgetRef ref) async {
    final disliked = await ref.read(musicPlayerProvider.notifier).toggleDislike(track);
    if (!context.mounted) return;
    showDsToast(
      context: context,
      title: disliked ? context.t.music.disliked : context.t.music.undisliked,
      status: DsStatus.success,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final artist = subtitle ?? track.artist;
    final disliked = ref.watch(musicDislikesProvider).contains(musicTrackKey(track));
    return DsListRow(
      leading: MusicArtwork(track: track),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.typography.body.copyWith(
          color: playing ? colors.accent : colors.text,
          fontWeight: playing ? FontWeight.w600 : null,
        ),
      ),
      description: artist.isEmpty
          ? null
          : Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(color: colors.textSubtle),
            ),
      trailing: selecting
          ? DsCheckbox(value: selected, onChanged: (_) => onSelected?.call())
          : Row(
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s4,
              children: [
                DsButton.icon(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  semanticLabel: favourite ? t.music.unfavourite : t.music.favourite,
                  onPressed: onFavourite,
                  icon: DsIcon(DsIcons.heart, size: 16, color: favourite ? colors.accent : colors.textMuted),
                ),
                if (onRemove case final remove?)
                  DsButton.icon(
                    variant: DsButtonVariant.ghost,
                    size: DsSize.sm,
                    semanticLabel: t.music.removeSong,
                    onPressed: remove,
                    icon: const DsIcon(DsIcons.x, size: 16),
                  ),
                DsMenuAnchor(
                  semanticLabel: t.music.moreActions,
                  items: [
                    if (onMoveUp case final moveUp?)
                      DsMenuItem(
                        leading: const DsIcon(DsIcons.arrowUp),
                        label: Text(t.music.moveUp),
                        onPressed: moveUp,
                      ),
                    if (onMoveDown case final moveDown?)
                      DsMenuItem(
                        leading: const DsIcon(DsIcons.arrowDown),
                        label: Text(t.music.moveDown),
                        onPressed: moveDown,
                      ),
                    if (onPlayNext case final playNext?)
                      DsMenuItem(
                        leading: const DsIcon(DsIcons.listPlus),
                        label: Text(t.music.playNext),
                        onPressed: playNext,
                      ),
                    if (onAddToPlaylist case final addToPlaylist?)
                      DsMenuItem(
                        leading: const DsIcon(DsIcons.listMusic),
                        label: Text(t.music.addToPlaylist),
                        onPressed: addToPlaylist,
                      ),
                    if (onDownload case final download?)
                      DsMenuItem(
                        leading: const DsIcon(DsIcons.download),
                        label: Text(t.music.download),
                        onPressed: download,
                      ),
                    DsMenuItem(
                      leading: const DsIcon(DsIcons.ban),
                      label: Text(disliked ? t.music.undislike : t.music.dislike),
                      onPressed: () => unawaited(_toggleDislike(context, ref)),
                    ),
                    DsMenuItem(
                      leading: const DsIcon(DsIcons.info),
                      label: Text(t.music.songDetails),
                      onPressed: () => _showDetails(context),
                    ),
                    DsMenuItem(
                      leading: const DsIcon(DsIcons.copy),
                      label: Text(t.music.copySongName),
                      onPressed: () => unawaited(_copyName(context)),
                    ),
                  ],
                  builder: (context, controller, _) => DsButton.icon(
                    variant: DsButtonVariant.ghost,
                    size: DsSize.sm,
                    semanticLabel: t.music.moreActions,
                    onPressed: controller.toggle,
                    icon: const DsIcon(DsIcons.ellipsisVertical, size: 16),
                  ),
                ),
              ],
            ),
      onPressed: selecting ? onSelected : onPlay,
    );
  }
}

/// The mode button's words and glyph — the reference's four modes.
String musicPlayModeLabel(Translations t, audio.PlayMode mode) => switch (mode) {
  audio.PlayMode.list => t.music.modeList,
  audio.PlayMode.listLoop => t.music.modeListLoop,
  audio.PlayMode.singleLoop => t.music.modeSingleLoop,
  audio.PlayMode.random => t.music.modeRandom,
};

DsIconData musicPlayModeIcon(audio.PlayMode mode) => switch (mode) {
  audio.PlayMode.list => DsIcons.arrowRightToLine,
  audio.PlayMode.listLoop => DsIcons.repeat,
  audio.PlayMode.singleLoop => DsIcons.repeat1,
  audio.PlayMode.random => DsIcons.shuffle,
};
