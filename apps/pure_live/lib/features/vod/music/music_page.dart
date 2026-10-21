import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:media_core_audio/media_core_audio.dart'
    show AudioPlaybackState, LyricDocument, LyricLine, MusicTrack, PlayMode;
import 'package:pure_live/app/app_providers.dart' show environmentProvider;
import 'package:pure_live/features/vod/music/bilibili_music_source.dart';
import 'package:pure_live/features/vod/music/music_player.dart';
import 'package:pure_live/features/vod/vod_page.dart' show vodClientProvider;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/tv/features/music/tv_music_view.dart';
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

  /// The state the page last rendered; the provider's stream keeps it
  /// current.
  AudioPlaybackState _state = AudioPlaybackState.idle;
  List<MusicTrack> _results = const [];

  /// The current track's lyric, when the source has one; null hides the
  /// strip.
  LyricDocument? _lyric;

  /// The track the lyric was loaded for, so a track change reloads.
  String? _lyricTrack;
  bool _loading = false;
  Object? _failure;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  /// Loads the current track's lyric once per track; the module caches, so a
  /// re-load costs nothing.
  Future<void> _loadLyric(MusicTrack? track) async {
    final key = track == null ? null : '${track.sourceId}:${track.id}';
    if (key == _lyricTrack) {
      return;
    }
    _lyricTrack = key;
    if (key == null) {
      if (mounted) {
        setState(() => _lyric = null);
      }
      return;
    }
    try {
      final document = await ref.read(musicPlayerProvider).loadCurrentLyric();
      if (mounted && _lyricTrack == key) {
        setState(() => _lyric = document.lines.isEmpty ? null : document);
      }
    } on Object {
      if (mounted && _lyricTrack == key) {
        setState(() => _lyric = null);
      }
    }
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
    await ref.read(musicPlayerProvider).setQueue(_results, startIndex: index);
  }

  @override
  Widget build(BuildContext context) {
    // The TV draws its own pane over the same controller and state stream.
    if (ref.read(environmentProvider).runtime.formFactor == FormFactor.tv) {
      return const PureScaffold(
        appBar: PureAppBar(title: '音乐'),
        body: TvMusicView(),
      );
    }
    // The module's state stream, watched through the provider the TV pane
    // reads too; a track change reloads the lyric once.
    final incoming = ref.watch(musicStateProvider).value;
    if (incoming != null) {
      _state = incoming;
      unawaited(_loadLyric(incoming.track));
    }
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
          // The lyric strip: the module's parsed LRC, synced to the position
          // it reports; a tap on a line seeks to it.
          if (track != null && _lyric != null) _lyricStrip(context, theme, state, _lyric!),
          // The now-playing bar: what media_core_audio reports.
          if (track != null) _nowPlaying(context, theme, state),
        ],
      ),
    );
  }

  /// Three lines of the lyric around the current one, the middle emphasised;
  /// unsynchronised documents show the first three and no current line.
  Widget _lyricStrip(BuildContext context, PureTheme theme, AudioPlaybackState state, LyricDocument lyric) {
    final index = lyric.isSynchronized ? lyric.indexAt(state.position) : 0;
    final window = <LyricLine>[
      for (var at = index - 1; at <= index + 1; at++)
        if (at >= 0 && at < lyric.lines.length) lyric.lines[at],
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: PureSpacing.md, vertical: PureSpacing.sm),
      color: theme.colors.bgContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in window)
            GestureDetector(
              onTap: lyric.isSynchronized ? () => unawaited(ref.read(musicPlayerProvider).seek(line.start)) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  [
                    line.text,
                    if (line.translation != null && line.translation!.isNotEmpty) line.translation!,
                  ].join('\n'),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.text.bodySmall.copyWith(
                    fontSize: line == (lyric.isSynchronized ? lyric.lineAt(state.position) : null) ? 15 : 12.5,
                    color: line == (lyric.isSynchronized ? lyric.lineAt(state.position) : null)
                        ? theme.colors.primary
                        : theme.colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
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
                    onPressed: () => ref.read(musicPlayerProvider).setPlayMode(switch (state.mode) {
                      PlayMode.list => PlayMode.listLoop,
                      PlayMode.listLoop => PlayMode.singleLoop,
                      PlayMode.singleLoop => PlayMode.random,
                      PlayMode.random => PlayMode.list,
                    }),
                  ),
                  PureIconButton(
                    icon: Icons.skip_previous,
                    tooltip: t.music.previous,
                    onPressed: () => unawaited(ref.read(musicPlayerProvider).previous()),
                  ),
                  PureIconButton(
                    key: const ValueKey('music-toggle'),
                    icon: state.playing ? Icons.pause : Icons.play_arrow,
                    tooltip: state.playing ? t.music.pause : t.music.play,
                    onPressed: () => unawaited(ref.read(musicPlayerProvider).toggle()),
                  ),
                  PureIconButton(
                    icon: Icons.skip_next,
                    tooltip: t.music.next,
                    onPressed: () => unawaited(ref.read(musicPlayerProvider).next()),
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
                        ref
                            .read(musicPlayerProvider)
                            .seek(Duration(milliseconds: (value * state.duration.inMilliseconds).round())),
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
