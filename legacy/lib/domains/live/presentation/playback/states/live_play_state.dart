import 'ui_state.dart';
import 'room_state.dart';
import 'player_state.dart';
import 'danmaku_state.dart';
import 'package:flutter/foundation.dart';

@immutable
class LivePlayState {
  final RoomState room;
  final PlayerState player;
  final DanmakuState danmaku;
  final UIState ui;

  const LivePlayState({
    this.room = const RoomState(),
    this.player = const PlayerState(),
    this.danmaku = const DanmakuState(),
    this.ui = const UIState(),
  });

  LivePlayState copyWith({RoomState? room, PlayerState? player, DanmakuState? danmaku, UIState? ui}) {
    return LivePlayState(
      room: room ?? this.room,
      player: player ?? this.player,
      danmaku: danmaku ?? this.danmaku,
      ui: ui ?? this.ui,
    );
  }

  @override
  String toString() {
    return 'LivePlayState(\n'
        '  room: $room,\n'
        '  player: $player,\n'
        '  danmaku: $danmaku,\n'
        '  ui: $ui,\n'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LivePlayState &&
        other.room == room &&
        other.player == player &&
        other.danmaku == danmaku &&
        other.ui == ui;
  }

  @override
  int get hashCode => Object.hash(room, player, danmaku, ui);
}
