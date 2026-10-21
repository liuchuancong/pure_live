import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' show AudioPlaybackState, MusicTrack, PlayMode;
import 'package:pure_live/features/vod/music/bilibili_music_source.dart';
import 'package:pure_live/features/vod/music/music_player.dart' show musicPlayerProvider, musicStateProvider;
import 'package:pure_live/features/vod/vod_page.dart' show vodClientProvider;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/tv/widgets/tv_pill.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// 音乐 on the ten-foot screen: the search row, the tracks as focus rows, and
/// the now-playing bar with its controls as pills — all driven by the same
/// media_core_audio controller the phone page uses.
final class TvMusicView extends ConsumerWidget {
  /// The TV music pane.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const _TvMusicBody();
}

final class _TvMusicBody extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_TvMusicBody> createState() => _TvMusicBodyState();
}

final class _TvMusicBodyState extends ConsumerState<_TvMusicBody> {
  final TextEditingController _keyword = TextEditingController();
  List<MusicTrack> _results = const [];
  bool _loading = false;
  Object? _failure;

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _keyword.text.trim();
    if (keyword.isEmpty || _loading) {
      return;
    }
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final page = await BilibiliMusicSource(ref.read(vodClientProvider)).search(keyword);
      if (mounted) {
        setState(() => _results = page.items);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _failure = error);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _play(int index) async {
    if (_results.isEmpty) {
      return;
    }
    await ref.read(musicPlayerProvider).setQueue(_results, startIndex: index);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final state = ref.watch(musicStateProvider).value ?? AudioPlaybackState.idle;
    final track = state.track;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 24, 48, 8),
            child: Row(
              children: [
                Text(t.music.title, style: theme.text.title.copyWith(color: theme.colors.text)),
                const SizedBox(width: 24),
                Expanded(
                  child: PureTextField(
                    key: const ValueKey('tv-music-search'),
                    controller: _keyword,
                    placeholder: t.music.searchHint,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => unawaited(_search()),
                  ),
                ),
                const SizedBox(width: 12),
                TvPill(key: const ValueKey('tv-music-go'), label: t.music.search, onTap: () => unawaited(_search())),
              ],
            ),
          ),
          if (_failure != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(t.errors.network, style: theme.text.bodySmall.copyWith(color: theme.colors.error)),
            ),
          Expanded(
            child: _loading && _results.isEmpty
                ? const Center(child: PureSpinner(size: 40))
                : _results.isEmpty
                ? Center(
                    child: PureEmpty(title: t.music.empty, icon: Icons.music_note_outlined),
                  )
                : FocusTraversalGroup(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(48, 8, 48, 16),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final entry = _results[index];
                        final current = track != null && track.id == entry.id && track.sourceId == entry.sourceId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TvTrackRow(
                            key: ValueKey('tv-music-track-${entry.id}'),
                            title: entry.title,
                            subtitle: [entry.artist, if (entry.duration != null) _label(entry.duration!)].join(' · '),
                            current: current,
                            autofocus: index == 0,
                            onTap: () => unawaited(_play(index)),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (track != null) _nowPlaying(context, theme, state),
        ],
      ),
    );
  }

  Widget _nowPlaying(BuildContext context, PureTheme theme, AudioPlaybackState state) {
    final t = context.t;
    final track = state.track!;
    final total = state.duration.inMilliseconds == 0 ? 1.0 : state.duration.inMilliseconds.toDouble();
    final player = ref.read(musicPlayerProvider);
    return Material(
      color: theme.colors.bgContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48, 8, 48, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.text.subtitle),
                      Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.text.caption),
                    ],
                  ),
                ),
                TvPill(
                  key: const ValueKey('tv-music-mode'),
                  label: switch (state.mode) {
                    PlayMode.list => t.music.mode,
                    PlayMode.listLoop => '${t.music.mode} ⟳',
                    PlayMode.singleLoop => '${t.music.mode} 1',
                    PlayMode.random => '${t.music.mode} ⤨',
                  },
                  selected: state.mode != PlayMode.list,
                  onTap: () => player.setPlayMode(switch (state.mode) {
                    PlayMode.list => PlayMode.listLoop,
                    PlayMode.listLoop => PlayMode.singleLoop,
                    PlayMode.singleLoop => PlayMode.random,
                    PlayMode.random => PlayMode.list,
                  }),
                ),
                const SizedBox(width: 12),
                TvPill(
                  key: const ValueKey('tv-music-previous'),
                  label: t.music.previous,
                  onTap: () => unawaited(player.previous()),
                ),
                const SizedBox(width: 12),
                TvPill(
                  key: const ValueKey('tv-music-toggle'),
                  label: state.playing ? t.music.pause : t.music.play,
                  selected: state.playing,
                  onTap: () => unawaited(player.toggle()),
                ),
                const SizedBox(width: 12),
                TvPill(
                  key: const ValueKey('tv-music-next'),
                  label: t.music.next,
                  onTap: () => unawaited(player.next()),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(_label(state.position), style: theme.text.caption),
                Expanded(
                  child: Slider(
                    value: (state.position.inMilliseconds / total).clamp(0.0, 1.0),
                    onChanged: (value) =>
                        unawaited(player.seek(Duration(milliseconds: (value * state.duration.inMilliseconds).round()))),
                  ),
                ),
                Text(_label(state.duration), style: theme.text.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _label(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return value.inHours > 0 ? '${value.inHours}:$minutes:$seconds' : '$minutes:$seconds';
  }
}

/// One track row: a focusable band with the title and its artist/duration.
final class _TvTrackRow extends StatefulWidget {
  const new({
    required this.title,
    required this.subtitle,
    required this.current,
    required this.onTap,
    this.autofocus = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool current;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  State<_TvTrackRow> createState() => _TvTrackRowState();
}

final class _TvTrackRowState extends State<_TvTrackRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final color = widget.current || _focused ? theme.colors.primary : theme.colors.text;
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (value) {
        if (value != _focused) {
          setState(() => _focused = value);
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colors.fillQuaternary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _focused ? theme.colors.primary : Colors.transparent, width: 2),
          ),
          child: Row(
            children: [
              Icon(widget.current ? Icons.graphic_eq : Icons.music_note_outlined, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.text.body.copyWith(
                        color: color,
                        fontWeight: widget.current ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
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
