/// 显式传递单个所选 HLS 源的 query token。
///
/// 类型本身与播放无关（录制中继、站点适配器和播放输入都用它），实现已移入
/// `media_core_ingest`；这里保留导入路径，避免一次性改动十几个调用点。
library;

export 'package:media_core_ingest/media_core_ingest.dart' show HlsSourceQueryPolicy;