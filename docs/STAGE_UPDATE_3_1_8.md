# Pure Live v3.1.8 录制会话时间修复

## 1. 发布范围

- 版本：`3.1.8+4121`。
- 目标：Android `arm64-v8a` APK、Windows x64 可选目录安装程序和便携 ZIP。
- 源码：两个平台从同一干净冻结提交串行构建，不复用、复制或改名旧版本安装包。
- 上游：本轮不拉取、不合并上游代码；当前维护仓库与 v3.1.7 运行证据是唯一修改基线。

## 2. 实测问题与根因

v3.1.7 Windows 便携版实际进入虎牙房间后，画质从 `蓝光20M` 切到 `蓝光8M`、线路从 `线路1` 切到 `线路2` 均取得真实结果，视频与弹幕继续。随后录制跨过一次虎牙短签名续接，录制中心的时长、大小、速度和码率持续累计，两个输出 MP4 也都能由 `ffprobe` 读取；但用户可见开始时间从首段 `08:42` 跳成第二段 `08:44`。

首次错误状态不在虎牙服务器、FFmpeg 进度或录制列表刷新，而在 `LiveRecordTask` 的状态建模：

1. `createTime` 同时表示用户点击开始录制的会话时间，以及当前原生 FFmpeg 尝试的文件名前缀时间。
2. CDN 短签名过期、输入中断或自动换线时，录制器必须调用 `beginNewAttempt()` 产生新的毫秒级前缀，避免覆盖上一段文件。
3. `beginNewAttempt()` 正确更新了 `createTime`，但录制中心也直接显示该字段，于是一次后台续接被错误呈现为一次新的用户录制。
4. 只禁止更新 `createTime` 会让重试文件名冲突；只在 UI 内缓存时间则无法跨应用重启恢复。根因需要在持久化模型层拆分语义。

该问题位于 Android 与 Windows 共享的 Dart 录制任务模型；Windows 实播先触发并证明，两个主要维护平台都交付同一修复。

## 3. 修复设计

### 会话与尝试分离

- 新增可持久化的 `recordingStartedAt`，只表示用户可见录制会话起点。
- `beginNewRecording()` 在用户明确开始或重新开始时设置 `recordingStartedAt`，同时清零本次会话累计大小和时长。
- `beginNewAttempt()` 继续更新 `createTime`，保证每次原生尝试生成独立的毫秒级文件前缀；它不再影响会话时间，也不清零跨分片累计值。
- 录制中心统一显示 `displayStartTime`：优先使用 `recordingStartedAt`，旧数据没有该字段时回退到 `createTime`。

### 持久化兼容

- 任务 schema 从 5 升到 6并写入 ISO-8601 会话时间。
- v3.1.7 及更早保存的任务仍可读取；由于历史数据没有独立会话时间，只能使用当时已有的 `createTime` 作为兼容显示值，不伪造未知时间。
- 新版保存后，应用重启、录制中心恢复、短签名轮换与自动重连都保持原会话时间。
- 用户显式停止后再次启动同一任务会写入新的会话起点，不错误沿用上一轮。

## 4. 自动化与实播证据

聚焦测试 `test/live_record_task_persistence_test.dart` 覆盖：

1. 自动续接前后 `recordingStartedAt` 不变；
2. `createTime` 与文件前缀随尝试轮换；
3. 已累计时长和文件大小不因原生重试清零；
4. 会话时间经 JSON 保存/恢复不变；
5. 用户显式重新录制时会话时间正确重置；
6. 签名 URL 继续不写入持久化数据。

聚焦回归 13/13 通过；记录：`local-artifacts/build-records/20260901T011808521Z-quality-focused.json`。

完整门禁的 Analyze 0 issue 与 Flutter 682/682 均通过；仓库审计 3901 个已跟踪文件、0 error、1 条既有警告。第一次命令最后在公开接口阶段退出非零，因为探针自身把应用使用的 Twitch `ZH/KO` 请求扩展为 `EN/ZH/KO`；Twitch 当前对三语言组合返回 `game.streams = null` 的部分 GraphQL 错误，而应用原请求和单语言请求均正常。探针恢复为与产品完全相同的 `ZH/KO` 合同后，公开接口复跑 42/42 通过。完整命令记录：`local-artifacts/build-records/20260901T020356896Z-quality-full.json`；该记录保留首次探针误报的非零状态，不改写历史结果，最终门禁由同次 Analyze/Flutter/仓库审计和修正后的 42/42 接口复跑共同组成。

v3.1.7 Windows 虎牙实播前置证据：

- 录制中心停止时显示 `00:03:18 / 82.75 MB / 1.1x / 2.1 Mbps`，FFmpeg 进程随后归零。
- 两个分段文件合计 83,138,772 bytes、媒体时长 195.550334 秒；均为 H.264 1920×1080 60 fps + AAC 44.1 kHz 双声道，没有空文件或不可解码文件。
- 详细链路与资源数据见 `docs/WINDOWS_RUNTIME_AUDIT_3_1_7.md`。

## 5. 平台影响与边界

| 平台 | 代码影响 | 本轮交付 |
| --- | --- | --- |
| Android arm64-v8a | 共享任务模型、录制中心显示和持久化 schema | Release APK |
| Windows x64 | 同一共享模型与 UI；已有真实虎牙续接证据 | 可选目录安装程序、便携 ZIP |
| 其他平台 | 源码层可获得相同状态修复 | 本轮不生成安装包 |

本轮没有修改平台画质/线路请求、播放器生命周期、横竖屏几何、弹幕协议、录制输出目录或 Windows 安装数据策略。画质与线路选择、视频连续性、分片媒体有效性已经由 v3.1.7 实播覆盖；新包仍需复验“首段 → 自动续接 → 停止 → 重启恢复”时界面时间保持不变。

## 6. 构建、签名与发布

冻结源码和 `v3.1.8` 标签均指向 `e94f94d73953e9ee295738a121df522e4710bf58`。Android 与 Windows 按 `BUILD_POLICY.md` 串行执行；两个阶段结束时活跃重型进程均为 0。

| 平台 | 命令 | 耗时 | 峰值 CPU | 峰值工作集 | 结果 |
| --- | --- | ---: | ---: | ---: | --- |
| Android arm64-v8a | `build_local_release.ps1 -Target AndroidArm64 -Configuration Release -SkipQuality -DedicatedBuild` | 1499.656 s | 66.18% | 15,051,489,280 bytes | APK 内容、版本、ABI、资源和原生库门禁通过 |
| Windows x64 | `build_local_release.ps1 -Target WindowsX64 -Configuration Release -SkipQuality -DedicatedBuild` | 409.978 s | 19.16% | 16,807,096,320 bytes | 安装程序与便携包按安装清单打包成功 |

GitHub Release：[v3.1.8](https://github.com/wzgrx/pure_live/releases/tag/v3.1.8)。Release 为非草稿、非预发布，共 7 个资产；GitHub 服务端摘要与本地清单一致。

| 资产 | 大小 | SHA-256 | 签名/用途 |
| --- | ---: | --- | --- |
| `PureLive-3.1.8-4121-debug-signed-android-arm64-v8a-release.apk` | 118,453,007 bytes | `f6f48e23a90cf46943157fc6ae2d3b07b7009780d75f32d743012b80c0fd3d60` | Release 编译模式，本地调试证书 |
| `PureLive-3.1.8-4121-windows-x64-portable.zip` | 72,315,778 bytes | `1bc337f8eec98c29e70a25446947d4b4b5ad5ea334bee6173b558d01b6a54cb1` | 免安装便携包 |
| `PureLive-3.1.8-4121-windows-x64-setup.exe` | 56,047,876 bytes | `6a6086eed886f9a840f1e26ab292cdf7d0bd98305672484983411f9c73bc6a0a` | 可选择安装目录，未配置 Authenticode |

- Android 包名 `com.mystyle.purelive`、版本名 `3.1.8`、基础 build `4121`、arm64 Manifest `versionCode=6121`、唯一 ABI `arm64-v8a`、Flutter 资源 1258 项。
- Android 和 Windows 构建元数据、平台独立 SHA-256 清单与安装包一并发布；没有使用旧包改名。
- K90 Pro（`25102RKBEC` / `myron`，Android 17，`1200×2608`，arm64-v8a，最高 120 Hz）已完成网络 ADB 配对并覆盖安装本次 Android APK；核对 `versionName=3.1.8`、arm64 分包 `versionCode=6121`，原关注数据仍在且首次启动成功，未见 AndroidRuntime/FATAL。首个 12 秒样本为 TOTAL PSS 179,370 KB、TOTAL RSS 377,012 KB；该短样本只作为启动基线，不代替长时间直播、录制、横竖屏、PiP、音频与热稳定性矩阵。
- 新设备 UI 基线已切换到 K90 Pro；旧 PJZ110 坐标继续保留作历史回归。K90 初始坐标由旧设备按物理分辨率缩放，只在语义核对后用于状态变更，并在实际进入对应页面后逐页重新快照，避免把比例换算当作实测。

## 7. 回滚边界

回滚只涉及 `recordingStartedAt`、`displayStartTime`、schema 6 字段和对应测试/UI引用。`createTime` 仍保留原来的文件尝试前缀职责，所以回滚不需要迁移录制文件、修改输出目录或丢弃既有失败分片。
