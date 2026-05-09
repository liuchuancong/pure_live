enum RecordStatus {
  idle, // 未开始（已创建任务）
  queued, // 排队中（达到并发上限）
  preparing, // 准备中（解析流/线路/清晰度）
  running, // 录制中
  reconnecting, // 断线重连中
  processing, //正在合并 TS 为 MP4
  completed, // 正常完成（手动或流结束）
  failed, // 失败（不可恢复或重试结束）
  stopped, // 用户手动停止
}
