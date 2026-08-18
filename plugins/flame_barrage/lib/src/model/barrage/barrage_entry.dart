import 'dart:ui';
import 'barrage_item.dart';

class BarrageEntry {
  BarrageEntry({required this.item, required this.creationTime});

  // =========================
  // 基础数据
  // =========================
  BarrageItem item;

  /// 创建时间（逻辑时间）
  int creationTime;

  // =========================
  // 位置
  // =========================
  double x = 0;
  double y = 0;
  double width = 0;
  double height = 0;

  int track = -1;
  double speed = 0;
  bool active = true;

  // =========================
  // 🧠 v2 时间系统（核心）
  // =========================

  /// 弹幕进入屏幕时间
  int spawnTime = 0;

  /// 结束时间（fixed / scroll统一用这个）
  int expireTime = 0;

  /// 上次更新位置时间（用于 delta motion）
  int lastUpdateTime = 0;

  // =========================
  // 渲染缓存
  // =========================
  Paragraph? paragraph;
  Paragraph? strokeParagraph;
  Picture? picture;
  String? pictureCacheKey;

  double? cachedWidth;

  // =========================
  // reset（必须同步 v2 字段）
  // =========================
  void reset({required BarrageItem newItem, required int newCreationTime}) {
    item = newItem;

    creationTime = newCreationTime;

    x = 0;
    y = 0;
    width = 0;
    height = 0;

    track = -1;
    speed = 0;
    active = true;

    spawnTime = 0;
    expireTime = 0;
    lastUpdateTime = 0;

    paragraph = null;
    strokeParagraph = null;
    picture = null;
    pictureCacheKey = null;
    cachedWidth = null;
  }
}
