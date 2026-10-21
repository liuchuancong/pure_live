import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core/media_core.dart' show PlayerKernel;
import 'package:media_core_audio/media_core_audio.dart'
    show AudioPlaybackController, AudioPlaybackState, MusicSourceRegistry, MusicTrack, PlayMode;
import 'package:media_core_media_kit/media_core_media_kit.dart' show registerMediaKitRegistry;
import 'package:pure_live/features/vod/music/bilibili_music_source.dart';
import 'package:pure_live/features/vod/vod_page.dart' show vodClientProvider;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The music page: search the platform's videos as songs, queue them in
/// media_core_audio and play through it.
///
/// Playback is media_core's own music module — the kernel opens the audio
/// stream, the module owns the queue, play modes and lyric loading, and the
/// page renders its state stream. The one platform piece is the source
/// adapter, which carries Bilibili's headers and search.
final class MusicPage extends ConsumerStatefulWidget {
  /// The music page.
  const new({super.key});

  @override
  ConsumerState<MusicPage> createState() => _MusicPageState();
}

final class _MusicPageState extends ConsumerState<MusicPage> {
  final TextEditingController _keyword = TextEditingController();
  late final PlayerKernel _kernel = PlayerKernel();
  late final AudioPlaybackController _player;
  StreamSubscription<AudioPlaybackState>? _states;
  AudioPlaybackState _state = AudioPlaybackState.idle;
  List<MusicTrack> _results = const [];
  bool _loading = false;
  Object? _failure;

  @override
  void initState() {
    super.initState();
    registerMediaKitRegistry(_kernel.registry);
    _player = AudioPlaybackController(
      _kernel,
      registry: MusicSourceRegistry([BilibiliMusicSource(ref.read(vodClientProvider))]),
    );
    _states = _player.stateStream.listen((state) {
      if (mounted) {
        setState(() => _state = state);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_states?.cancel());
    unawaited(_player.dispose());
    unawaited(_kernel.dispose());
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
      final source = BilibiliMusicSource(ref.read(vodClientProvider));
      final page = await source.search(keyword);
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
    await _player.setQueue(_results, startIndex: index);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final state = _state;
    final track = state.track;
    return PureScaffold(
      appBar: PureAppBar(title: t.music.title),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(PureSpacing.md, PureSpacing.sm, PureSpacing.md, PureSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: PureTextField(
                    key: const ValueKey('music-search'),
                    controller: _keyword,
                    placeholder: t.music.searchHint,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => unawaited(_search()),
                  ),
                ),
                const SizedBox(width: 8),
                PureIconButton(icon: Icons.search, tooltip: t.music.search, onPressed: () => unawaited(_search())),
              ],
            ),
          ),
          if (_failure != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PureSpacing.md),
              child: Text(t.errors.network, style: theme.text.bodySmall.copyWith(color: theme.colors.error)),
            ),
          Expanded(
            child: _loading && _results.isEmpty
                ? const Center(child: PureSpinner(size: 32))
                : _results.isEmpty
                ? Center(
                    child: PureEmpty(title: t.music.empty, icon: Icons.music_note_outlined),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final entry = _results[index];
                      final current = track != null && track.id == entry.id && track.sourceId == entry.sourceId;
                      return ListTile(
                        key: ValueKey('music-track-${entry.id}'),
                        leading: Icon(
                          current ? Icons.graphic_eq : Icons.music_note_outlined,
                          color: current ? theme.colors.primary : theme.colors.textSecondary,
                        ),
                        title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          [entry.artist, if (entry.duration != null) _duration(entry.duration!)].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => unawaited(_play(index)),
                      );
                    },
                  ),
          ),
          // The now-playing bar: what media_core_audio reports.
          if (track != null) _nowPlaying(context, theme, state),
        ],
      ),
    );
  }

  Widget _nowPlaying(BuildContext context, PureTheme theme, AudioPlaybackState state) {
    final t = context.t;
    final track = state.track!;
    final total = state.duration.inMilliseconds == 0 ? 1.0 : state.duration.inMilliseconds.toDouble();
    return Material(
      color: theme.colors.bgContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(PureSpacing.md, 6, PureSpacing.md, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.text.body),
                        Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.text.caption),
                      ],
                    ),
                  ),
                  PureIconButton(
                    key: const ValueKey('music-mode'),
                    icon: switch (state.mode) {
                      PlayMode.list => Icons.repeat,
                      PlayMode.listLoop => Icons.repeat_on,
                      PlayMode.singleLoop => Icons.repeat_one,
                      PlayMode.random => Icons.shuffle,
                    },
                    tooltip: t.music.mode,
                    onPressed: () => _player.setPlayMode(switch (state.mode) {
                      PlayMode.list => PlayMode.listLoop,
                      PlayMode.listLoop => PlayMode.singleLoop,
                      PlayMode.singleLoop => PlayMode.random,
                      PlayMode.random => PlayMode.list,
                    }),
                  ),
                  PureIconButton(
                    icon: Icons.skip_previous,
                    tooltip: t.music.previous,
                    onPressed: () => unawaited(_player.previous()),
                  ),
                  PureIconButton(
                    key: const ValueKey('music-toggle'),
                    icon: state.playing ? Icons.pause : Icons.play_arrow,
                    tooltip: state.playing ? t.music.pause : t.music.play,
                    onPressed: () => unawaited(_player.toggle()),
                  ),
                  PureIconButton(
                    icon: Icons.skip_next,
                    tooltip: t.music.next,
                    onPressed: () => unawaited(_player.next()),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(_duration(state.position), style: theme.text.caption),
                  Expanded(
                    child: Slider(
                      value: (state.position.inMilliseconds / total).clamp(0.0, 1.0),
                      onChanged: (value) => unawaited(
                        _player.seek(Duration(milliseconds: (value * state.duration.inMilliseconds).round())),
                      ),
                    ),
                  ),
                  Text(_duration(state.duration), style: theme.text.caption),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _duration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return value.inHours > 0 ? '${value.inHours}:$minutes:$seconds' : '$minutes:$seconds';
  }
}
