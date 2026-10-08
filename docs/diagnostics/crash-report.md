# Crash Report(崩溃报告)

## 分层

- **Dart 异常**:FlutterError + PlatformDispatcher.onError → 记录 + 分组。
- **插件异常**:沙箱内捕获(见 plugin-security),按插件聚合,不进全局崩溃。
- **原生崩溃**:占用极低预期;以符号化友好的系统日志提示为主(深入崩溃收集待后续评估)。

## 收集

本地聚合(近 N 条,含堆栈摘要/设备/版本/最近播放诊断标签);firebase 已保留——crashlytics 接入与否在发布阶段决定(隐私开关,默认关)。

## 规则

- 崩溃报告默认**脱敏**(无 URL 参数/无凭据/无播放历史)。
- 崩溃率是发布门禁指标(W12 release)。
