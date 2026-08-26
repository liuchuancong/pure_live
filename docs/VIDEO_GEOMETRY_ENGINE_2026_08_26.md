# Video Geometry Engine（2026-08-26）

## 目标

直播源存在三类彼此不同的几何信息：

1. **编码画布**：解码器报告的 `dw/dh`、旋转与像素宽高；
2. **有效节目区域**：画布内去掉上下黑边/左右黑边后真正的视频内容；
3. **呈现窗口**：普通竖屏页、横屏全屏、系统 PiP、应用内小窗的目标比例。

旧链路把三者当成同一个比例，遇到“16:9 画布内嵌 9:16 直播”时会被识别成横屏；强行设成
9:16 又会拉伸画面，并把同一个错误带到横屏与小窗。本轮将它们拆成独立证据和独立边界。

## 成熟方案依据

- Android PiP：提前发布 `PictureInPictureParams`，画面比例变化时继续更新参数，使用
  `sourceRectHint` 与 `setSeamlessResizeEnabled(true)` 改善进出动画：
  <https://developer.android.com/develop/ui/views/picture-in-picture>
- Media3 `PlayerView`：播放器呈现采用明确的 fit/zoom/fill 策略，视频优先使用 Surface：
  <https://developer.android.com/reference/androidx/media3/ui/PlayerView>
- mpv：以 `video-params` / `video-out-params` 作为显示尺寸事实来源，并提供 crop、aspect、rotate
  等属性：<https://github.com/mpv-player/mpv/blob/master/DOCS/man/input.rst>
- mpv 官方 autocrop 与 FFmpeg cropdetect 都说明暗场会产生歧义；持续启用滤镜还可能影响硬解路径。
  因此本项目采用“新会话有界、低分辨率、证据满足后立即停止”的截图分析，不在渲染循环运行检测：
  <https://github.com/mpv-player/mpv/blob/master/TOOLS/lua/autocrop.lua>
- LiveKit Flutter 的渲染器以真实 track 尺寸驱动 contain/cover，而不是让多个父子组件重复决定比例：
  <https://github.com/livekit/client-sdk-flutter/blob/main/lib/src/widgets/video_track_renderer.dart>

## 统一识别链

### 0. 平台流声明

- 抖音优先读取 `stream_url.extra.width/height`；
- 缺失时读取默认清晰度 `resolution`、`stream_data.main.sdk_params` 和方向一致的候选分辨率；
- 平台声明描述节目比例，解码元数据描述传输画布，两者分别保存；
- 强声明可修正异常采样宽高，并为横屏画布内的竖屏节目提供跨播放器内核的初始几何。

### 1. 解码元数据

- MediaKit 原子读取同一 `VideoParams` 事件中的 `dw/dh`，缺失时才回退 `w/h`；
- 旋转只归一化一次；
- 三次一致样本或 500 ms 稳定窗口后提交方向；
- 质量/线路切换的单个混合尺寸只成为候选，不立即翻转布局。

### 2. 有效画面识别

`ActiveVideoContentAnalyzer` 在 192 px 宽的小图上分析：

- 左右/上下边缘的亮度、暗像素比例与方差；
- 两侧黑边的对称性、最小占比与中间保留区域；
- 中央节目区域必须具备足够亮度或纹理变化；
- 弹幕造成的少量白色像素按局部窗口容错；
- 两次高置信度且边界一致的结果才提交；首帧为空或转场时继续后续有界采样；
- 全暗场、转场、非对称遮罩与低置信结果保持现有几何。

识别得到的裁边矩形只进入呈现几何。Flutter 用一个裁剪视口显示原始比例纹理，先去除编码黑边，
再执行用户的 contain/cover/fill，避免把 16:9 画布直接压成 9:16。

### 3. 会话、缓存与回退

- 每次房间、线路、清晰度源切换都会生成新的 geometry generation；旧 Timer 的结果自动失效，
  上一画布的裁边坐标立即清除；
- 同一进程内保存最多 96 个房间、最长 4 小时的稳定几何；重进房间先显示 provisional 快照，
  新的解码证据随后接管，避免 16:9 -> 9:16 的视觉跳变；
- 缓存按 `platform:roomId` 隔离，不跨房间复用；
- 手动“自动/竖屏/横屏”仍是最高呈现优先级，并可保留为房间设置；
- MediaKit 截图能力缺席时自然退回解码元数据链。

## 三种竖屏呈现

### 普通竖屏直播页

- 竖屏视频使用完整可用画布；
- 弹幕与画质区域成为独立手势的三档面板（收起/中间/展开）；
- 只拖动顶部把手改变面板高度，列表滑动手势继续完全属于弹幕列表；
- `balanced` 默认中档，`immersive` 默认收起档，`compatibility` 继续旧布局。

### 横屏全屏

- 视频保持可信竖屏比例并居中；
- 两侧使用缓存封面的低成本模糊暗化背景；
- 控件仍覆盖完整屏幕，模糊层不复制视频解码、不持续截图。

### 系统 PiP / 应用内小窗

- 稳定竖屏源使用真实有效节目比例，应用内小窗形成竖长窗口；
- Android PiP 入场使用 `sourceRectHint`、无缝缩放，并在识别结果变化后更新活动 PiP 参数；
- 小窗只保留紧凑控制和有限弹幕轨道；
- 普通横屏、方形、未知源仍使用既有 16:9 小窗合同。

## 普通直播保护条件

- 新布局只在稳定有效方向为 portrait、总开关开启、手机宽度断点内生效；
- 普通横屏继续原 16:9 页面、黑色全屏背景和原小窗比例；
- 画面分析只有强对称黑边 + 活跃中心 + 两次一致证据才接管；
- 渲染末端要求裁边后的比例与最终呈现比例一致，阻断旧裁边或异常裁边造成的二次压窄；
- 识别结果、手动覆盖、质量切换、全屏与 PiP 均有确定性测试；
- 运行期不安装 cropdetect 滤镜，不增加持续 CPU/GPU 任务。
