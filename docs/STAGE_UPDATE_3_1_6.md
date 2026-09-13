# Pure Live v3.1.6 虎牙醒目留言实时刷新修复

## 1. 发布范围

- 版本：`3.1.6+4119`。
- 目标：Android `arm64-v8a` APK、Windows x64 可选目录安装程序和便携 ZIP。
- 源码：两个平台从同一干净冻结提交串行构建，不复用或改名旧版本安装包。
- 上游：本轮按维护策略只读审查最新 Issue，不拉取、不合并上游代码；当前维护仓库仍是发布基线。

## 2. 问题归因

上游 Issue [#828](https://github.com/liuchuancong/pure_live/issues/828) 报告“醒目留言只有手动刷新才显示”。当前维护分支和上游的界面层都已经使用 `RxList` 与 `Obx`，手动刷新后能够立即展示也证明列表组件不是首次错误状态。真正的问题位于虎牙协议适配层：

1. 虎牙 WebSocket 的 URI `2001314` 是留言板变化通知，不直接携带完整醒目留言。
2. 旧实现收到通知后立刻、且只调用一次 WUP `getHeadLineMessageBoard`。
3. 推送与 WUP 快照是最终一致的：通知可能先到，第一次 WUP 仍返回旧列表或空列表；稍后手动刷新时服务端快照已经更新，所以用户看到“手动刷新才出现”。
4. 旧辅助函数对空结果调用 `messages.last`，可能抛出 `RangeError`。
5. WUP 请求在 WebSocket 解码函数内被 `await`，慢请求会串行阻塞后续普通弹幕，而不只是影响醒目留言。

该缺陷属于当前维护分支与上游共享的协议时序问题，不是 Android 页面刷新、Windows 列表布局或某一次上游合并造成的回归。

## 3. 修复设计

### 非阻塞有界补偿

- WebSocket 收到通知后只调度后台协调器，解码函数立即返回；普通弹幕不等待 WUP。
- 默认补偿时间点为 `0 / 600 / 1800 / 4000 ms`，每次 WUP 调用最多等待 3 秒。
- 只在当前房间会话仍有效时继续；切换房间、断开或停止后，旧代际任务立即失效。
- 补偿窗口有明确上限，不引入长期轮询、常驻定时器或持续网络/CPU 占用。

### 快照合并与容错

- 使用醒目留言值对象集合记录已经发送的条目；完整 WUP 快照中只有新条目进入上层 `RxList`。
- 补偿执行期间再次收到通知时合并为最多一轮后续协调，避免同一事件启动多个并行请求序列。
- 空留言板直接返回空列表；网络失败或超时结束当前尝试并进入下一有界时间点，不抛出到 WebSocket 主循环。
- 保留现有控制器中的过期清理规则，修复只改变消息何时可靠到达，不改变价格、持续时间或 UI 样式语义。

## 4. 自动化证据

- `test/huya_danmaku_protocol_test.dart` 新增“首轮快照为空、后续快照出现”场景：验证 WebSocket 解码先返回，醒目留言随后自动发送。
- 同一测试模拟重复通知与重复快照：验证醒目留言只发出一次。
- `test/super_chat_expiry_policy_test.dart` 保留时间与淘汰边界。
- 聚焦质量命令：

  ```powershell
  .\tool\local_ci.ps1 -Scope Focused `
    -TestPath @('test/huya_danmaku_protocol_test.dart','test/super_chat_expiry_policy_test.dart')
  ```

- 结果：延迟快照、重复快照、跨房间代际隔离与到期策略共 9/9 通过；仓库策略、设备 UI 映射、Built-in Kotlin 审计通过；全仓审计 3896 个已跟踪文件、0 error、1 条既有警告。
- 聚焦记录：`local-artifacts/build-records/20260831T195751960Z-quality-focused.json`。
- 最终完整门禁：Analyze 0 issue、Flutter 678/678、公开平台接口 42/42、仓库审计 3896 个已跟踪文件且 0 error；耗时 1007.180 秒，峰值 CPU 34.68%，峰值工作集 19,126,968,320 bytes，结束后活跃重型进程 0。
- 完整记录：`local-artifacts/build-records/20260831T201458105Z-quality-full.json`。
- 冻结源码与 `v3.1.6` 标签均指向 `398d182dcb02a3587a6ae74e35f258f7d3eebbc9`。

## 5. 构建与 GitHub 资产

Android、Windows 按构建策略串行执行，均复用同一源码完整门禁：

| 平台 | 命令 | 耗时 | 峰值 CPU | 峰值工作集 | 收尾 |
| --- | --- | ---: | ---: | ---: | --- |
| Android arm64-v8a | `build_local_release.ps1 -Target AndroidArm64 -Configuration Release -SkipQuality` | 932.682 s | 58.36% | 20,766,429,184 bytes | 活跃重型进程 0 |
| Windows x64 | `build_local_release.ps1 -Target WindowsX64 -Configuration Release -SkipQuality` | 1071.061 s | 50.78% | 20,692,557,824 bytes | 活跃重型进程 0 |

GitHub Release：[v3.1.6](https://github.com/liuchuancong/pure_live/releases/tag/v3.1.6)。Release 共 7 个资产：三个客户端产物、Android/Windows 两份构建元数据和两份 SHA-256 清单。

| 资产 | 大小 | SHA-256 | 签名状态 |
| --- | ---: | --- | --- |
| `PureLive-3.1.6-4119-debug-signed-android-arm64-v8a-release.apk` | 118,450,755 bytes | `0736e9cb2844a2bbfbccf22eaba5e0da8f0ed11410437b35c4faad6abe171a17` | Release 编译模式，本地调试证书 |
| `PureLive-3.1.6-4119-windows-x64-portable.zip` | 72,313,273 bytes | `0e7423e84e9ec694aabffadf4de0f1eff1392ef3d72c946117fd4fbd99da758e` | 便携 ZIP，不适用 Authenticode |
| `PureLive-3.1.6-4119-windows-x64-setup.exe` | 56,046,319 bytes | `1a2fa055ec2497469493a98e224cca9fbba8bccd9c0e2d62bb1024460ae9068a` | 未配置 Authenticode |

- Android 内容门禁：包名 `com.mystyle.purelive`、版本名 `3.1.6`、基础 build `4119`、arm64 ABI 偏移 `2000`、Manifest `versionCode=6119`、唯一 ABI `arm64-v8a`、Flutter 资源 1258 项。
- Android 构建记录：`local-artifacts/build-records/20260831T203326711Z-build-androidarm64-release.json`。
- Windows 构建记录：`local-artifacts/build-records/20260831T205143452Z-build-windowsx64-release.json`。

## 6. 平台影响

| 平台 | 代码影响 | 交付 |
| --- | --- | --- |
| Android arm64-v8a | 虎牙弹幕协议层共享修复；UI、播放器、竖屏比例与录制链没有改动 | Release APK |
| Windows x64 | 使用同一 Dart 虎牙协议层，因此同步获得非阻塞补偿与空板容错 | 可选目录安装程序、便携 ZIP |
| 其他平台 | 源码层同样受益，但本轮没有对应设备交付要求 | 不生成安装包 |

## 7. 运行验证边界

- 确定性测试覆盖“通知先于快照”“空快照”“重复快照”“解码不阻塞”“到期清理”。
- Android v3.1.6 已在 PJZ110 / Android 16 通过网络 ADB 从 v3.1.5 静默覆盖安装；核对 `versionName=3.1.6`、`versionCode=6119`，安装前后用户原前台小红书 Activity 完全一致，没有启动 Pure Live 或抢占界面。
- 真实付费醒目留言依赖主播房间在观察窗口内出现对应事件。没有截获真实事件时标记为运行观察项，不用模拟结果冒充实播证据。
- 本轮没有修改画质、线路、播放器恢复、录制或竖屏几何，因此完整门禁用于确认共享代码没有回归，但不会把未执行的平台实播矩阵写成已经通过。

## 8. 回滚边界

回滚只需恢复虎牙 URI `2001314` 的协调逻辑、空列表处理、对应协议测试以及版本/发布文档。由于新实现不改变消息模型、控制器列表和 UI，回滚不涉及用户配置迁移或数据库结构。
