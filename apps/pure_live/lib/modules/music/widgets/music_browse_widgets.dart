import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_library.dart' show musicFavouritesProvider;
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/music_playback_settings.dart'
    show musicPlaybackSettingsProvider, musicSourceDisplayName;
import 'package:pure_live/modules/music/controller/music_source.dart' show musicSourceListProvider;
import 'package:pure_live/modules/music/controller/sources/music_browse_source.dart' show MusicAlbum;
import 'package:pure_live/modules/music/widgets/music_actions.dart';
import 'package:pure_live/modules/music/widgets/music_widgets.dart';
import 'package:pure_live/shared/shared.dart' show CoverFallback, cachedImage;

/// The platform a browse page reads its data from, in the viewer's own
/// wording — the alias choice applies here as it does in the lists.
String musicBrowseSourceLabel(WidgetRef ref, Translations t, String sourceId) {
  final source = ref.watch(musicSourceListProvider).where((entry) => entry.id == sourceId).firstOrNull;
  if (source == null) return sourceId;
  return musicSourceDisplayName(t, ref.watch(musicPlaybackSettingsProvider).sourceNameType, source.id, source.name);
}

/// The header both browse pages share: the way back and the page's name.
final class MusicBrowseHeader extends StatelessWidget {
  /// The header over [title].
  const MusicBrowseHeader({required this.title, super.key});

  /// The page's name, the kind of thing being browsed.
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s8, DsSpace.s20, DsSpace.s8),
      child: Row(
        spacing: DsSpace.s4,
        children: [
          DsButton.icon(
            variant: DsButtonVariant.ghost,
            semanticLabel: t.common.back,
            onPressed: () => Navigator.of(context).maybePop(),
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
        ],
      ),
    );
  }
}

/// The page a platform cannot serve: named as such, rather than drawn as an
/// empty album or artist that reads like the platform's own answer.
final class MusicBrowseUnsupported extends StatelessWidget {
  /// The unsupported state with [title] and the platform's [sourceName].
  const MusicBrowseUnsupported({required this.icon, required this.title, required this.sourceName, super.key});

  final DsIconData icon;
  final String title;
  final String sourceName;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Center(
      child: DsEmptyState(
        icon: DsIcon(icon),
        title: Text(title),
        description: Text(t.music.browseUnsupportedHint(source: sourceName)),
      ),
    );
  }
}

/// A browse page's failed read: the platform's words and a retry.
final class MusicBrowseFailure extends StatelessWidget {
  /// The failure state under [title], retried by [onRetry].
  const MusicBrowseFailure({required this.title, required this.error, required this.onRetry, super.key});

  final String title;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Center(
      child: DsEmptyState(
        icon: const DsIcon(DsIcons.cloudOff),
        title: Text(title),
        description: Text('$error'),
        actions: [DsButton(onPressed: onRetry, child: Text(t.common.retry))],
      ),
    );
  }
}

/// A browse page's loading state, the size every list in the module uses.
final class MusicBrowseLoading extends StatelessWidget {
  /// The spinner.
  const MusicBrowseLoading({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28)));
}

/// A section's words over a browse page's list.
final class MusicBrowseSection extends StatelessWidget {
  /// The section heading [title].
  const MusicBrowseSection({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s20, DsSpace.s20, DsSpace.s8),
      child: Text(title, style: theme.typography.heading.copyWith(color: colors.text)),
    );
  }
}

/// One song of a browse page, wired the way the charts' rows are: the row
/// plays its list from its own place, and its menu keeps the usual verbs.
final class MusicBrowseRow extends ConsumerWidget {
  /// The [index]th song of [tracks]; downloads are filed under [listName].
  const MusicBrowseRow({required this.tracks, required this.index, required this.listName, super.key});

  final List<audio.MusicTrack> tracks;
  final int index;

  /// The album or artist the row's downloads belong to.
  final String listName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = tracks[index];
    final playingId = ref.watch(musicPlayerProvider.select((state) => state.track?.id));
    final player = ref.read(musicPlayerProvider.notifier);
    final favourites = ref.watch(musicFavouritesProvider);
    final favouriteController = ref.read(musicFavouritesProvider.notifier);
    return MusicSongRow(
      track: song,
      number: index + 1,
      playing: playingId == song.id,
      favourite: favourites.contains(song),
      onPlay: () => unawaited(player.playAll(tracks, index: index)),
      onFavourite: () => unawaited(favouriteController.toggle(song)),
      onPlayNext: () => unawaited(player.playNext(song)),
      onAddToPlaylist: () => unawaited(showAddToPlaylistDialog(context, ref, song)),
      onDownload: () => unawaited(downloadTrackWithToast(context, ref, song, listName: listName)),
      onToggleSource: () => unawaited(showToggleSourceDialog(context, ref, song)),
    );
  }
}

/// One artist as a round card: the avatar the history named them by, their
/// name and the platform that serves their page.
final class MusicArtistCard extends StatelessWidget {
  /// The card for [name], served by the platform called [sourceLabel].
  const MusicArtistCard({required this.name, required this.sourceLabel, required this.onPressed, super.key});

  /// The width a card keeps inside a home rail.
  static const double width = 128;

  /// The artist the history credited.
  final String name;

  /// The platform that serves [name]'s page, in the viewer's own wording.
  final String sourceLabel;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    return SizedBox(
      width: width,
      child: DsCard(
        onPressed: onPressed,
        style: const DsCardStyle(padding: EdgeInsets.zero),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s12, DsSpace.s8, DsSpace.s12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s8,
            children: [
              ClipOval(
                child: DsImage(
                  image: null,
                  width: 96,
                  height: 96,
                  semanticLabel: name,
                  fallback: CoverFallback(title: name, padding: const EdgeInsets.all(DsSpace.s12)),
                ),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.typography.bodyStrong.copyWith(color: colors.text),
              ),
              Text(
                sourceLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One album as a card: its cover, its name and what the platform said about
/// it, the playlist card's grammar at a fixed width so a rail lines up.
final class MusicAlbumCard extends StatelessWidget {
  /// The card for [album], opened by [onPressed].
  const MusicAlbumCard({required this.album, required this.onPressed, super.key});

  /// The width a card keeps inside an artist's album rail.
  static const double width = 152;

  final MusicAlbum album;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final year = album.year;
    final facts = [if (year != null) '$year', if (album.trackCount > 0) t.music.songsCount(count: album.trackCount)];
    return SizedBox(
      width: width,
      child: DsCard(
        onPressed: onPressed,
        style: const DsCardStyle(padding: EdgeInsets.zero),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(theme.radii.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              DsImage(
                image: album.coverUri == null ? null : cachedImage(album.coverUri.toString()),
                aspectRatio: 1,
                semanticLabel: album.name,
                fallback: CoverFallback(title: album.name),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, DsSpace.s8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s3,
                  children: [
                    Text(
                      album.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.bodyStrong.copyWith(color: colors.text),
                    ),
                    if (facts.isNotEmpty)
                      Text(
                        facts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
