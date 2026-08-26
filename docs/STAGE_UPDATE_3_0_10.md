# v3.0.10 Android 横屏全屏竖屏展示修复

- 版本：`3.0.10+4098`
- 目标：Android `arm64-v8a` Release APK
- 冻结基线：`wzgrx/pure_live@2dbd1a9c`
- 来源分类：`fork-regression`
- 首个错误状态：维护分支提交 `646f3db2613c953baf533e2fd18b43fe45376205` 加入全屏模糊背景，但没有把专用 fit/fill 契约传到播放器原生视口
- 上游：本轮不合并上游，只修复维护仓库横屏全屏渲染链
- 设备操作：仅代码审查、官方资料对照和自动化验证，不操作手机

## 为什么只有横屏全屏仍异常

普通竖屏页与应用内小窗已经把外部容器调整为竖屏比例，原生播放器即使读取全局 `fill/cover`，错误也不明显。横屏全屏容器固定为宽屏，旧实现仍把用户的普通画面适配选项传给 9:16 纹理：

- `BoxFit.fill` 会改变宽高比并横向拉伸；
- `BoxFit.cover` 会保留比例但裁掉大量上下内容；
- 只有 `BoxFit.contain` 能在横屏视口中完整居中显示竖屏节目。

已有 `PortraitFullscreenPresentation` 确实放置了模糊封面，但其上方的播放器原生视口仍由 MediaKit 的 `fill`、FijkView 的 `color` 或 BetterPlayer 外层表面填成黑色。全屏黑画布把背景完全盖住，所以表现为“两侧只有黑色”，不是封面 URL 或模糊算法没有执行。

## 修复设计

1. 在构建任何原生视频 Widget 之前，由 `resolveFullscreenVideoSurfaceStyle` 原子决定全屏视口：稳定竖屏 + 适配开关开启时固定 `contain + transparent`，其他直播保持全局 fit + 黑色表面。
2. `UnifiedPlayer.getVideoWidget` 把 `fit` 与 `fill` 分离；`fit` 只控制纹理缩放，`fill` 只控制未被纹理覆盖的视口。
3. MediaKit、Fijk 和 BetterPlayer 三套适配器接收相同合同，避免更换播放器内核后复发。
4. 背景按详情封面、房间封面、详情头像、房间头像回退；网络资源缺席时使用低成本暗色渐变。
5. 全屏展示订阅不可变 `VideoPresentationGeometry` 修订号，首帧后才确认的竖屏方向也能原地切换到专用展示，不重建播放会话。
6. 竖屏全屏临时锁定 contain，但不写回用户的普通画面 fit 配置；退出后原设置继续生效。

## 其他平台与异常比例

这套识别不是抖音专用分支。所有站点在得到播放 URL 后都进入同一个播放器管理层，解码器发布的显示宽高经过同一 `PortraitStreamDetector` 和 `VideoPresentationGeometry`：Bilibili、斗鱼、虎牙、抖音、快手、网易 CC、Twitch、SOOP、YY 与自定义源的直接 9:16/3:4 直播均按内容尺寸处理。

证据边界也保持明确：

- 正确发布显示宽高的直接竖屏、横屏、方形与常见非 16:9 流：由原生纹理唯一保留比例；
- 16:9 编码画布内嵌竖屏内容：需要两次一致的真实帧边界证据，默认 MediaKit 路径可以纠正；
- 服务器给出错误 SAR/宽高、首帧长期纯黑、画中画合成或动态横竖切换：先保持上一个可信状态，后续真实证据纠正；用户也可使用当前直播间的手动横/竖屏覆盖；
- 站点接口是否能取得播放地址属于独立的外部接口证据，不由画面比例引擎替代。

因此，平台名称本身不会形成遗漏；关键在于解码器或真实帧能否提供可靠几何证据。发布说明会分别记录代码覆盖、自动化覆盖与未进行的设备采样，不使用绝对化结论。

## 参考依据

- Flutter [`BoxFit`](https://api.flutter.dev/flutter/painting/BoxFit.html)：`fill` 会扭曲宽高比，`contain` 保持比例并完整显示源。
- Android Media3 [`AspectRatioFrameLayout`](https://developer.android.com/reference/androidx/media3/ui/AspectRatioFrameLayout)：FIT、FILL 与 ZOOM 是不同的内容缩放模式。
- [media-kit Video 实现](https://github.com/media-kit/media-kit/blob/main/media_kit_video/lib/src/video/video_texture.dart)：Video Widget 自身拥有 `fit` 与 `fill`，应用必须在原生视口层传入专用值。
- 抖音开放平台 [`live-player`](https://developer.open-douyin.com/docs/resource/zh-CN/mini-app/develop/component/media-component/live-player/)：`orientation` 与 `object-fit` 分离；全屏方向另由 requestFullScreen 管理。

## 回归范围

- 横屏全屏竖屏内容固定 contain；
- 透明 surface 从布局层传到原生播放器合同；
- 模糊封面及头像/渐变回退；
- 九个平台 ID 使用相同 720×1280 解码尺寸均稳定分类为竖屏；
- 普通横屏不启用环境背景、不覆盖用户 fit；
- 普通竖屏、应用小窗、PiP、实测黑边、音频模式和播放器生命周期继续纳入正式全量门禁。

最终 Analyze、完整 Flutter 回归、公开接口探测、APK 内容、ABI、签名与 SHA-256 记录将在正式交付后补充。
