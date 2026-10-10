# pure_live_diagnostics

> 职责:崩溃报告、trace 与播放诊断的数据面

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_diagnostics.dart`;内部实现放 `lib/src/` |

## 内容

- `recording.dart` —— `RingBuffer`(定容 + 丢条计数)、`runGuarded`(同步/异步/逃出 zone 的错误都落到同一个 onError)、`measure`(失败也报耗时并原样上抛)

这里只有**机制**。要离开设备的诊断词汇(`DiagnosticEvent` / `DiagnosticTrace` / `PlatformErrorInfo`)定义在 `pure_live_platform`;把它们留在 L1,这个 L0 包就不用向上指。

## 
## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)

## 行为契约(2026-10-10 起)

- `RingBuffer` 是真环形:满时移动 head 而不是 `removeAt(0)`(后者每次 add 复制整个尾巴,而这个缓冲区
  在整个会话期内每个诊断事件都要写)。`droppedCount` 非 0 表示"这份视图是残缺的"。
- `measure` 用 `Stopwatch`(单调),不再拿两次 `DateTime.now()` 相减:墙钟会被 NTP 校正、用户改时间、
  唤醒后时区变化往回拨,那时旧实现报出**负时长** —— 面板读成"瞬时",阈值判断读成"可以忽略"。
- `runGuarded` 现在也守护 `onError` 自己:报告器抛异常(诊断文件被锁是常见一种)以前会让调用方
  永远等一个不会完成的 future。现在它照旧返回/抛出,不挂死也不吞掉 body 的原因。

## 未验证

- 只有一个消费者(`ecosystem/extension` 的内存 tracer)。18 个测试覆盖机制本身;
  "诊断真正落到设备上"的路径不在本包内,也未验证。
