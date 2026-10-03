import 'package:media_core/media_core.dart';

/// 应用贴在 [PlayerSource] 上的容器格式声明。
///
/// 引擎只能靠探测猜容器，而探测在网络慢的线路上正好吃掉起播预算；平台解析播放
/// 地址时本来就知道每条线路是什么容器，把这个事实随源带过去，引擎就不用猜。
/// 值是 `LiveStreamFormat` 的名字（`hls` / `flv` / `other`）——Core 不能反向依赖
/// shared 层的枚举，所以这里只认字符串。
const String kPlaybackStreamFormatKey = 'pure_live.stream_format';

/// 把平台声明的容器格式打包成 [PlayerSource.metadata]；没有声明就是空表，
/// 让读的一方回退到 URL 形状。
Map<String, Object?> playbackStreamFormatMetadata(String? formatName) =>
    formatName == null ? const <String, Object?>{} : <String, Object?>{kPlaybackStreamFormatKey: formatName};

/// 源上声明的容器格式名字；没声明时为 null。
String? declaredStreamFormatOf(PlayerSource source) {
  final value = source.metadata[kPlaybackStreamFormatKey];
  return value is String && value.isNotEmpty ? value : null;
}

/// 是否是本仓自己起的本机输入：回环中继，或自有配方（`owned:` 这类自定义协议）。
///
/// 这类输入有两件事和远端源相反：不能送进代理（本机端口经代理转发既多一跳，也会
/// 被拒绝本地目标的代理直接打死），也不需要为它猜容器（本机读一次的代价远低于猜错
/// 的代价，而 Dart 重写的 HEVC FLV 中继输出的就不是 HLS）。
bool isPrivatePlaybackInput(Uri uri) {
  if (!const {'http', 'https'}.contains(uri.scheme.toLowerCase())) return true;
  final host = uri.host.toLowerCase();
  return host == 'localhost' || host == '::1' || host.startsWith('127.');
}
