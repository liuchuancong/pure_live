import 'package:flutter/foundation.dart';
import 'package:pure_live/common/index.dart';

@immutable
class DanmakuState {
  final List<LiveMessage> messages;
  final String? currentDanmakuRoomId;

  const DanmakuState({this.messages = const [], this.currentDanmakuRoomId});

  DanmakuState copyWith({List<LiveMessage>? messages, String? currentDanmakuRoomId}) {
    return DanmakuState(
      messages: messages ?? this.messages,
      currentDanmakuRoomId: currentDanmakuRoomId ?? this.currentDanmakuRoomId,
    );
  }

  DanmakuState clearMessages() {
    return DanmakuState(messages: [], currentDanmakuRoomId: currentDanmakuRoomId);
  }

  @override
  String toString() {
    return 'DanmakuState(\n'
        '  messages: ${messages.length} items,\n'
        '  currentDanmakuRoomId: $currentDanmakuRoomId,\n'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DanmakuState &&
        listEquals(other.messages, messages) &&
        other.currentDanmakuRoomId == currentDanmakuRoomId;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(messages), currentDanmakuRoomId);
}
