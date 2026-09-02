# Pure Live v3.1.7 虎牙醒目留言事件身份修复

## 1. 发布范围

- 版本：`3.1.7+4120`。
- 目标：Android `arm64-v8a` APK、Windows x64 可选目录安装程序和便携 ZIP。
- 源码：两个平台从同一干净冻结提交串行构建，不复用或改名旧版本安装包。
- 上游：本轮不拉取、不合并上游代码；当前维护仓库是唯一修改基线。

## 2. 继续审计发现的根因

v3.1.6 已经把虎牙 URI `2001314` 的留言板补偿改成非阻塞、有界重试，解决通知早于 WUP 快照时必须手动刷新的问题。继续检查会话级去重后发现另一个可确定复现的边界：

1. `GameEventMessageBoardInfo` 实际提供稳定的 `lMessageId`，旧解析器没有把它传入通用醒目留言模型。
2. 旧 `LiveSuperChatMessage` 只用 `userName + message + price` 判等。
3. 虎牙弹幕传输层的 `_emittedSuperChats` 会保留到退出房间；同一用户稍后再次购买相同金额、发送相同文字时，新事件会与旧事件判等并被整场抑制。
4. 使用 `startTime` 直接补充判等也不可靠：虎牙接口只返回总时长和剩余倒计时，客户端每轮以当前时间重建开始/结束时间，网络延迟会让同一快照产生毫秒漂移。
5. 已发送集合此前只在离开房间时清空，极长会话理论上会持续增长。

这不是列表刷新、主题、横竖屏或播放器问题，而是平台稳定事件身份在解析层被丢弃后引发的会话去重错误。

## 3. 修复设计

### 稳定事件身份

- 通用醒目留言模型增加可选 `messageId`；只有协议明确提供稳定 ID 时才使用。
- 虎牙把正数 `lMessageId` 映射为 `huya:<id>`，避免与其他平台命名空间碰撞。
- 两个对象都有事件 ID 时只按 ID 判等；没有事件 ID 的其他平台继续使用原有用户名、文字和金额兼容键。
- UI 列表优先用 `messageId` 建立唯一键，避免倒计时重建时间变化造成同一事件重复渲染。

### 有界会话缓存

- 虎牙传输层仍以插入有序集合合并完整 WUP 快照。
- 记忆上限为 512 项；超过上限时删除最早记录。虎牙留言板单次只返回少量近期数据，512 项远高于活动快照，既保留重试去重又避免长时会话无界增长。
- `start()`、`stop()` 和会话代际切换继续清空状态；旧房间请求不能污染新房间。

## 4. 自动化证据

- `test/huya_danmaku_protocol_test.dart` 增加稳定事件身份回归：同一 `messageId` 的两次快照即使重建时间相差 850 ms，仍判为同一事件。
- 同一测试增加合法重复内容回归：用户名、文字、金额完全相同但 `messageId` 不同的两个事件均发送到上层。
- 聚焦虎牙协议与到期策略测试 11/11 通过：`local-artifacts/build-records/20260831T214641341Z-quality-focused.json`。
- 最终完整门禁：Analyze 0 issue、Flutter 680/680、公开平台接口 42/42、仓库审计 3898 个已跟踪文件且 0 error；耗时 1140.940 秒，峰值 CPU 72.25%，峰值工作集 19,288,657,920 bytes，结束后活跃重型进程 0。
- 完整记录：`local-artifacts/build-records/20260831T220642436Z-quality-full.json`。

## 5. 平台影响

| 平台 | 代码影响 | 交付 |
|---|---|---|
| Android arm64-v8a | 虎牙弹幕共享模型、协议解析、去重与列表键 | Release APK |
| Windows x64 | 使用同一 Dart 协议层和模型，同步获得修复 | 可选目录安装程序、便携 ZIP |
| 其他平台 | 通用模型字段为可选值，既有构造调用和兼容判等保持不变 | 本轮不构建 |

## 6. 运行验证边界

- 确定性测试覆盖事件 ID 判等、倒计时重建抖动、合法重复内容、重复快照、跨房间代际和到期清理。
- 真实付费醒目留言依赖外部主播房间在观察窗口内发生对应事件；没有截获真实事件时继续标为运行观察项，不用模拟测试冒充实播结果。
- 本轮没有修改播放器、画质、线路、竖屏几何或录制状态机；完整门禁用于排除共享模型改动造成的代码回归，不把未执行的实机矩阵写成通过。

## 7. 构建与校验

冻结源码与 `v3.1.7` 标签均指向 `13d4d4094a200ff43b2ec98e986818e7a58a1fc3`。Android、Windows 按 `BUILD_POLICY.md` 串行构建；Android 收尾时仍有两个 Java 后台进程处于回落窗口，Windows 构建守卫先排队至其退出再启动，最终活跃重型进程为 0，没有并发执行两个平台构建。

| 平台 | 命令 | 耗时 | 峰值 CPU | 峰值工作集 | 最终收尾 |
|---|---|---:|---:|---:|---|
| Android arm64-v8a | `build_local_release.ps1 -Target AndroidArm64 -Configuration Release -SkipQuality` | 795.991 s | 67.01% | 19,677,376,512 bytes | Windows 阶段启动前守卫确认回落 |
| Windows x64 | `build_local_release.ps1 -Target WindowsX64 -Configuration Release -SkipQuality` | 1158.972 s | 63.76% | 16,422,981,632 bytes | 活跃重型进程 0 |

GitHub Release：[v3.1.7](https://github.com/wzgrx/pure_live/releases/tag/v3.1.7)。Release 为非草稿、非预发布，共 7 个资产；GitHub 返回的服务端 SHA-256 与本地清单逐项一致。

| 资产 | 大小 | SHA-256 | 签名状态 |
|---|---:|---|---|
| `PureLive-3.1.7-4120-debug-signed-android-arm64-v8a-release.apk` | 118,451,707 bytes | `7233a01ad90e207df483fb63b125ac7d9ab33f9811b6b797f78e3b5397969a7a` | Release 编译模式，本地调试证书 |
| `PureLive-3.1.7-4120-windows-x64-portable.zip` | 73,781,511 bytes | `ac174263d67c3d131656c69043d21562b5c4fd85512c5fca970e23ef2c603013` | 便携 ZIP，不适用 Authenticode |
| `PureLive-3.1.7-4120-windows-x64-setup.exe` | 56,046,835 bytes | `99b3f1983aac9025d4f6da41a4dde52bdb135c1afa55921e25dcbb08b76f81f3` | 未配置 Authenticode |

- Android 包核验：包名 `com.mystyle.purelive`、版本 `3.1.7`、Manifest `versionCode=6120`、唯一 ABI `arm64-v8a`、Flutter 资源 1258 项。
- PJZ110 / Android 16 已从 v3.1.6 静默覆盖安装到 v3.1.7；安装前后用户前台都保持 `com.xingin.xhs/.index.v2.IndexActivityV2`，没有启动 Pure Live，安装后核对 `versionName=3.1.7`、`versionCode=6120`。
- Windows 便携 ZIP 共 1301 项；`pure_live.exe`、WebView2 loader、Flutter manifest 和内置 `3.1.7+4120` 更新源各 1，退役 QuickJS DLL 与运行期用户数据均为 0。
- GitHub 发布后的同一 Windows 便携产物已在全新独立 instance 隐藏启动并连续空闲采样 180.930 秒：37/37 样本均响应，Working Set 196.0078→196.0234 MiB、Private Bytes 530.9766→528.8086 MiB，退出后残留进程为 0；详见 `docs/WINDOWS_RUNTIME_AUDIT_3_1_7.md`。
- Android 构建记录：`local-artifacts/build-records/20260831T224917895Z-build-androidarm64-release.json`。
- Windows 构建记录：`local-artifacts/build-records/20260831T231008974Z-build-windowsx64-release.json`。

## 8. 回滚边界

回滚只涉及可选事件 ID、虎牙 `lMessageId` 映射、512 项已发送缓存、列表唯一键和对应测试；没有用户设置、数据库或备份格式迁移。
