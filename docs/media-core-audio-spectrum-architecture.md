# PureLive Media Core 音频频谱分析架构设计方案

- 定稿：2026-10-30（用户拍板）
- 范围：media_core 音频分析子系统 + PureLive 音效中心接入
- 状态：方案定稿；阶段 A（审计）与阶段 B（PCM Tap 验证）均未实施

## 1. 目标

为音效中心提供四类分析数据：频谱、波形、电平、EQ 频响曲线。

## 2. 总体架构原则

- 采集 / DSP / UI 三层严格分离。
- PCM 采集走 native bypass PCM Tap：在原生音频线程拷贝到环形缓冲，不干扰播放链。
- 首选路线：复用 libmpv 音频链 + 独立 PCM Tap。

三条硬约束：

1. FFT 引擎是通用实现，不绑定 media_kit。
2. 完整 PCM Stream 默认关闭——普通播放只开频谱 + 电平；PCM 仅在波形/分析订阅时开放。
3. 先验证 PCM Tap（最大技术风险，五平台原生实现），再做其余。

## 3. DSP/FFT 管线

- Hann 窗；默认 FFT 尺寸 2048。
- 频带对数分布，32/64/128 可选，覆盖 20Hz–20kHz。
- EMA 平滑：attack 0.5 / release 0.1。
- 目标帧率 30 FPS；FFT 在后台线程执行；流向订阅者丢弃过期帧。

## 4. 数据模型

| 模型 | 内容 | 开放策略 |
|---|---|---|
| `AudioSpectrumFrame` | 归一化 0.0–1.0 float 频带数组 | 频谱订阅 |
| `AudioLevelFrame` | 每通道 peak / rms | 电平订阅 |
| `AudioPcmFrame` | 原始 PCM 块 | 可选订阅，默认关闭 |

## 5. API 面

- `AudioAnalyzer`：spectrum / levels / pcm 三条流。
- `AudioAnalysisConfig`：频带数、FFT 尺寸、平滑参数等。
- `AudioAnalysisController`：订阅与生命周期管理。
- 分析器生命周期与播放器生命周期同步（打开/暂停/停止/切歌对齐启停）。

## 6. EQ 频响曲线（服务音效中心）

三层关系：原始信号 / 后 DSP 信号 / EQ 频响曲线。频响曲线必须从实际滤波器参数计算得出，禁止用滑块连线折线冒充。

## 7. mpv_audio_kit 评估项

引入或借鉴前必须验证：是否输出真实 PCM、DSP 位置、libmpv 基座、与 media_kit 的兼容性、五平台可用性。

## 8. 包结构

- `media_core/lib/src/audio_analysis/`（通用层）+ `audio_dsp/frequency_response.dart`。
- `media_core_media_kit/lib/src/audio_analysis/`：`media_kit_audio_analyzer.dart`、`media_kit_audio_tap.dart`、`pcm_ring_buffer.dart`、`fft_processor.dart`。

## 9. 实施阶段

| 阶段 | 内容 | 门槛 |
|---|---|---|
| A | 架构审计：审计 media_core 现有抽象、media_kit 适配器、libmpv 集成、DSP 链、五平台原生构建、可复用 PCM 采集接口，产出《media_core 音频 PCM 采集可行性审计》 | 只读，不改代码 |
| B | PCM Tap 五平台技术验证 | 最大技术风险项，先行 |
| C | 通用 FFT 引擎 | 依赖 B |
| D | 播放器接入（media_core_media_kit） | 依赖 B/C |
| E | PureLive UI 接入（音效中心） | 依赖 D |

实施顺序：先审计、再验证 PCM、最后实现 FFT 和 UI 接入。**不得在没有验证 PCM 获取能力之前直接开发完整 FFT 接入。**

## 10. 禁止事项

- 替换 media_kit。
- 播放期间挂第二个 FFmpeg 解码器。
- 在 Flutter UI 层做 FFT。
- 用 mpv 频谱 video filter 当数据接口。
- 频谱计算耦合进 LivePlaybackController。
- 提供每播放器的频谱 UI API。

## 11. 测试要求

以已知频率信号注入为强制门槛验证频带正确性，禁止以 UI 目测判定。

## 12. 现状锚点（2026-10-30 实查）

- media_core 当前无任何 spectrum/FFT/PCM 面；已有的最接近能力是 EBU R128 响度探针路径（`PlayerAdapterBase.emitLoudnessChanged` momentary/shortTerm LUFS，"滤镜在场即能力"，af 链携带探针滤镜时才上报）——可作为电平显示的参考路径，但单频带响度 ≠ 频谱。
- 应用侧 af 链以单条 `lavfi=[…]` 条目经 `handle.applyEngineOptions([EngineOption('af', …)])` 下发（见 apps/pure_live `modules/music/controller/music_playback.dart`），PCM Tap 如走滤镜路线需沿用同一接缝。
- lx-music-desktop 参考实现用 Web Audio `AnalyserNode.getByteFrequencyData`（canvas 128 柱、rAF 随播放循环、均值放大 ×1.4），浏览器能力无法在 mpv 上复刻，仅作 UI 行为参照。

## 13. B1/B2 实机判定（2026-10-30，Windows 实跑）

自动探针 `media_core example/lib/main_probe.dart`（纯 Dart 合成 440 Hz/0.5 振幅正弦 WAV，裸 media_kit 播放器挂 astats tap，stdout 直出），本机（Windows 11 22621，wasapi 输出）实测：

**前置发现（比判定本身更重要）**：media-kit 官方 Windows 预编译 libmpv-2.dll（`libmpv-win32-video-build` 2023-09-24，38MB）**没有编入任何 avfilter 音频滤镜**——`lavfi=[volume=0.5]`、`lavfi=[astats]` 一律 "parsing the filter graph failed"。DLL 内字节扫描 `astats`/`ebur128` 零命中。**这意味着 pure_live 音效中心的整条 lavfi 链（EQ/九效果）在 Windows 上从未真正生效过**（applyFailed 横幅会亮，UI 开关照走）。响度探针同理不可用。

换 zhongfly/mpv-winbuild 全功能 libmpv-2.dll（2026-10-30 构建，122MB，仅替换 build 产物验证）后：

- **B1 通过**：`@tap:lavfi=[astats=metadata=1:reset=1]` 挂载成功、无报错、播放推进正常；`af-metadata/tap` 属性每帧携带完整 astats 读数（正弦 ±16384 与 0.5 振幅精确吻合，Peak_level −6.02 dBFS 理论值命中）。
- **B2 parse 通过**：稳态 33–78 µs（首帧 1.06 ms），远低于 2 ms 预算。
- **B2 rate 不达标**：回调率稳定 **~15 Hz**，低于 30 Hz 预算。廉价回调（仅计数）同样 ~14.4 Hz——瓶颈在 mpv 属性变更通知本身（astats 逐帧写 metadata ≈46.9 Hz，但 mpv 合并通知），非解析侧开销，优化回调无法改善。

**关键 API 勘误**：mpv 的滤镜元数据属性是 `af-metadata/<label>`，裸 `af-metadata` 恒为空——挂载必须带标签（`@tap:lavfi=[…]`）。探针已改（media_core 53e5ca3）。

**结论与去向**：
1. lavfi+af-metadata 路线**可用但只有 ~15 Hz**——32 频带 VU 式频谱在 15 fps 逐带更新仍可看；要更高帧率或真 FFT 必须走方案 B（WASAPI/平台采集）。
2. **无论频谱走哪条路，Windows 换全功能 libmpv 是音效中心生效的先决条件**——不换，EQ/效果链全部空转。候选：zhongfly/mpv-winbuild mpv-dev（libmpv-2 ABI 兼容，替换即用，122MB 体积代价 + 发布渠道/校验流程待定）。
3. B3（asplit+bandpass×N 频带扇出）在该路线下受同一 15 Hz 上限约束，先于 B4 决策 DLL 问题。
