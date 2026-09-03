import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/player/models/player_engine.dart';

class PlayerSession {
  const PlayerSession({required this.id, required this.engine, this.audioOnly = false});

  final int id;
  final PlayerEngine engine;
  final bool audioOnly;

  PlayerSession copyWith({int? id, PlayerEngine? engine, bool? audioOnly}) {
    return PlayerSession(
      id: id ?? this.id,
      engine: engine ?? this.engine,
      audioOnly: audioOnly ?? this.audioOnly,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlayerSession &&
        other.id == id &&
        other.engine == engine &&
        other.audioOnly == audioOnly;
  }

  @override
  int get hashCode => Object.hash(id, engine, audioOnly);
}

class PlayRequest {
  const PlayRequest({
    required this.id,
    required this.playerSession,
    required this.url,
    required this.playUrls,
    required this.headers,
    this.room,
    this.status = PlayRequestStatus.pending,
    this.startTime,
  });

  final int id;
  final PlayerSession playerSession;
  final String url;
  final List<String> playUrls;
  final Map<String, String> headers;
  final LiveRoom? room;
  final PlayRequestStatus status;
  final DateTime? startTime;

  PlayRequest copyWith({
    int? id,
    PlayerSession? playerSession,
    String? url,
    List<String>? playUrls,
    Map<String, String>? headers,
    LiveRoom? room,
    PlayRequestStatus? status,
    DateTime? startTime,
  }) {
    return PlayRequest(
      id: id ?? this.id,
      playerSession: playerSession ?? this.playerSession,
      url: url ?? this.url,
      playUrls: playUrls ?? this.playUrls,
      headers: headers ?? this.headers,
      room: room ?? this.room,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
    );
  }

  bool get isPending => status == PlayRequestStatus.pending;
  bool get isActive => status == PlayRequestStatus.active;
  bool get isCompleted => status == PlayRequestStatus.completed;
  bool get isFailed => status == PlayRequestStatus.failed;

  // 检查请求是否仍然有效（未被取消或过期）
  bool isValid(PlayerSession currentSession, {Duration maxAge = const Duration(seconds: 30)}) {
    if (status == PlayRequestStatus.cancelled || status == PlayRequestStatus.completed) {
      return false;
    }
    if (playerSession.id != currentSession.id) {
      return false;
    }
    if (startTime != null && DateTime.now().difference(startTime!) > maxAge) {
      return false;
    }
    return true;
  }
}

enum PlayRequestStatus {
  pending, // 等待执行
  active, // 执行中
  completed, // 已完成
  failed, // 失败
  cancelled, // 已取消
}
