# 背景智能取色与自适应主题（实施基线）

本文件是背景模块的正式实施基线：先记录现状审计，再固定设计决策，最后给出阶段 B～E 的边界。
与既有设置、主题、壁纸来源冲突时，以「不退化现有视觉效果」为第一优先级。

## 1. 阶段 A 审计摘要

现状数据流：

```
backgroundSettingsProvider（媒体身份）
  → backgroundSampleProvider : Color?
       image    PaletteGenerator.fromImageProvider(48×48) → dominantColor
       gradient 各 stop 的 RGB 算术平均
       video    无头播放器静帧 → dominantColor / 首帧截图 → dominantColor
  → backgroundToneProvider（单色 + 用户蒙层 → 二选一）
  → pure_live_app.themeMode 强制覆盖用户明暗
```

| # | 缺陷 | 证据 |
| --- | --- | --- |
| 1 | 只取主色，没有亮度分布 | `tone/background_tone.dart` 的 `_dominant` |
| 2 | 没有目标对比度，也不反推蒙层 | `backgroundToneProvider` 只比较两个 ink |
| 3 | 只要背景有颜色就强制覆盖用户主题 | `bootstrap/pure_live_app.dart` 的 `themeMode` |
| 4 | 渐变取色忽略 stops/角度/alpha，且 RGB 均值不是亮度 | `_averageOf` |
| 5 | 没有区域分析，局部墨色与全局主题混在一起 | 无 `backgroundRegionProvider` |
| 6 | 没有分析缓存（无算法版本、无 mtime），视频每帧重解码 | `backgroundSampleProvider`、`BackgroundClipStills` |
| 7 | 视频只取一次色，无节流、无场景变化 | `background_video_source.dart` 的 `_publishTone` |
| 8 | 预览与正式背景各写一份蒙层 | `_StageScrim` vs `appBackgroundOverlay` |
| 9 | 模糊有三个执行点，语义分裂 | 图片 overlay / 视频解码器 / 视频 overlay=0 |
| 10 | 无算法测试 | `test/app` 下无 background 目录 |

可复用资产：无头截帧与静帧文件缓存、视频帧发布通道、媒体身份 `select` 写法、
`palette_generator_plus.contrastRatio`、`PaletteGenerator.fromImage/fromByteData`、`rawStraightRgba`。

## 2. 设计决策与实施约束（已确认，不再待定）

### 2.1 六项决策

| 项目 | 决策 | 说明 |
| --- | --- | --- |
| followTone | 默认开启 | 关：完全遵循用户主题；开：按背景分析结果推荐明暗；分析失败回退用户当前主题；换背景重新分析，但不得频繁闪烁。**手动选择主题视为停止跟随**（主题页、标题栏开关、对话框任一入口），否则主题设置被背景覆盖、用户无法改主题 |
| 蒙层模式 | 默认自动，自定义值 0.45 为下限 | 三档：关闭 0 / 自动按对比度计算 / 自定义用户值；自动值不覆盖用户自定义值，切模式保留上次自定义值。自动 = `max(按对比度求出的最小浓度, 用户自定义值)`：原本在 0.45 下可读的壁纸观感不变，只有读不清的才加深，上限 0.8 |
| 局部 ink | 仅壳层 + 玻璃 | 首批只接标题栏、底栏、玻璃最低可读性保护 |
| 预览 scrim | 统一共享实现 | 删除 `_StageScrim`，预览与正式使用同一遮罩颜色、透明度、渐变方向与合成算法 |
| 分析缓存 | 仅内存 LRU | 键含媒体标识 + 算法版本；重启后重算；不写 Hive CE，不增加持久化负担 |
| 算法测试 | 常驻 | `apps/pure_live/test/app/background/tone/` 是长期回归测试，不是临时测试或示例 |

### 2.2 首批局部 ink 的使用范围

只接入：

- 应用壳层标题栏；
- 应用底栏；
- 玻璃容器的最低可读性保护。

暂不接入：直播间、房间卡片、视频卡片、普通内容列表及其他业务页面。局部颜色分析不得侵入业务模块。

### 2.3 实施边界

- 不推翻现有 Background Provider，不修改主题系统基本架构。
- 不扩大首批局部 ink 消费范围。
- 不改变默认蒙层视觉效果（自定义 0.45 时观感与今天一致）。
- 不增加持久化缓存。
- 不删除正式算法测试。
- 不新增依赖，不建 isolate；单次分析只解码一次 64px。
- 先保证现有视觉效果不退化，再提高分析准确度，最后逐步开放局部自适应。

### 2.4 临时测试与正式测试

临时烟测在验证后删除；本模块的算法测试必须保留。目录：

```
apps/pure_live/test/app/background/tone/
├── image_brightness_analyzer_test.dart
├── image_region_analyzer_test.dart
├── gradient_analyzer_test.dart
├── contrast_analyzer_test.dart
├── background_tone_test.dart
└── background_analysis_cache_test.dart
```

## 3. Provider 与模块结构

```
backgroundSettingsProvider.select(媒体身份)
  → backgroundAnalysisProvider : BackgroundAnalysisResult?   （唯一解码入口 + 内存 LRU）
       ├→ backgroundToneProvider       : BackgroundTone?      （全局明暗 + 有效蒙层）
       ├→ backgroundRegionProvider     : List<ImageRegionResult>?
       └→ backgroundForegroundProvider : BackgroundForeground?
```

新增目录 `apps/pure_live/lib/app/background/tone/analysis/`：

| 文件 | 职责 |
| --- | --- |
| `background_models.dart` | `BackgroundAnalysisResult`、`ImageRegionResult`、亮度分布、蒙层计划、主题决策 |
| `background_luminance.dart` | sRGB 相对亮度、WCAG 对比度、墨色推荐、均匀色、直方图与分位 |
| `background_pixels.dart` | 一次 RGBA 采样：亮度分布 + 3×3 分区 + 代表色 |
| `background_regions.dart` | 3×3 分区几何与逐区统计 |
| `background_gradient.dart` | 按 stops/角度/alpha 在 24 个位置取样，再生成全局与分区结果 |
| `background_palette.dart` | `ImageProvider → 64px 解码 → 同一份像素喂给统计与调色板` |
| `background_scrim.dart` | 自动蒙层：在合成色上求最小透明度并复核，最多 0.8 |
| `background_tone_policy.dart` | 全局主题推荐 + 滞回 |
| `background_analysis_cache.dart` | 内存 LRU、缓存键（版本/采样尺寸/mtime/地址） |

阶段 B 只实现以上纯算法与模型，不接线、不改观感。

## 4. 算法口径

- 亮度只用 sRGB 线性化后的相对亮度；RGB 分量均值只用于「代表色」，不参与明暗判定。
- 直方图 16 桶；统计 mean/median/P10/P25/P75/P90；`darkRatio = luma < 0.18`，
  `brightRatio = luma > 0.82`。
- 3×3 分区各自出统计与建议墨色；全局与局部不互推。
- 自动蒙层：快门 4.5:1（正文）/ 3:1（大字号），以 1% 步进找最小透明度，
  在合成后的颜色上复核；到 0.8 仍不达标则标记 `needsTextPlate`。
- 主色只作为代表色之一；主题判定看分位与最坏前置色，不看单一 dominantColor。
- 视频：静帧优先；实时帧 ≤1 次/10s，中位亮度变化 >0.08 或直方图 L1 >0.25 才更新；
  暂停/不可见不采样。
- 缓存键不含蒙层、模糊、主题、文案、布局；这些变化不得触发解码。
- 单次分析 ≤ 一次 64px 解码 + ≤4096 像素循环；不新增依赖、不建 isolate。

## 5. 阶段 B～E

- **B（本轮）**：分析模型、亮度/分区/渐变/蒙层/主题滞回/缓存 + 常驻算法测试。
  门：`dart analyze` 干净；`flutter test test/app/background/tone` 以 exit code 为准。
- **C（已完成）**：`backgroundAnalysisProvider` 取代旧取色入口；`followTone`、`scrimMode` 接入；
  预览与正式共用 `AppBackgroundScrim`，`_StageScrim` 已删除。
  默认 `scrimMode=auto` + 自定义 0.45 作下限，原本可读的壁纸观感与今天一致；读不清的自动加深。
- **D（部分完成）**：设置页已加蒙层三档与「跟随背景明暗」；手动选主题自动关闭跟随。
  **局部 ink（标题栏、底栏、玻璃最低保护）尚未接线**：全局自动蒙层已保证正文对比度，
  局部 ink 留待需要更轻蒙层时再做。
- **E（未开始）**：视频低频采样与场景变化、静帧 key 加 mtime + 算法版本、验收图集逐项过。
  现状：视频色调取静帧（首次采样），同一片段内换场不会重新判定。

## 6. 常驻测试

```
apps/pure_live/test/app/background/tone/
├── image_brightness_analyzer_test.dart
├── image_region_analyzer_test.dart
├── gradient_analyzer_test.dart
├── contrast_analyzer_test.dart
├── background_tone_test.dart
└── background_analysis_cache_test.dart
```

覆盖：已知对比度夹具（黑白 21:1、红线不是 RGB 均值）、直方图与分位、alpha 合成、
3×3 分区、渐变 stops/角度/透明端、自动蒙层复核、主题滞回、LRU 淘汰与缓存键。
