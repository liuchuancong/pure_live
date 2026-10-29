import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/lx_script_runtime.dart';
import 'package:pure_live/modules/music/controller/music_settings.dart';
import 'package:pure_live/modules/music/controller/sources/music_source_kg.dart';
import 'package:pure_live/modules/music/controller/sources/music_source_kw.dart';

/// The platform key lx-music uses for Kuwo; the module's default source.
const String kLxMusicSourceId = 'kw';

/// Every built-in platform the module speaks, each a lx-music source.
final musicSourceListProvider = Provider<List<audio.MusicSource>>((ref) {
  final runtime = ref.watch(lxScriptRuntimeProvider);
  return [KwMusicSource(runtime), KgMusicSource(runtime)];
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
  return KwMusicSource(runtime);
});
