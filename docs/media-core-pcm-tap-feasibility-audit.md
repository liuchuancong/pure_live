# media_core 音频 PCM 采集可行性审计

- 阶段 A 产出（《PureLive Media Core 音频频谱分析架构设计方案》§9 阶段 A）
- 审计日期：2026-10-30；只读审计，media_core 仓零代码改动
- 审计基线：media_core `7a01775`（global hotkey commit）；media_kit fork pin `803c4a27912091db6f839d48d1b984a0d9f588c7`（Predidit/media-kit）
- 结论一句话：**频带/电平数据走「lavfi 滤镜 → 帧 metadata → mpv `af-metadata` 属性观察」通道方案成立（生产已验证）；真 PCM 流无法从预编译 libmpv 内部出界，PCM Tap 的落点只能是 ①滤镜 metadata 的文件/管道出口，或 ②平台音频层捕获——阶段 B 按 B1→B2→B3→B4 顺序验证。**

## 1. 现有抽象与事件面

| 项 | 位置 | 审计结论 |
|---|---|---|
| 适配器契约 | `packages/media_core/lib/src/adapter/contract/player_adapter_base.dart` | `emitLoudnessChanged(momentary, shortTerm)` 是"滤镜在场即能力"的官方范式（`@protected`，`acceptsEngineEvents` 门控，进 `PlayerAdapterEvent` 流）。频谱/电平的 `emit*` 照此模式长出即可 |
| 适配器实现 | `media_core_media_kit/lib/src/adapter/media_kit_player_adapter.dart` | `MediaKitPlayerAdapter extends PlayerAdapterBase`。`_observeLoudness()` 在适配器初始化时启动；`_onLoudnessMetadata` 有 `isDisposed / _hasOpened / _playingNow` 三重门 + 200ms 节流（Stopwatch）——生命周期与播放状态对齐的现成样板 |
| 解析 | 同上 `_r128Value` | `af-metadata` 以字符串形态到达：`+lavfi.r128.M=-23.1+lavfi.r128.S=-23.4`（值可带负号，不能按 `+` 切分）。频带数组若走此通道=更长的正则/解析成本，见 §4 带宽核算 |
| 引擎选项接缝 | `media_kit_player_adapter_engine.dart` | `onApplyEngineOptions` → 列表项逐条 `change-list af add <entry>` + `af-count` 回读确认挂载。应用侧（`music_playback.dart`）把整条音效链合成**单条** `lavfi=[…]` 下发。分析滤镜必须**追加进同一条 lavfi 图**（`asplit` 取一路进分析支路），不能指望独立 `af` 条目与图共存无副作用——追加是安全的（`change-list` 支持） |
| 观察机制 | media_kit fork `NativePlayer.observeProperty`（`real.dart:1173`） | 直接 `mpv_observe_property(ctx, reply, name, MPV_FORMAT_NONE)` FFI，回调收格式化字符串；**同一属性重复 observe 抛 ArgumentError**（重复安装需先 unobserve 或只装一次）。任意 mpv 属性零新增原生代码可观察 |

## 2. libmpv 基座与原生构建面

- **预编译二进制**：fork 的 native assets hook（`media_kit/hook/build.dart`）按 `native_bundles.json` 下发 13 个 target（android arm/arm64/x64/ia32、windows x64/arm64、linux x64/arm64、ios arm64/x64、macos arm64/x64、ohos_arm64）。Windows x64 = `Predidit/libmpv-win32-video-cmake` 2026-09-15 git-`0b7ed67`——新 FFmpeg（lavfi 的 astats/ametadata/bandpass 全量可用）。
- **C 构建链已在用**：同一 hook 里 `CBuilder.library` 编译 `native_event_loop.c`/`native_library.c`——native assets 的 C 工具链在五平台是**已验证可工作**的。media_core 侧如需自己的 C（B4 平台捕获），建独立 hook，**不动 fork**。
- **libmpv 本体不可改**：预编译 .dll/.so/.dylib，无法注册自定义 `af` 滤镜进 mpv。重编 mpv = 五平台 SDK 矩阵 + 与上游 packager 永久分叉，**否决**。

## 3. PCM 出界候选路（逐一裁定）

| 路线 | 机制 | 裁定 |
|---|---|---|
| 甲：滤镜 metadata → `af-metadata` | lavfi 滤镜写帧 metadata，mpv 汇入 `af-metadata` 属性，Dart 观察字符串 | **已验证（ebur128 生产在跑）**。电平（astats）直接可用；频带数组受 metadata 键空间冲突限制（见 §5） |
| 乙：`ametadata=mode=print/delete:file=<path>` | 每条分析支路把 metadata 落到独立文件/命名管道，Dart 侧读 | **B3 主验证项**。FFmpeg `ametadata` 有 `file=`；`\\.\pipe\…` 与 POSIX FIFO 均可 fopen。五平台文件语义、吞吐、延迟待验证 |
| 丙：mpv 输出改道（`--ao=pcm`、encode 模式 `--o`、audio dump） | 让 mpv 把音频写出来 | **否决**——改道即断掉正常发声或整个进入转码模式，违反"复用 libmpv 音频链" |
| 丁：平台音频层捕获（WASAPI loopback / PulseAudio monitor / CoreAudio tap / ALSA loop / AAudio 复制） | 系统混音处拿 PCM，C 库经自有 hook 打包，FFI 环形缓冲回 Dart | **B4 兜底**。方案 §2"native bypass PCM Tap"的本义；拿到的是系统后混音（含非 app 声音），EQ 频响分层语义受损（只有"末级后"一层） |
| 戊：mpv_audio_kit 包 | 自带第二份 libmpv 0.41.0 | **否决**——同进程双 libmpv 符号冲突 + 第二引擎违反禁止清单；至多借鉴其 API 形状 |
| 己：fork mpv 编自定义 af | C 滤镜直接出 PCM | **否决**（§2 末条） |

## 4. 通道带宽核算（路线甲）

- mpv 每个音频帧（44.1kHz×1024 ≈ 23ms）更新一次 `af-metadata`；观察回调按帧触发，200ms 节流是适配器策略而非通道上限。
- 32 频带 × `lavfi.astats.N…` 文本 ≈ 每帧 1–2 KB 字符串：30 FPS 目标下 ≈ 30–60 KB/s 的 Dart 字符串解析——主 isolate 可承受；128 频带翻 4 倍仍可接受，但**解析应在 isolate 或切片增量做**（方案"FFT 后台线程"约束在此转化为"解析在后台"）。
- 频带数 ≤ 64 时此通道无阻塞风险；**不需要为频谱引入 C 层**，除非 B3/B4 验证推翻。

## 5. 频带数组的 metadata 键冲突（关键发现）

`astats` 的 metadata 键空间是 `lavfi.astats.<channel>.<stat>`——**并联 N 条 bandpass+astats 支路会互相覆盖同一键**（帧 metadata 是单键值字典，lavfi 不带滤镜实例前缀）。解法：

1. 每支路 `astats` 后接 `ametadata=mode=delete:file=<支路出口>`——打印即清除，N 个出口互不冲突（B3 验证 N=32 的文件/管道扇出吞吐）；
2. 或接受 `ebur128` 的思路：**一个自带多频带输出的滤镜**不存在（`ebur128` 只有 LUFS 三值；`aspectralstats` 是频谱特征值非频带数组；`firequalizer dumpfile` 是滤波器响应非信号）——不用等。

## 6. 复用清单（阶段 C/D 直接引用）

- 观察与解析：`_observeLoudness`/`_onLoudnessMetadata`/`_r128Value` 形态照搬（含 `is Dynamic` 调用 `observeProperty` 的兼容写法）。
- 生命周期门：`isDisposed / _hasOpened / _playingNow`；开图=分析滤镜追加进 `af`（`change-list`），关图=`change-list af remove`。
- 能力上报范式：`PlayerAdapterEvent` 新增 `spectrumChanged`/`levelsChanged`（0.0–1.0 归一后 emit），contract 层加 `emit*`。
- af 图合成：应用侧 `musicEqAfEntries` 已是单条 `lavfi=[…]` 的唯一合成点；分析支路以 `asplit` 挂在链尾。
- 包落位：通用层 `media_core/lib/src/audio_analysis/`；mpv 侧 `media_core_media_kit/lib/src/audio_analysis/`（方案 §8 原案成立，无需新建包）。

## 7. 阶段 B 验证清单（按序，各自有通过门槛）

| # | 验证 | 门槛 |
|---|---|---|
| B1 | `astats=metadata=1:reset=1` 挂进 af，`af-metadata` 读 `lavfi.astats.Overall.RMS_level`/`Peak_level`（含 per-channel） | Windows 真机连续播放读到合理 dB 值；暂停清空；不打扰现链 |
| B2 | 通道带宽实测：帧级 metadata 触发频率 + 字符串解析耗时（isolate 内） | ≥30 Hz 稳定、解析 <2 ms/帧 |
| B3 | `asplit` + N 条 `bandpass,astats,ametadata=mode=delete:file=<出口>`：命名管道/文件扇出 | N=32 时五延迟 <50 ms、无文件锁错误；Windows 先行 |
| B4 | （B3 失败才启）平台捕获 tap：WASAPI loopback 最小样例，经自有 native assets hook 编 C，环形缓冲 FFI 回传 | 已知频率注入（§11 强制门槛）频带正确 |

**B 阶段任何一项未过 → 不动 C（FFT）/D（接入）/E（UI）。**
