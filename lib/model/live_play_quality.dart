import 'dart:convert';

import 'live_play_quality_play_url_info.dart';

class LivePlayQuality {
  /// 清晰度
  String quality;

  /// 清晰度信息
  final dynamic data;

  final int sort;

  /// 码率
  /// 流畅 250
  /// 标清 500
  /// 高清 1000
  /// 超清 2000
  /// 蓝光4M 4000
  /// 蓝光8M 8000
  /// 蓝光10M 10_000
  /// 蓝光20M 20_000
  /// 蓝光30M 30_000
  final int bitRate;

  /// 播放链接
  List<LivePlayQualityPlayUrlInfo> playUrlList = [];

  LivePlayQuality({
    required this.quality,
    required this.data,
    this.sort = 0,
    this.bitRate = 0,
  });

  @override
  String toString() {
    return json.encode({
      "quality": quality,
      "data": data.toString(),
      "sort": sort,
      "bitRate": bitRate,
    });
  }
}
