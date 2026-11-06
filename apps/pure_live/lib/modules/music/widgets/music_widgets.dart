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
import 'package:pure_live/modules/music/controller/music_playback_settings.dart'
    show MusicQuality, musicPlaybackSettingsProvider, musicQualityByScriptName, musicSourceDisplayName;
import 'package:pure_live/modules/music/controller/music_source.dart' show musicSourceListProvider;
import 'package:pure_live/modules/music/widgets/music_browse_links.dart'
    show musicTrackArtistId, openMusicAlbum, openMusicArtist;
import 'package:pure_live/shared/shared.dart' show avatarInitials, cachedImage;

/// The content tabs the module's pages wear: 44 tall, starting flush with
/// the strip that holds them, and no hairline under the row — the same
/// measure the video module set, and the one the component's own defaults
/// (46 tall, a border-coloured rule) would otherwise contradict.
const DsTabsStyle kMusicFeedTabsStyle = DsTabsStyle(
  height: 44,
  padding: EdgeInsets.zero,
  dividerColor: Color(0x00000000),
);

/// The song's own tier marker, the reference's 无损 / Hi-Res tag beside a title.
///
/// Only the lossless steps are marked: a 128K or 320K song carries nothing a
/// listener would read as news. A source that never listed the song's
/// renditions leaves [audio.MusicTrack.qualities] empty, and the row then says
/// nothing rather than guessing what the platform could serve.
String? musicQualityBadgeOf(Translations t, audio.MusicTrack track) {
  final offered = track.qualities;
  if (offered.isEmpty) return null;
  final ids = {for (final quality in offered) quality.id};
  if (ids.contains(MusicQuality.hiRes.scriptName)) return t.music.badgeHiRes;
  if (ids.contains(MusicQuality.lossless.scriptName)) return t.music.qualityLossless;
  return null;
}

/// The song's listed renditions in the module's own words, best last; an id
/// the four steps do not name is left out rather than shown as a guess.
String musicQualitiesText(Translations t, audio.MusicTrack track) =>
    [for (final quality in track.qualities) ?musicQualityByScriptName(quality.id)?.label(t)].join(' · ');

/// Who sang it and which record it came off, as one line: the module's only
/// spelling of a song's credits.
///
/// Empty pieces drop out and a song with neither yields null, so a row shows
/// its own fallback rather than a dangling separator. The bar under every music
/// page and the list rows both read this, so the same song cannot be credited
/// one way in the bar and another way in the list above it.
///
/// The library's search results deliberately do not: that row spends its second
/// piece on the source the song came from, which is the one fact that differs
/// between two hits on the same title.
String? musicTrackCredits(audio.MusicTrack track) {
  final parts = [if (track.artist.isNotEmpty) track.artist, if (track.album.isNotEmpty) track.album];
  return parts.isEmpty ? null : parts.join(' · ');
}

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
      initials: avatarInitials(track.title),
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
    this.number,
    this.ranked = false,
    this.onRemove,
    this.onPlayNext,
    this.onAddToPlaylist,
    this.onDownload,
    this.onToggleSource,
    this.onEditTags,
    this.onMoveUp,
    this.onMoveDown,
    this.subtitle,
    this.unavailableReason,
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

  /// The song's place in the list, printed in the leading column; null
  /// leaves the column empty (the row then leads with its art alone).
  final int? number;

  /// Whether that place is a chart standing: the top three numerals then
  /// grade their ink by it — the accent is the first place's alone and the
  /// heaviest weight there, the second and third keep the primary and muted
  /// inks a step below it, and every place after is the subtle ink any
  /// number is read in. An unranked list keeps all its numerals in that
  /// last ink.
  final bool ranked;

  /// Removes the song from the list it is drawn in, when the list owns one.
  final VoidCallback? onRemove;

  /// Puts the song right after the one on air.
  final VoidCallback? onPlayNext;

  /// Adds the song to one of the viewer's playlists.
  final VoidCallback? onAddToPlaylist;

  /// Downloads the song.
  final VoidCallback? onDownload;

  /// Swaps the song to another platform's copy — the reference's 歌曲换源.
  final VoidCallback? onToggleSource;

  /// Edits the song's tags in its file — the reference's 编辑歌曲标签; local
  /// songs only.
  final VoidCallback? onEditTags;

  /// Moves the song one place up in its list.
  final VoidCallback? onMoveUp;

  /// Moves the song one place down in its list.
  final VoidCallback? onMoveDown;

  /// A line under the title; the artist by default.
  final String? subtitle;

  /// Why this song cannot play right now — its file is gone or the engine
  /// failed on it. The row dims its title and says so beside it; null for a
  /// row that has nothing to warn about.
  final String? unavailableReason;

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
  void _showDetails(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final empty = t.music.songDetailEmpty;
    // The page the sheet was opened from: the sheet closes first, then the
    // album or artist page opens above it.
    final page = context;
    // The source names itself the way every list names it (the viewer's
    // alias choice included), not as the bare id the track carries.
    final settings = ref.read(musicPlaybackSettingsProvider);
    final source = ref.read(musicSourceListProvider).where((entry) => entry.id == track.sourceId).firstOrNull;
    final sourceLabel = source == null
        ? track.sourceId
        : musicSourceDisplayName(t, settings.sourceNameType, source.id, source.name);

    Widget row(String label, String value, {VoidCallback? onPressed}) => Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s12,
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
          ),
          Expanded(
            child: onPressed == null
                ? Text(value.isEmpty ? empty : value, style: theme.typography.body)
                : DsLink(
                    label: value.isEmpty ? empty : value,
                    style: const DsLinkStyle(underlineWidth: 0),
                    onPressed: onPressed,
                  ),
          ),
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
              row(
                t.music.songDetailArtist,
                track.artist,
                onPressed: track.artist.isEmpty
                    ? null
                    : () {
                        Navigator.of(page).pop();
                        openMusicArtist(
                          page,
                          sourceId: track.sourceId,
                          artist: track.artist,
                          artistId: musicTrackArtistId(track),
                        );
                      },
              ),
              row(
                t.music.songDetailAlbum,
                track.album,
                onPressed: (track.albumId ?? '').isEmpty
                    ? null
                    : () {
                        Navigator.of(page).pop();
                        openMusicAlbum(page, sourceId: track.sourceId, albumId: track.albumId!);
                      },
              ),
              row(t.music.songDetailDuration, _durationText(track.duration)),
              // The renditions the platform listed for this song. Empty when
              // it never said, which the row shows as its dash.
              row(t.music.songDetailQualities, musicQualitiesText(t, track)),
              row(t.music.songDetailSource, sourceLabel),
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
    final duration = _durationText(track.duration);
    // The leading numeral's ink: a ranked list grades it like the board's
    // column — the accent is the first place's alone and carries the
    // heaviest weight, the second and third step down through the primary
    // and muted inks, and every place after keeps the subtle ink any number
    // is read in. The song on air keeps its bars over any of it.
    TextStyle indexStyle() => switch (ranked ? number : null) {
      1 => theme.typography.numeric(
        theme.typography.caption.copyWith(color: colors.accentText, fontWeight: FontWeight.w700),
      ),
      2 => theme.typography.numeric(theme.typography.caption.copyWith(color: colors.text, fontWeight: FontWeight.w600)),
      3 => theme.typography.numeric(
        theme.typography.caption.copyWith(color: colors.textMuted, fontWeight: FontWeight.w600),
      ),
      _ => theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
    };
    return DsPressable(
      onPressed: selecting ? onSelected : onPlay,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return LayoutBuilder(
          builder: (context, constraints) {
            // The table's full set of columns needs the room for them; a
            // narrow list keeps the title and the two verbs.
            final wide = constraints.maxWidth >= 620;
            return Container(
              height: _kSongRowHeight,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s12),
              decoration: DsBoxDecoration(
                color: playing
                    ? colors.accentTint
                    : hovered
                    ? colors.hover
                    : null,
                borderRadius: BorderRadius.circular(theme.radii.card),
              ),
              child: Row(
                spacing: DsSpace.s12,
                children: [
                  SizedBox(
                    width: _kSongIndexWidth,
                    child: playing
                        ? DsIcon(DsIcons.audioLines, size: 16, color: colors.accent)
                        : Text('${number ?? ''}', textAlign: TextAlign.center, style: indexStyle()),
                  ),
                  MusicArtwork(track: track),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 2,
                      children: [
                        Row(
                          spacing: DsSpace.s4,
                          children: [
                            Flexible(
                              child: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.body.copyWith(
                                  color: unavailableReason != null
                                      ? colors.textSubtle
                                      : playing
                                      ? colors.accent
                                      : colors.text,
                                  fontWeight: playing ? FontWeight.w600 : null,
                                ),
                              ),
                            ),
                            if (unavailableReason case final reason?)
                              DsBadge(
                                dot: false,
                                style: DsBadgeStyle(textStyle: theme.typography.overline),
                                label: Text(reason),
                              ),
                            // The song's own tier, the reference's mark beside
                            // a title: what the platform listed for this song,
                            // not what the player was asked to fetch.
                            if (musicQualityBadgeOf(t, track) case final badge?)
                              DsBadge(
                                dot: false,
                                style: DsBadgeStyle(textStyle: theme.typography.overline),
                                label: Text(badge),
                              ),
                          ],
                        ),
                        if (artist.isNotEmpty)
                          Text(
                            artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.caption.copyWith(color: colors.textSubtle),
                          ),
                      ],
                    ),
                  ),
                  if (wide)
                    Expanded(
                      flex: 3,
                      child: Text(
                        track.album.isEmpty ? t.music.songAlbumUnknown : track.album,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(
                          color: track.album.isEmpty ? colors.textSubtle : colors.textMuted,
                        ),
                      ),
                    ),
                  if (wide)
                    SizedBox(
                      width: _kSongDurationWidth,
                      child: Text(
                        duration,
                        textAlign: TextAlign.end,
                        style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textMuted)),
                      ),
                    ),
                  SizedBox(
                    width: _kSongActionsWidth,
                    child: selecting
                        ? Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: DsCheckbox(value: selected, onChanged: (_) => onSelected?.call()),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            spacing: DsSpace.s4,
                            children: [
                              DsButton.icon(
                                variant: DsButtonVariant.ghost,
                                size: DsSize.sm,
                                semanticLabel: favourite ? t.music.unfavourite : t.music.favourite,
                                onPressed: onFavourite,
                                icon: DsIcon(
                                  DsIcons.heart,
                                  size: 16,
                                  color: favourite ? colors.accent : colors.textMuted,
                                ),
                              ),
                              if (onRemove case final remove?)
                                DsButton.icon(
                                  variant: DsButtonVariant.ghost,
                                  size: DsSize.sm,
                                  semanticLabel: t.music.removeSong,
                                  onPressed: remove,
                                  icon: const DsIcon(DsIcons.x, size: 16),
                                ),
                              _menu(context, ref, t, colors, theme, disliked),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// The row's own ⋮ menu: the list moves, the queue and playlist verbs, the
  /// dislike switch, the details and the copy.
  Widget _menu(BuildContext context, WidgetRef ref, Translations t, DsColors colors, DsThemeData theme, bool disliked) {
    return DsMenuAnchor(
      semanticLabel: t.music.moreActions,
      items: [
        if (onMoveUp case final moveUp?)
          DsMenuItem(leading: const DsIcon(DsIcons.arrowUp), label: Text(t.music.moveUp), onPressed: moveUp),
        if (onMoveDown case final moveDown?)
          DsMenuItem(leading: const DsIcon(DsIcons.arrowDown), label: Text(t.music.moveDown), onPressed: moveDown),
        if (onPlayNext case final playNext?)
          DsMenuItem(leading: const DsIcon(DsIcons.listPlus), label: Text(t.music.playNext), onPressed: playNext),
        if (onAddToPlaylist case final addToPlaylist?)
          DsMenuItem(
            leading: const DsIcon(DsIcons.listMusic),
            label: Text(t.music.addToPlaylist),
            onPressed: addToPlaylist,
          ),
        if (onDownload case final download?)
          DsMenuItem(leading: const DsIcon(DsIcons.download), label: Text(t.music.download), onPressed: download),
        if (onToggleSource case final toggleSource?)
          DsMenuItem(
            leading: const DsIcon(DsIcons.arrowRightLeft),
            label: Text(t.music.toggleSource),
            onPressed: toggleSource,
          ),
        if (onEditTags case final editTags?)
          DsMenuItem(leading: const DsIcon(DsIcons.edit), label: Text(t.music.editTags), onPressed: editTags),
        DsMenuItem(
          leading: const DsIcon(DsIcons.ban),
          label: Text(disliked ? t.music.undislike : t.music.dislike),
          onPressed: () => unawaited(_toggleDislike(context, ref)),
        ),
        DsMenuItem(
          leading: const DsIcon(DsIcons.info),
          label: Text(t.music.songDetails),
          onPressed: () => _showDetails(context, ref),
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
    );
  }
}

/// The song table's column widths: the leading number, the duration and the
/// trailing verbs, shared by [MusicSongRow] and [MusicSongTableHeader] so the
/// header's words sit over their columns.
const double _kSongIndexWidth = 24;
const double _kSongDurationWidth = 52;
const double _kSongActionsWidth = 108;
const double _kSongArtWidth = 32;
const double _kSongRowHeight = 52;

/// The words over one song table: # · 标题 · (专辑 ·) 时长, the same column
/// widths the rows use, so a long list reads as the reference's table.
final class MusicSongTableHeader extends StatelessWidget {
  /// The header row.
  const MusicSongTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final style = theme.typography.caption.copyWith(color: colors.textSubtle);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 620;
        return Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s12),
          child: SizedBox(
            height: 28,
            child: Row(
              spacing: DsSpace.s12,
              children: [
                SizedBox(
                  width: _kSongIndexWidth,
                  child: Text('#', textAlign: TextAlign.center, style: style),
                ),
                const SizedBox(width: _kSongArtWidth),
                Expanded(flex: 5, child: Text(t.music.songTableTitle, style: style)),
                if (wide) Expanded(flex: 3, child: Text(t.music.songTableAlbum, style: style)),
                if (wide)
                  SizedBox(
                    width: _kSongDurationWidth,
                    child: Text(t.music.songTableDuration, textAlign: TextAlign.end, style: style),
                  ),
                const SizedBox(width: _kSongActionsWidth),
              ],
            ),
          ),
        );
      },
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

/// A path's last segment, for a device file or a download's output.
String musicFileNameOf(String path) {
  final separator = path.lastIndexOf(RegExp(r'[\/]'));
  return separator < 0 ? path : path.substring(separator + 1);
}

/// A clock in `mm:ss`, or `h:mm:ss` past an hour — the player's two labels.
String musicDurationText(Duration duration) {
  final total = duration.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:${two(minutes)}:${two(seconds)}' : '${two(minutes)}:${two(seconds)}';
}
