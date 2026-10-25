# 多窗口共享存储与克隆窗口设计

> 最终模型：**每个窗口都是完整应用的克隆**，都运行 `PureLiveApp`，都有主页、
> 设置、房间路由。窗口之间共享同一份数据。
>
> 数据所有权：**仍然只有主窗口打开 SQLite**。克隆窗口没有数据库，读取来自
> 主窗口的仓储快照，写入以命令发回主窗口，主窗口落库后向所有窗口广播增量。
>
> 窗口层固定使用 `desktop_multi_window`，不引入 `multi_window_manager`。
>
> **已实施**：完整应用克隆窗口（主页/设置/房间路由）；主窗口唯一 SQLite；
> 克隆窗口 `RemoteJsonStore` 投影；namespace 快照/写入/广播；设置修订；
> 新窗口入口（侧栏 + Ctrl/Cmd+N）；房间作为初始路由时返回主页；同房间全局
> 去重；drift 存储与 Hive 移除。
>
> **窗口控制已实施（三个桌面平台）**：克隆窗口按 `window.chrome` 使用原生
> caption 或自绘标题栏，全部经扩展的 `pure_live/room_window` 通道控制自己的
> 顶层窗口（拖拽、最小化、最大化/还原、isMaximized、关闭、标题，Windows
> 保留 resize/snap）。Windows 的克隆全屏与 PiP 固定在自己的 HWND 上，不再
> 误操作主窗口。
>
> **系统媒体会话已实施**：主窗口独占唯一的 `audio_service` 驱动（Windows
> SMTC、Linux MPRIS、macOS 媒体面板）；克隆窗口把 kernel 的活跃播放器（房间、
> VOD、多画面）经窗口桥 claim/update/release，主窗口按最近 claim 呈现，并把
> 系统按钮转发回拥有窗口。直播不显示 seek 按钮。
>
> **仍缺**：旧 Hive 数据一次性导入；macOS/Linux 原生代码与跨窗口媒体条尚未
> 在本机编译/运行验证。

## 1. 模型纠正

之前的设计把子窗口当成“只装一个直播间的 panel”，因此只 seed 了设置、当前房间
的关注和录制任务。这是错的。

正确模型：

- **窗口 = 应用实例**，不是页面容器。每个窗口有自己的路由栈、主页、设置、
  房间、IPTV、VOD、多画面、录制中心。
- **数据 = 同一份**。一个窗口的关注、历史、设置、IPTV 源、多画面布局、录制
  任务，另一个窗口都看得到；设置改动即时同步。
- **数据库 = 主窗口唯一实例**。克隆窗口不打开 SQLite，不持 Hive，不做本地
  持久化；所有仓储读写通过窗口 RPC。

## 2. 数据路径

### 2.1 主窗口

```text
main window
  StorageBootstrap → StorageStores (Local)
  StoragePrefs / FollowRepository / HistoryRepository / ... 
        │  local writes
        ▼
  LocalStorageStores.changes (namespace, key, value)
        │
        ▼
  WindowStorageBridge (server)
        ├─ storage.snapshot(namespace) → entries
        ├─ storage.put/delete/putAll/clear
        └─ storage.changed(namespace, values) → every clone
```

- `LiveStorageStores` 的每个 `LocalJsonStore` 成功写入后，向
  `StorageStores.changes` 发一条 `{namespace, values}`；主窗口 UI 和克隆窗口
  都靠这条流获得真相。
- `WindowStorageBridge` 注册在当前主窗口通道上；克隆窗口发来的命令在这里执行。
- 主窗口自己页面的写入也走本地 store，因此同样广播给克隆窗口。

### 2.2 克隆窗口

```text
clone window
  WindowStorageClient (invokeMethod → main)
        │ snapshot(namespace) / put / delete / putAll / clear
        ▼
  StorageStores (Remote)
        ├─ RemoteJsonStore: 内存快照，读取同步
        ├─ 写命令成功后等待/应用 storage.changed
        └─ 收到变更 → 更新快照 → 发 watch/watchKeys
  Riverpod repositories / providers
```

- 克隆窗口启动时通过 `storage.snapshot(namespace)` 按需拉取 namespace；不预载
  全部 IPTV/VOD 文档。
- 写入是命令，返回值只表示主窗口接受；UI 先按 controller 的乐观状态更新，
  主窗口广播回来后以权威值为准。
- 每个克隆窗口有自己的内存快照，主窗口是唯一持久化者。
- 克隆在首帧前就 arm 变更通道；namespace 尚未打开时到达的 `storage.changed`
  先缓冲，等快照安装后再应用，避免启动窗口期丢写。
- 主窗口把克隆自己的写入原样广播回来；`RemoteJsonStore.applyChange` 做深比较，
  值未变化时不发通知，writer 正在编辑的 controller 不会被自己的回波重建。
- 每个 namespace 带单调 revision：快照返回读取时的 revision，广播带提交后的
  revision；克隆只接受 `last + 1`，发现跳号就重新拉取快照而不是应用一个缺少前提
  的增量。主窗口每 20s 发一次只带 revision 的心跳，补上最后一条广播丢失的情况。

### 2.3 设置即时同步

设置是跨窗口最敏感的一类，单靠 `StoragePrefs` 的静态读取不会让已存在的
Provider 重新读值，因此增加一个设置修订：

- 主窗口/克隆窗口收到 `settings` namespace 的变更时，bump
  `settingsRevisionProvider`。
- 根节点监听修订，重新读取主题、语言、字体、密度等根设置。
- 设置类 controller（播放、弹幕、盾牌、方向、浏览、导航、网络、刷新、搜索、
  录制、VOD、IPTV、背景等）watch 这个修订，或由 `WindowStorageBridge` 在
  收到 settings 变更时集中 invalidate；两种方式只选一种，避免重复重建。
- 列表类数据（关注、历史、录制、IPTV、多画面）不需要修订：它们的仓储直接
  watch `RemoteJsonStore`，增量到达就刷新。

### 2.4 系统媒体会话

系统每个应用只有一个媒体条（SMTC / MPRIS / 锁屏），`audio_service` 也不能在
同一进程初始化第二次。因此媒体条仍由主窗口唯一持有：

```text
clone kernel active player
  ⇄ media.claim / update / release（窗口桥，带 windowId）
primary WindowMediaSessionHub
  → MediaSessionDriver.presentRemote(item, state, target)
  → SMTC / MPRIS / 媒体面板
  ← 系统按钮
  → media.control(play/pause/seek/stop) → 拥有窗口
```

- 克隆窗口给 kernel 挂一个轻量 `KernelAudioDriver`，活跃播放器（房间、VOD、
  多画面）开始、暂停/恢复、换集或释放时上报；房间播放额外提供标题、主播、
  封面，其他播放器用 source 的标题与元数据。
- 主窗口维护每个窗口的 session 与 claim 顺序：新 claim 取得媒体条；owner 的
  update 刷新元数据/进度；release 后回退到最近仍在播放的窗口，否则清除并让
  主窗口自己的播放器接回。
- 系统按钮只发给 owner 窗口，由该窗口操作自己的 kernel/handle；窗口关闭、
  通道失败或进程退出时会释放，不会留下描述已消失窗口的媒体条。
- 直播没有真实时间轴：`seekable=false`，媒体条不显示前进/后退按钮；VOD 等
  有 duration 的播放保留 seek。
- 主窗口自己的播放器仍走原来的 kernel 绑定；本地播放开始会接管媒体条，本地
  暂停/停止后由主窗口的 reconcile 定时器把媒体条交回仍在播放的克隆窗口。

## 3. 窗口模型

### 3.1 窗口角色

- 主窗口：唯一 DB、托盘、关闭策略、退出流程。
- 克隆窗口：完整应用；出现在任务栏；关闭只销毁自己；没有托盘；不拥有进程
  生命周期。
- 关闭是“关这个窗口”，不是“退出应用”：主窗口关闭时若还有其它窗口，隐藏到
  托盘（无托盘则最小化），保留主引擎和数据库；只有托盘 Quit、确认框里选择
  退出或没有其它窗口时才销毁全部。显式 `shell_dismiss`/退出流程仍会关闭所有
  克隆。因关主窗口而隐藏的主窗口，在最后一个克隆关闭时会自动重新显示，避免
  应用只剩托盘。
- 浮窗/弹窗：保持现有 `WindowRole` 语义。

建议新增 `WindowRole.clone`（或复用 `panel` 但明确 `ownsAppState=false`
且 `showsInTaskbar=true`）。窗口角色只影响生命周期/托盘/关闭，不影响渲染的
页面集合。

### 3.2 启动

`main()` 仍按 `multi_window` 参数分流，但子窗口走完整 boot：

1. `PlatformBootstrap.init`；
2. 找主窗口，`WindowController.fromCurrentEngine` 拿自身；
3. 建 `WindowStorageClient`，`StorageStores.attachRemote(client)`；
4. 建 `ProviderContainer` 并注册 `WindowStorageBridge`（首帧前 arm 变更通道）；
5. `StoragePrefs.init()` 从 `RemoteJsonStore('settings')` 读设置；启动期间到达的
   变更由 remote stores 缓冲后应用；
6. 日志、播放器预热、图片缓存目录、窗口标题；
7. 读取 `window.chrome`，配置原生/自绘标题栏，并取自己的原生窗口句柄；
8. `runApp(UncontrolledProviderScope(container, child: PureLiveApp()))`。

`appRouterProvider` 的 `initialLocation` 改为从
`windowInitialRouteProvider` 读取：主窗口默认主页；克隆窗口用
`WindowArguments.route`，例如 `/room/bilibili/123`。

### 3.3 打开新窗口

- 房间卡片/搜索结果不再打开 room-only 窗口，而是打开一个克隆窗口，
  initialRoute 指向房间。
- 增加“新窗口”入口：侧栏 foot、自绘标题栏、Ctrl/Cmd+N、托盘菜单；克隆窗口
  自己也能再开窗口，拥有自己的 `SecondaryWindows`。
- 同一房间去重：扫描所有 `WindowController.getAll()` 的窗口参数，而不只是
  当前窗口的 `SecondaryWindows`；打开前把窗口导航回该房间，已在房间时只前置。
- 进程级窗口变化会把已关闭的窗口从 `SecondaryWindows` 清掉；旧记录调用失败时
  继续全局查找或新开窗口，不会卡在“窗口打不开就退回页内”的旧状态。

### 3.4 标题栏

- `window.chrome == system`：克隆窗口用原生 caption，不画 app strip；主窗口
  保持现有 chrome。
- `window.chrome == custom`：克隆窗口必须自绘。`window_manager` 不能可靠
  控制子引擎窗口，因此由扩展现有 `pure_live/room_window` 原生通道来操作
  克隆自己的顶层窗口：
  - Windows：隐藏原生 caption、保留 resize/snap、drag、min/max/restore、
    isMaximized、close、title；
  - macOS：隐藏标题、透明标题栏、`fullSizeContentView`（traffic lights 仍是
    系统的，嵌在 app 条内）；
  - Linux：GTK 去装饰、drag、min/max/restore。
- 全屏/PiP 的 Windows 后端通过通道取得的 HWND 固定到克隆窗口；进程级查找
  只会找到主窗口，固定后不会再让主窗口替克隆进全屏或被缩成小窗。
- macOS/Linux 上窗口插件按当前活动窗口解析，克隆窗口聚焦时由各自的
  window_manager 后端驱动；其原生通道仍需在对应平台上编译验证。

## 4. 与现有代码的差异

当前工作区的房间窗口实现（`runRoomWindow` / `RoomWindowBridge` /
`RoomLocalPrefs` / `RemoteFollowsController` / scoped 设置控制器）是错误模型
的产物，迁移时删除：

- 删除 `roomWindow.seed` 的 room-only 快照和 `RoomLocalPrefs`；
- 删除 `RemoteFollowsController`、`RemoteHistoryController`、
  `RemoteRecordingsController`、scoped 弹幕/播放控制器、
  `RoomShieldRulesController`、`RoomOrientationChoicesController`；
- 子窗口的所有仓储改为 `RemoteJsonStore`，不再为每个功能写远程控制器；
- 删除房间窗口专用的 `roomLeaveProvider` 覆盖；房间页回退用路由 pop；
- `openRoom` 改为打开完整克隆窗口；
- 主窗口的 `RoomWindowBridge` 替换为通用 `WindowStorageBridge`。

保留：

- `live_storage` 的 drift schema、`LocalJsonStore`、`StoragePrefs`；
- `desktop_multi_window` 和现有 Runner 的插件注册；
- `pure_live/room_window` 原生通道（扩展标题栏控制后继续用）。

## 5. 实施顺序

| 阶段 | 内容 | 验收 |
| --- | --- | --- |
| 1 | `JsonStore` 抽象出 `LocalJsonStore` / `RemoteJsonStore`；`StorageStores` 支持 local/remote；`StorageChange` 流 | live_storage 测试通过，主窗口行为不变 |
| 2 | 通用 `WindowStorageBridge`：snapshot、写命令、变更广播；克隆窗口 remote stores | 两窗口看到同一份关注/历史/设置；主窗口唯一 DB |
| 3 | 克隆窗口 boot：完整 `PureLiveApp`、initialRoute、`SecondaryWindows`；删除 room-only 路径 | 新窗口有主页/设置/房间，可独立导航 |
| 4 | 设置修订和集中 invalidate；根主题/语言即时更新 | 改主题/语言/播放/弹幕，另一窗口即时变化 |
| 5 | 子窗口原生/自绘标题栏控制（按平台） | `window.chrome` 两种模式都与主窗口一致 |
| 6 | 旧 Hive 数据导入工具（独立工具，不进 app 依赖） | 可选，按需 |

没有第 1–4 阶段，不能把子窗口改成克隆；否则只是“多了一个窗口”，数据仍然
是房间快照。

## 6. 并发与失败

- 只有主窗口写 SQLite；主窗口内部按 namespace 串行写，跨 namespace 不共享
  事务。设置类命令按 key 串行，last-write-wins。
- 克隆窗口的命令失败：`invokeMain` 有短重试；失败时 UI 保留乐观状态，主窗口
  不落库。下一次快照/重开恢复权威值。
- 广播失败：2s 超时后丢弃；主窗口的 20s revision 心跳会让克隆发现跳号并重新
  拉取该 namespace 的快照。快照 revision 比本地旧时拒绝覆盖，避免把飞行中的
  新变更回滚。克隆自己的写入回波按 revision 去重，不触发 settings 重建。
- 大量数据（IPTV）按 namespace 懒加载，不在启动时全量 seed。
- 主窗口退出：`DesktopShell.beforeQuit` 先按进程级窗口列表让所有引擎（包括克隆
  自己再开的克隆）关闭，再 `StorageStores.closeInstance()` 等待队列写并关闭
  SQLite，之后才销毁主窗口、移除托盘并退出；失败的克隆窗口调用被忽略，不让
  退出卡住。

## 7. 验收

- 打开两个克隆窗口：一个改主题/语言/播放/弹幕，另一个即时变化。
- 一个窗口关注/取关、记录历史、导入 IPTV；另一个窗口的列表同步。
- 两个窗口都能进主页、设置、房间、IPTV、VOD、多画面、录制中心。
- 子窗口进程内没有 SQLite 句柄；主窗口是唯一 writer。
- 同一房间重复打开只前置已有克隆窗口。
- `window.chrome` 为原生/自绘时，克隆窗口与主窗口的标题栏行为一致。
- 克隆窗口播放房间/VOD 时系统媒体条出现并可暂停/播放/停止；直播不出现 seek；
  关闭该窗口或停止播放后媒体条消失或回退到仍在播放的窗口。
- Windows/macOS/Linux 的 Runner 插件注册、关闭、全屏/PiP、播放器 view 正常。

## 8. 参考

- [desktop_multi_window — pub.dev](https://pub.dev/packages/desktop_multi_window)
- [Drift — SQLite for Dart/Flutter](https://drift.simonbinder.eu/)
- [SQLite WAL](https://www.sqlite.org/wal.html)
