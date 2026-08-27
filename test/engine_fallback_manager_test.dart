import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/player/core/engine_fallback_manager.dart';
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/player/models/player_error_type.dart';
import 'package:pure_live/player/models/player_exception.dart';

void main() {
  test('the first confirmed terminal decoder failure selects another engine', () async {
    final manager = EngineFallbackManager(
      defaultEngine: PlayerEngine.mediaKit,
      supportedEngines: const <PlayerEngine>[PlayerEngine.mediaKit, PlayerEngine.fijk],
    );

    final next = await manager.fallback(
      PlayerEngine.mediaKit,
      PlayerException(message: 'decoder initialization failed', type: PlayerErrorType.codec),
    );

    expect(next, PlayerEngine.fijk);
  });

  test('an explicit retry budget can retain the same engine before fallback', () async {
    final manager = EngineFallbackManager(
      defaultEngine: PlayerEngine.mediaKit,
      maxRetryCount: 2,
      supportedEngines: const <PlayerEngine>[PlayerEngine.mediaKit, PlayerEngine.exo],
    );
    final error = PlayerException(message: 'source failed', type: PlayerErrorType.source);

    expect(await manager.fallback(PlayerEngine.mediaKit, error), PlayerEngine.mediaKit);
    expect(await manager.fallback(PlayerEngine.mediaKit, error), PlayerEngine.exo);
  });

  test('fallback priority starts from the configured user engine', () async {
    final manager = EngineFallbackManager(
      defaultEngine: PlayerEngine.fijk,
      supportedEngines: const <PlayerEngine>[PlayerEngine.mediaKit, PlayerEngine.fijk, PlayerEngine.exo],
    );
    final error = PlayerException(message: 'decoder failed', type: PlayerErrorType.codec);

    expect(await manager.fallback(PlayerEngine.fijk, error), PlayerEngine.mediaKit);
  });
}
