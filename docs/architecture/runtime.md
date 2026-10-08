# PureLiveRuntime 运行时

> App 启动时组装的九大子运行时;App 是唯一组合根(Composition Root)。

## 1. 组装顺序(冷启动流)

```text
main()
 → Flutter binding + storage/logging 初始化(L0)
 → PureLiveRuntime 构建:
    1. CacheRuntime / DiagnosticRuntime    横向支撑先就位
    2. PluginRuntime.load()                内置 Native 插件注册 + JS/Data 插件从注册表恢复
    3. CapabilityRegistry.resolve()        能力发现(哪些源提供了哪些 capability)
    4. ContentRuntime / AccountRuntime     会话恢复(auth 状态事件重放)
    5. MediaRuntime                        空闲待命(无全局播放状态,Session 按需创建)
    6. ThemeRuntime / BackgroundSystem     令牌→主题、背景画布
    7. SyncRuntime.start()                 增量同步调度
 → MaterialApp.router + Experience 层
```

## 2. 子运行时职责

| Runtime | 职责 | 主文档 |
|---|---|---|
| ExtensionGateway | 扩展统一入口:注册/发现/类型识别/Runtime 选择/生命周期/隔离 | [platform-infrastructure.md](platform-infrastructure.md) |
| TaskScheduler | 统一后台任务调度(优先级/去重/重试):源刷新/仓库更新/插件更新/Ticket 刷新/缓存维护 | [platform-infrastructure.md](platform-infrastructure.md) |
| PluginRuntime | 插件装载、校验、沙箱、生命周期状态机 | [../plugin/plugin-lifecycle.md](../plugin/plugin-lifecycle.md) |
| CapabilityRuntime | CapabilityRegistry:发现/查询/按 capability 取 Provider 列表 | [../contracts/capability-contract.md](../contracts/capability-contract.md) |
| ContentRuntime | ContentRef 解析、跨域内容寻址 | [../content/content-ref.md](../content/content-ref.md) |
| MediaRuntime | MediaTicket/MediaPlan/PlaybackSession/Queue/Recovery/Watchdog/SegmentScheduler | [../media/media-architecture.md](../media/media-architecture.md) |
| AccountRuntime | Account/Session/auth.expired 事件广播 | [../services/auth.md](../services/auth.md) |
| SyncRuntime | 多设备增量同步与冲突合并 | [../services/sync.md](../services/sync.md) |
| CacheRuntime | 命名空间缓存与淘汰 | [../services/cache.md](../services/cache.md) |
| ThemeRuntime | 令牌文件 → WindThemeData/ColorScheme | [../contracts/theme-contract.md](../contracts/theme-contract.md) |
| DiagnosticRuntime | 追踪/播放诊断/诊断报告导出 | [../diagnostics/tracing.md](../diagnostics/tracing.md) |

## 3. 组合根规则

- 只有 App 允许知道全部包;包之间靠 Riverpod provider + 接口装配,禁止手动单例/服务定位器。
- Runtime 各组件只依赖抽象(契约),实现由 App 注入(Riverpod overrides)。
- Runtime 不持有 UI;Experience 层订阅 Runtime 状态。

## 4. 事件总线

横向基础设施 `EventBus`(L0 `pure_live_events`):`auth.expired`、`play.started/error/buffering`、`ticket.refresh`、`line.switch`、`plugin.enabled/disabled`、`sync.completed`、`download.completed`、`record.segment` 等。**禁止用事件总线替代正常接口依赖**——事件只用于广播型、多播型通知。
