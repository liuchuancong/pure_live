import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_library.dart';
import 'package:pure_live/modules/music/controller/music_playback.dart';
import 'package:pure_live/modules/music/widgets/music_actions.dart';
import 'package:pure_live/modules/music/widgets/music_widgets.dart';

/// The play queue: the panel beside the player and the sheet the bar's queue
/// button raises. It walks to the playing row once per song and empties from
/// its own header, so the list is managed where it is shown.
final class MusicQueuePanel extends ConsumerStatefulWidget {
  /// The queue panel.
  const MusicQueuePanel({super.key});

  @override
  ConsumerState<MusicQueuePanel> createState() => MusicQueuePanelState();
}

final class MusicQueuePanelState extends ConsumerState<MusicQueuePanel> {
  /// The playing row's mark: a queue some hundreds long arrives where the
  /// song is, not at its head.
  final GlobalKey _playingKey = GlobalKey();

  /// The song the panel last walked to; a new song moves the view again.
  String? _locatedFor;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final state = ref.watch(musicPlayerProvider);
    final controller = ref.read(musicPlayerProvider.notifier);
    final favourites = ref.watch(musicFavouritesProvider);
    final favouriteController = ref.read(musicFavouritesProvider.notifier);
    final track = state.track;
    if (state.queueLength == 0 || track == null) {
      return DsSurface(
        decoration: DsBoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
        child: Center(
          child: DsEmptyState(icon: const DsIcon(DsIcons.listMusic), title: Text(t.music.queueEmpty)),
        ),
      );
    }
    // 打开即定位, and follow the song the queue steps onto: the panel walks
    // to the playing row once per song, not on every rebuild.
    if (track.id != _locatedFor && controller.queue.any((song) => song == track)) {
      _locatedFor = track.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final keyContext = _playingKey.currentContext;
        if (!mounted || keyContext == null) return;
        Scrollable.ensureVisible(keyContext, alignment: 0.3, duration: const Duration(milliseconds: 120));
      });
    }
    // The queue's own measure: how long the list still runs, the reference's
    // line under the panel's title.
    final total = controller.queue.fold(Duration.zero, (sum, song) => sum + (song.duration ?? Duration.zero));
    return DsSurface(
      decoration: DsBoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
      padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s12, DsSpace.s4, DsSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: DsSpace.s8),
            child: Row(
              spacing: DsSpace.s4,
              children: [
                Expanded(
                  child: Text(
                    [
                      t.music.queueTitle,
                      t.music.songsCount(count: state.queueLength),
                      if (total > Duration.zero) musicDurationText(total),
                    ].join(' · '),
                    style: theme.typography.caption.copyWith(color: colors.textSubtle),
                  ),
                ),
                // The reference panel's own verb: emptying the list from the
                // panel that lists it, not only from the player's menu. The
                // queue cannot be brought back, so the ask comes first.
                DsButton.icon(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  semanticLabel: t.music.clearQueue,
                  onPressed: () async {
                    final confirmed = await showDsConfirm(
                      context: context,
                      title: t.music.clearQueueConfirmTitle,
                      description: t.music.clearQueueConfirmBody,
                      confirmLabel: t.music.clearQueue,
                      cancelLabel: t.common.cancel,
                      destructive: true,
                      icon: const DsIcon(DsIcons.trash2),
                    );
                    if (!confirmed || !context.mounted) return;
                    unawaited(controller.clearQueue());
                  },
                  icon: const DsIcon(DsIcons.trash2, size: 16),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                DsListSection(
                  children: [
                    // The queue reorders by dragging — a handle at each row's
                    // end on a pointer, a long press on touch — the reference's
                    // own gesture. The engine keeps the song on air playing
                    // wherever it lands.
                    DsReorderableList(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: controller.queue.length,
                      onReorder: (from, to) => unawaited(controller.moveInQueue(from, to)),
                      itemBuilder: (context, index) {
                        final song = controller.queue[index];
                        return KeyedSubtree(
                          key: song == track ? _playingKey : ValueKey<String>('queue-slot-$index'),
                          child: MusicSongRow(
                            track: song,
                            playing: song == track,
                            favourite: favourites.contains(song),
                            onPlay: () => unawaited(controller.playAt(index)),
                            onFavourite: () => unawaited(favouriteController.toggle(song)),
                            onRemove: () => unawaited(controller.removeAt(index)),
                            onAddToPlaylist: () => unawaited(showAddToPlaylistDialog(context, ref, song)),
                            onDownload: () => unawaited(downloadTrackWithToast(context, ref, song)),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
