import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core/media_core.dart' show PlayerKernel;
import 'package:media_core_audio/media_core_audio.dart'
    show AudioPlaybackController, AudioPlaybackState, MusicSourceRegistry;
import 'package:media_core_media_kit/media_core_media_kit.dart' show registerMediaKitRegistry;
import 'package:pure_live/features/vod/music/bilibili_music_source.dart';
import 'package:pure_live/features/vod/music/lyric_provider.dart' show lyricProvider;
import 'package:pure_live/features/vod/vod_page.dart' show vodClientProvider;

/// The music module's player, shared by the phone page and the TV pane: one
/// kernel with the media_kit backend, one controller over the platform
/// sources, disposed when the last page that watched it goes away.
// riverpod's family/autoDispose types are not exported by flutter_riverpod.
// ignore: specify_nonobvious_property_types
final musicPlayerProvider = Provider.autoDispose<AudioPlaybackController>((ref) {
  final kernel = PlayerKernel();
  registerMediaKitRegistry(kernel.registry);
  final controller = AudioPlaybackController(
    kernel,
    registry: MusicSourceRegistry([
      BilibiliMusicSource(ref.watch(vodClientProvider), lyrics: ref.watch(lyricProvider)),
    ]),
  );
  ref.onDispose(() {
    unawaited(controller.dispose());
    unawaited(kernel.dispose());
  });
  return controller;
});

/// The controller's state as a stream provider, so both pages render the
/// same answers and neither owns the subscription.
// ignore: specify_nonobvious_property_types
final musicStateProvider = StreamProvider.autoDispose<AudioPlaybackState>(
  (ref) => ref.watch(musicPlayerProvider).stateStream,
);
