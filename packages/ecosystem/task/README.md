# pure_live_task

> 职责:统一后台任务调度:Task 契约、优先级队列、按 deduplicationKey 去重与取消语义

| 项 | 规则 |
|---|---|
| 层 | ecosystem(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation;契约与模型包是纯 Dart,禁止 Flutter 依赖。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_task.dart`;内部实现放 `lib/src/` |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src/cancellation.dart` —— `CancellationToken` 与 `TaskCancelledException`
- `lib/src/task.dart` —— `Task`(descriptor / run / cancel)与 `TaskContext`
- `lib/src/task_scheduler.dart` —— `TaskScheduler` 契约与 `TaskHandle`
- `lib/src/in_memory_task_scheduler.dart` —— 单 isolate 内的调度实现
- 数据模型 `TaskDescriptor` / `TaskPriority` / `TaskState` / `TaskStatus` / `TaskResult` 在 `pure_live_platform`
  (models §13),划分理由见 [docs/adr/0018-contract-package-split.md](../../../docs/adr/0018-contract-package-split.md)

## 规则(规范来自 platform-contracts.md §16、platform-infrastructure.md §7.3)

1. **全平台一个调度器**:Source 更新 / 仓库刷新 / EPG / 插件更新 / 下载 / 同步 / 备份 / Ticket 刷新 /
   Cookie 刷新 / 缓存清理都从这里走,优先级与去重才有统一含义。
2. **去重**:`deduplicationKey` 相同的 pending/running 任务只留一个,第二次 `submit` 返回同一个 handle
   —— 三个 "Refresh TVBox A" 必须只跑一次。同 `id` 重复提交同样幂等。
3. **优先级**:`critical > high > normal > low > background`,同优先级按提交顺序;槽位空了才取下一个
   (`maxConcurrent`,默认 3)。
4. **取消不是失败**(models §20 不变量 9):终态是 `cancelled`,结果为
   `PlatformErrorCodes.taskCancelled` 且 `recoverable: true`;`handle.result` 正常 complete,不抛异常。
   运行中的任务先 `token.cancel()`,再 `await task.cancel()` 让持有资源的一方自行释放。
5. **pause 只对 pending 有效**:运行中的任务没有协作式暂停语义,`pause` 返回 false;`resume` 重新入队。
6. **失败口径统一**:任务 `throw` 与返回 `TaskResult(success: false)` 都记 `failed`(带 `task.failed` 或
   任务自己的错误码),调用方读到的状态不取决于任务选了哪种表达方式。
7. **有界留存**:`find()` 只保留最近 `finishedLimit`(默认 64)条终态记录;先前的 handle 仍能读到自己的真实
   终态,不会被淘汰动作改成假状态。

`CancellationToken` 是平台侧类型:media_core 的 `TaskCancelToken` 属 Player 域且依赖 Flutter,按 models §2
在 `pure_live_media` 接线层映射(与 ADR 0016 对 MediaTrack 的处理一致)。

## 已知边界

- 单 isolate,无持久化:进程重启后 pending 任务不会恢复(持久任务队列属于后续需求,不做提前设计)。
- `TaskDescriptor.networkRequired` / `backgroundAllowed` 目前只是**记录**字段,调度器不读它们;网络门控随
  设备状态源( connectivity / lifecycle )一起接,免得凭空的判断逻辑假装它们已生效。
- 诊断 Trace 关联:调度器只发 `TaskStatus` 事件流。`TaskContext` 暂不带 `traceId` —— 没有生产者之前放一个
  永远为 null 的字段只会假装已接线;诊断 trace 随 `ecosystem/extension` 的 `ExtensionContext` 一起补。

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
