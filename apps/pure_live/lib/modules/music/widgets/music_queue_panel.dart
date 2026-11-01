import 'dart:async' show unawaited;
import 'dart:io' show File;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_library.dart';
import 'package:pure_live/modules/music/controller/music_playback.dart';
import 'package:pure_live/modules/music/widgets/music_actions.dart';
import 'package:pure_live/modules/music/widgets/music_widgets.dart';

/// The play queue: the panel beside the player and the sheet the bar's queue
/// button raises. It walks to the playing row once per song and empties from
/// its own header, so the list is managed where it is shown.
///
/// The list is split at the playhead: 已播放 above it — collapsed by default,
/// most recent first, plain rows — and 接下来播放 from it on, the part the
/// viewer still rearranges. A song whose local file vanished, or one the
/// engine already refused, keeps its row but says so beside its title.
final class MusicQueuePanel extends ConsumerStatefulWidget {
  /// The queue panel.
  const MusicQueuePanel({super.key});

  @override
  ConsumerState<MusicQueuePanel> createState() => MusicQueuePanelState();
}

final class MusicQueuePanelState extends ConsumerState<MusicQueuePanel> {
  /// How many rows a group draws before offering the rest; a queue of several
  /// hundred opens quickly and says how much it still holds.
  static const int _kGroupPage = 100;

  /// The playing row's mark: a queue some hundreds long arrives where the
  /// song is, not at its head.
  final GlobalKey _playingKey = GlobalKey();

  /// The song the panel last walked to; a new song moves the view again.
  String? _locatedFor;

  /// Whether the played group is open; it starts closed so the panel opens on
  /// the song on air.
  bool _playedExpanded = false;
  int _upNextShown = _kGroupPage;
  int _playedShown = _kGroupPage;

  /// Queue entries whose local file is gone, keyed like the dislikes.
  Set<String> _missingFiles = const <String>{};

  /// The local paths [_missingFiles] was measured for.
  String _measuredPaths = '';

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final (track, queueLength, index, mode) = ref.watch(
      musicPlayerProvider.select((state) => (state.track, state.queueLength, state.index, state.mode)),
    );
    // A reorder keeps the track, its index and the length, so the engine's
    // snapshot compares equal to the last one; the revision is the only sign
    // that the order changed.
    ref.watch(musicQueueRevisionProvider);
    final failed = ref.watch(musicFailedTracksProvider);
    final controller = ref.read(musicPlayerProvider.notifier);
    final favourites = ref.watch(musicFavouritesProvider);
    final favouriteController = ref.read(musicFavouritesProvider.notifier);
    if (queueLength == 0 || track == null) {
      return DsSurface(
        decoration: DsBoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
        child: Center(
          child: DsEmptyState(icon: const DsIcon(DsIcons.listMusic), title: Text(t.music.queueEmpty)),
        ),
      );
    }
    final queue = controller.queue;
    _ensureFileCheck(queue);
    // The queue positions in play order: list order, or the shuffle the engine
    // materialized, so 已播放 means "already played" rather than "earlier in
    // the list" while shuffled.
    final order = controller.playOrder;
    final cursor = order.indexOf(index);
    final played = cursor > 0 ? order.sublist(0, cursor).reversed.toList(growable: false) : const <int>[];
    final upNext = cursor >= 0 ? order.sublist(cursor) : order;
    // 打开即定位, and follow the song the queue steps onto: the panel walks
    // to the playing row once per song, not on every rebuild. A new song also
    // puts the two groups back to their first page.
    if (track.id != _locatedFor && index >= 0 && index < queue.length) {
      _locatedFor = track.id;
      _upNextShown = _kGroupPage;
      _playedShown = _kGroupPage;
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealPlaying());
    }
    // The queue's own measure: how long the list still runs, the reference's
    // line under the panel's title.
    final total = queue.fold(Duration.zero, (sum, song) => sum + (song.duration ?? Duration.zero));

    Widget row(int queueIndex) {
      final song = queue[queueIndex];
      final key = musicTrackKey(song);
      final unavailable = _missingFiles.contains(key)
          ? t.music.queueMissingFile
          : failed.contains(key)
          ? t.music.queueUnplayable
          : null;
      final playing = queueIndex == index;
      return KeyedSubtree(
        key: playing ? _playingKey : ValueKey<String>('queue-slot-$queueIndex'),
        child: MusicSongRow(
          track: song,
          playing: playing,
          favourite: favourites.contains(song),
          unavailableReason: unavailable,
          onPlay: () => unawaited(controller.playAt(queueIndex)),
          onFavourite: () => unawaited(favouriteController.toggle(song)),
          onRemove: () => unawaited(controller.removeAt(queueIndex)),
          onAddToPlaylist: () => unawaited(showAddToPlaylistDialog(context, ref, song)),
          onDownload: () => unawaited(downloadTrackWithToast(context, ref, song)),
        ),
      );
    }

    Widget groupHeader(String label, int count, {bool expanded = true, VoidCallback? onToggle}) {
      final caption = '$label · ${t.music.songsCount(count: count)}';
      final content = Row(
        spacing: DsSpace.s4,
        children: [
          Flexible(
            child: Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.label.copyWith(color: colors.textMuted),
            ),
          ),
          if (onToggle != null)
            DsIcon(expanded ? DsIcons.chevronUp : DsIcons.chevronDown, size: 14, color: colors.textSubtle),
        ],
      );
      if (onToggle == null) {
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s4, DsSpace.s4, DsSpace.s8, 0),
          child: content,
        );
      }
      return DsPressable(
        onPressed: onToggle,
        semanticLabel: caption,
        expanded: expanded,
        builder: (context, states, child) {
          final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
          return DsFocusRing(
            focused: states.contains(WidgetState.focused),
            borderRadius: BorderRadius.circular(theme.radii.card),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s4),
              decoration: DsBoxDecoration(
                color: lit ? colors.hover : null,
                borderRadius: BorderRadius.circular(theme.radii.card),
              ),
              child: child,
            ),
          );
        },
        child: content,
      );
    }

    Widget showMore(int remaining, VoidCallback onPressed) => Padding(
      padding: const EdgeInsets.only(top: DsSpace.s4, right: DsSpace.s8),
      child: Center(
        child: DsButton(
          variant: DsButtonVariant.ghost,
          size: DsSize.sm,
          onPressed: onPressed,
          child: Text(t.music.queueShowMore(count: remaining)),
        ),
      ),
    );

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
                      t.music.songsCount(count: queueLength),
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
                if (played.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: DsSpace.s8),
                    child: groupHeader(
                      t.music.queuePlayed,
                      played.length,
                      expanded: _playedExpanded,
                      onToggle: () {
                        setState(() => _playedExpanded = !_playedExpanded);
                        // The rows above the playhead change the list's height;
                        // the song on air stays where the viewer left it.
                        WidgetsBinding.instance.addPostFrameCallback((_) => _revealPlaying());
                      },
                    ),
                  ),
                  if (_playedExpanded)
                    DsListSection(
                      children: [
                        for (final queueIndex in played.take(_playedShown)) row(queueIndex),
                        if (played.length > _playedShown)
                          showMore(played.length - _playedShown, () => setState(() => _playedShown += _kGroupPage)),
                      ],
                    ),
                ],
                Padding(
                  padding: const EdgeInsets.only(right: DsSpace.s8),
                  child: groupHeader(t.music.queueUpNext, upNext.length),
                ),
                DsListSection(
                  children: [
                    // The up-next rows reorder by dragging — a handle at each
                    // row's end on a pointer, a long press on touch. The engine
                    // keeps the song on air playing wherever it lands. A
                    // shuffled queue plays a permutation, not the list order,
                    // so its rows are not draggable.
                    DsReorderableList(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: math.min(_upNextShown, upNext.length),
                      onReorder: mode == audio.PlayMode.random
                          ? null
                          : (from, to) => unawaited(controller.moveInQueue(upNext[from], upNext[to])),
                      itemBuilder: (context, position) => row(upNext[position]),
                    ),
                  ],
                ),
                if (upNext.length > _upNextShown)
                  showMore(upNext.length - _upNextShown, () => setState(() => _upNextShown += _kGroupPage)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Walks the list to the song on air, once the frame laid it out.
  void _revealPlaying() {
    final keyContext = _playingKey.currentContext;
    if (!mounted || keyContext == null) return;
    Scrollable.ensureVisible(keyContext, alignment: 0.3, duration: const Duration(milliseconds: 120));
  }

  /// Measures which of the queue's local files still exist, once per set of
  /// paths: a queue of streamed songs costs nothing, and a file deleted while
  /// the panel is open shows on the next measurement.
  void _ensureFileCheck(List<audio.MusicTrack> queue) {
    final paths = [for (final song in queue) ?song.localPath];
    final signature = paths.join('\u0000');
    if (signature == _measuredPaths) return;
    _measuredPaths = signature;
    if (paths.isEmpty) {
      _missingFiles = const <String>{};
      return;
    }
    unawaited(_measureFiles(queue, signature));
  }

  Future<void> _measureFiles(List<audio.MusicTrack> queue, String signature) async {
    final missing = <String>{};
    for (final song in queue) {
      final path = song.localPath;
      if (path == null) continue;
      try {
        // A local library runs to hundreds of files; the check stays off the
        // frame rather than probing each one synchronously.
        // ignore: avoid_slow_async_io
        if (!await File(path).exists()) missing.add(musicTrackKey(song));
      } on Object {
        // A path the platform cannot even ask about counts as gone.
        missing.add(musicTrackKey(song));
      }
    }
    if (!mounted || signature != _measuredPaths) return;
    setState(() => _missingFiles = missing);
  }
}
