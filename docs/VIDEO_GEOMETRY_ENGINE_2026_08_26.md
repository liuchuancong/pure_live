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

- 抖音先把播放器实际选中的 URL 反向关联到 `stream_data.data.<sdk_key>.main` 或同键
  `flv_pull_url` / `hls_pull_url_map`，再读取该条目的 `sdk_params.resolution` 或清晰度分辨率；
- `stream_orientation` 表示常规/双画面候选流的选择能力，并不直接表示横竖比例；顶层
  `extra.width/height` 也可能只是音频直播的 256×256 占位画布，两者均不作为节目比例；
- 已有具体播放 URL 却关联不到同一 `sdk_key` 时保持未知，交给解码器与有效画面检测，避免拿默认
  清晰度或另一双画面构图误裁当前画面；
- 精确选中流分辨率只负责首帧前的方向提示；它没有像素坐标，不再生成推测裁边，也不覆盖正常范围内
  的解码显示尺寸。只有两次一致的真实帧证据可以建立裁边。

### 1. 解码元数据

- MediaKit 原子读取同一 `VideoParams` 事件中的 `dw/dh`，缺失时才回退 `w/h`；该尺寸同时驱动
  Android 原生 Surface 与应用几何状态，正常范围内优先于平台提示；
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

每次识别同时保存截图自身的画布比例与裁边矩形，二者作为同一组原子证据提交，不把截图坐标套到
另一套解码宽高。普通帧直接交给播放器原生纹理的唯一 `BoxFit`；只有确认存在黑边时才增加一个
裁剪视口，先去除编码黑边，再执行用户的 contain/cover/fill。

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
- 弹幕面板覆盖播放器底部控制区时，面板上方保留独立“横屏全屏”入口；该入口只影响本次呈现，
  不回写用户的长期方向策略。

### 横屏全屏

- 视频保持可信竖屏比例并居中；
- 两侧使用缓存封面的低成本模糊暗化背景；
- 控件仍覆盖完整屏幕，模糊层不复制视频解码、不持续截图。
- 全屏的节目比例只约束解码视频图层，不把特殊 `BoxFit` 写入共用的 `UnifiedPlayer`、适配器或
  原生 Controller；普通页、全屏与小窗短暂并存时仍使用同一个用户 fit，避免路由重建顺序造成
  “最后写入者”比例污染。

### 系统 PiP / 应用内小窗

- 稳定竖屏源使用真实有效节目比例，应用内小窗形成竖长窗口；
- 应用内小窗的外层尺寸持续订阅呈现比例，晚到的解码/视觉证据会同时调整纹理和窗口边界，
  不再只在创建小窗的一刻冻结 16:9；
- Android PiP 先切到仅视频的紧凑 Surface，等一帧布局完成后，以真实 contain 可视矩形生成
  `sourceRectHint`；请求比例与可视矩形保持一致，并在可靠比例变化时更新活动 PiP 参数；
- 小窗只保留紧凑控制和有限弹幕轨道；
- 普通横屏、方形、未知源仍使用既有 16:9 小窗合同。

## 普通直播保护条件

- 新布局只在稳定有效方向为 portrait、总开关开启、手机宽度断点内生效；
- 普通横屏继续原 16:9 页面、黑色全屏背景和原小窗比例；
- 画面分析只有强对称黑边 + 活跃中心 + 两次一致证据才接管；
- 平台方向提示不推导黑边，原生纹理始终按真实画布比例布局；
- 普通帧不再经过“外层 `FittedBox` + 播放器内层 `FittedBox`”的重复缩放；竖屏页、横屏全屏、
  应用小窗与系统 PiP 共用同一个不可变 `VideoPresentationGeometry`；
- 渲染末端要求裁边后的比例与最终呈现比例一致，阻断旧裁边或异常裁边造成的二次压窄；
- 识别结果、手动覆盖、质量切换、全屏与 PiP 均有确定性测试；
- 运行期不安装 cropdetect 滤镜，不增加持续 CPU/GPU 任务。
