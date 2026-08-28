import 'package:pure_live/player/models/player_engine.dart';

class PlayerSession {
  const PlayerSession({required this.id, required this.engine});

  final int id;
  final PlayerEngine engine;
}

class PlayRequest {
  const PlayRequest({required this.id, required this.playerSession});

  final int id;
  final PlayerSession playerSession;
}
