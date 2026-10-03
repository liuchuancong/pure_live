/// 单个 HLS 中继的内存 cookie 集（受长度与条数上限约束）。
///
/// 实现已移入 `media_core_ingest`（回环 ingest 中继与录制中继共用），这里保留
/// 导入路径供录制侧与站点适配器继续引用。
library;

export 'package:media_core_ingest/media_core_ingest.dart' show HlsSessionCookies;