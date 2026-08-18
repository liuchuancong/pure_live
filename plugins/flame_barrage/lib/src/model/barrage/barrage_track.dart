import 'package:flame_barrage/src/model/barrage/barrage_entry.dart';

class BarrageTrack {
  BarrageTrack({required this.index});

  final int index;

  /// 最右边界
  double lastRight = 0;

  /// 当前轨道弹幕数
  int activeCount = 0;

  /// 固定弹幕占用
  bool locked = false;

  /// 最近一次发射时间
  int lastLaunchTime = 0;

  BarrageEntry? lastEntry;

  double avgSpeed = 0;

  double density = 0;
}
