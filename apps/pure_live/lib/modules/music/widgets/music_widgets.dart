import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart' show cachedImage;

/// A song's album art: its cover, or the title's initials on a tone when the
/// platform gave none.
final class MusicArtwork extends StatelessWidget {
  /// The art of [track].
  const MusicArtwork({required this.track, this.size = DsSize.sm, super.key});

  final audio.MusicTrack track;
  final DsSize size;

  @override
  Widget build(BuildContext context) => DsAvatar(
    initials: track.title,
    image: track.coverUri == null ? null : cachedImage(track.coverUri.toString()),
    size: size,
    toneIndex: DsAvatar.toneFor(track.id),
    semanticLabel: track.title,
  );
}

/// One song in a list: its art, name and artist, the favourite heart, and the
/// remove verb on the lists that collect songs.
///
/// A row is the play control: the reference plays a song by choosing its row,
/// so a separate play button would be a second way to say the same thing.
final class MusicSongRow extends StatelessWidget {
  /// A song row for [track].
  const MusicSongRow({
    required this.track,
    required this.playing,
    required this.favourite,
    required this.onPlay,
    required this.onFavourite,
    this.onRemove,
    this.subtitle,
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

  /// A line under the title; the artist by default.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final artist = subtitle ?? track.artist;
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
      trailing: Row(
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
        ],
      ),
      onPressed: onPlay,
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
  audio.PlayMode.list => DsIcons.arrowRight,
  audio.PlayMode.listLoop => DsIcons.repeat,
  audio.PlayMode.singleLoop => DsIcons.repeat1,
  audio.PlayMode.random => DsIcons.shuffle,
};
