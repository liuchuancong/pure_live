import 'package:flame_barrage/flame_barrage.dart';

class BarrageMessage {
  const BarrageMessage({
    required this.id,
    required this.content,
    required this.timestamp,
    this.type = BarrageType.scroll,
    this.userId,
    this.userName,
    this.priority = 0,
  });

  /// 消息唯一ID
  final String id;

  /// 弹幕内容
  final String content;

  /// 消息时间
  final DateTime timestamp;

  /// 弹幕类型
  final BarrageType type;

  /// 用户ID
  final String? userId;

  /// 用户昵称
  final String? userName;

  /// 优先级
  final int priority;
}
