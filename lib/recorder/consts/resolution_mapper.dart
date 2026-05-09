class ResolutionMapper {
  /// 数值越大越清晰
  static const Map<String, int> levelMap = {
    // 原画
    "原画": 5,
    "蓝光8M": 5,
    "蓝光": 5,
    "1080P60": 5,

    // 超清
    "超清": 4,
    "蓝光4M": 4,
    "1080P": 4,

    // 高清
    "高清": 3,
    "720P": 3,

    // 标清
    "流畅": 2,
    "480P": 2,
  };

  static int getLevel(String quality) {
    return levelMap[quality] ?? 5; // 默认原画
  }
}
