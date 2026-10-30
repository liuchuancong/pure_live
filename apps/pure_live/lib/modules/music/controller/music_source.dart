import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/app/providers/network/network_providers.dart' show networkFactoryProvider;

import 'package:pure_live/modules/music/controller/lx_script_runtime.dart';
import 'package:pure_live/modules/music/controller/music_settings.dart';
import 'package:pure_live/modules/music/controller/music_source_swaps.dart' show musicSourceSwapsProvider;
import 'package:pure_live/modules/music/controller/sources/music_display_lyric.dart' show DisplayLyricSource;
import 'package:pure_live/modules/music/controller/sources/music_source_cache.dart' show CachedLyricSource;
import 'package:pure_live/modules/music/controller/sources/music_source_kg.dart' show KgMusicSource;
import 'package:pure_live/modules/music/controller/sources/music_source_kw.dart' show KwMusicSource;
import 'package:pure_live/modules/music/controller/sources/music_source_match.dart' show findSameSong;
import 'package:pure_live/modules/music/controller/sources/music_source_mg.dart' show MgMusicSource;
import 'package:pure_live/modules/music/controller/sources/music_source_tx.dart' show TxMusicSource;
import 'package:pure_live/modules/music/controller/sources/music_source_wy.dart' show WyMusicSource;

/// The platform key lx-music uses for Kuwo; the module's default source.
const String kLxMusicSourceId = 'kw';

/// Every built-in platform the module speaks, each a lx-music source with a
/// lyric cache in front of it.
final musicSourceListProvider = Provider<List<audio.MusicSource>>((ref) {
  final runtime = ref.watch(lxScriptRuntimeProvider);
  final transport = ref.watch(networkFactoryProvider).create(profile: ClientProfile.api);
  MusicSettings settingsOf() => ref.read(musicSettingsProvider);
  return [
    DisplayLyricSource(CachedLyricSource(KwMusicSource(runtime, transport)), settingsOf: settingsOf),
    DisplayLyricSource(CachedLyricSource(KgMusicSource(runtime, transport)), settingsOf: settingsOf),
    DisplayLyricSource(CachedLyricSource(TxMusicSource(runtime, transport)), settingsOf: settingsOf),
    DisplayLyricSource(CachedLyricSource(WyMusicSource(runtime, transport)), settingsOf: settingsOf),
    DisplayLyricSource(CachedLyricSource(MgMusicSource(runtime, transport)), settingsOf: settingsOf),
  ];
});

/// The module's active source: the viewer's default, or Kuwo when unset.
final musicSourceProvider = Provider<audio.MusicSource>((ref) {
  final sources = ref.watch(musicSourceListProvider);
  final preferred = ref.watch(musicSettingsProvider).defaultSourceId;
  for (final source in sources) {
    if (source.id == preferred) return source;
  }
  return sources.first;
});

/// The Kuwo source itself; its own endpoints (hot words, comments) hang off
/// the platform rather than the active source.
final kwMusicSourceProvider = Provider<KwMusicSource>((ref) {
  final runtime = ref.watch(lxScriptRuntimeProvider);
  final transport = ref.watch(networkFactoryProvider).create(profile: ClientProfile.api);
  return KwMusicSource(runtime, transport);
});

/// lx-music's 换源 resolve: the track's own platform is asked first, and when
/// it refuses, the other platforms are searched for the same song and the
/// first one that resolves wins. A manual swap from the viewer rides above
/// every attempt.
Future<audio.TrackSource> resolveWithToggle(Ref ref, audio.MusicTrack track, {audio.MusicQuality? quality}) async {
  final sources = ref.read(musicSourceListProvider);
  final swapped = ref.read(musicSourceSwapsProvider.notifier).swappedOf(track);
  if (swapped != null) {
    for (final source in sources) {
      if (source.id != swapped.sourceId) continue;
      try {
        return await source.resolveTrackSource(swapped, quality: quality);
      } on Object {
        break;
      }
    }
  }
  var own = ref.read(musicSourceProvider);
  for (final source in sources) {
    if (source.id == track.sourceId) own = source;
  }
  try {
    return await own.resolveTrackSource(track, quality: quality);
  } on Object {
    // Fall through to the other platforms.
  }
  for (final source in sources) {
    if (source.id == track.sourceId) continue;
    try {
      final page = await source.search('${track.title} ${track.artist}', pageSize: 10);
      final match = findSameSong(track, page.items);
      if (match == null) continue;
      return await source.resolveTrackSource(match, quality: quality);
    } on Object {
      continue;
    }
  }
  throw StateError('no source could resolve ${track.title}');
}
