import 'dart:convert';

class LivePlayQualityPlayUrlInfo {
  /// 播放链接
  String playUrl;

  ///  额外信息
  String info = "";

  LivePlayQualityPlayUrlInfo({
    required this.playUrl,
    this.info = "",
  });

  @override
  String toString() {
    return json.encode({
      "playUrl": playUrl,
      "info": info.toString(),
    });
  }
}
