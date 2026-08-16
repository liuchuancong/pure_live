# Android 高刷新率与性能验证

Pure Live 在 Android 上默认启用高刷新率模式：应用会在当前屏幕分辨率的可用显示模式中请求最高刷新率。原生层持续监听显示器模式变化，折叠屏切换、外接屏变化、应用恢复前台或系统调整显示模式后都会重新检测并回传当前/最高 Hz。用户可在“设置 → 通用 → 高刷新率显示”关闭该选项。

## 本次性能路径

- 恢复 Flutter 在 Android API 29+ 的默认 Impeller 渲染路径；不支持 Vulkan 的设备由 Flutter 回退到兼容渲染器。
- Android 原生层按当前物理分辨率选择最高刷新率显示模式，同时设置首选模式 ID 和首选刷新率；显示变化事件使用 160 ms 去抖，避免系统切换模式时反复提交窗口参数。
- 直播卡片封面统一使用磁盘/内存缓存，并按控件像素宽度下采样，减少大图解码和滚动时重复下载。
- 网格封面加载占位改为静态绘制，减少大量卡片同时创建动画控制器。
- 首页、分区、收藏与搜索结果使用固定高度懒加载网格，移除固定高度卡片上的瀑布流布局计算。
- 封面按实际设备像素宽度解码，上限从 1440 降到 960，并关闭列表图片淡入淡出动画。
- 主播放器与小窗弹幕使用独立重绘边界，并限制表情图片缓存，降低视频、控制栏和弹幕之间的无关重绘及内存压力。
- 弹幕列表使用 80 ms 合帧更新和独立可见快照；用户上滑后冻结当前 500 条视图并累计新消息数，回到底部时一次同步，避免热门房间持续顶走正在阅读的内容。
- Android/Windows/Linux 使用平台夹持滚动物理模型，iOS/macOS 保留弹性模型；应用全局页面不再强制套用 iOS 弹簧阻尼。
- 主播放器与小窗弹幕 FPS 可动态采用设备最高刷新率，`flame_barrage` 引擎按配置帧间隔推进；不同轨道保留轻量速度差异。
- 播放器内弹幕样式变化按渲染帧合并更新，持久化写入使用 160 ms 尾端去抖并在退出前补写最终值，减少拖动滑块时的配置重建和磁盘写入。
- 数据库、设置、自定义字体和直播页必需控制器在首屏前完成注册；FFmpeg、解析和账号服务继续延迟预热，消除更新后首次启动与快速点击搜索结果的初始化竞态。
- 缓存目录统计与清理使用异步文件 I/O，缩略图自动刷新带有并发保护，减少大缓存目录阻塞界面的概率。
- 收藏直播间详情刷新在内存中批量合并，整个周期只写入一次 Hive，并保留本地标签，降低定时刷新时的序列化、磁盘写入和响应式重建次数。

高刷新率会增加 GPU、CPU 和电量消耗。设备处于省电模式、过热、低电量或厂商应用级刷新率限制时，系统仍可能降低实际刷新率。

## 真机检查

安装本地 APK 后，可先确认系统给应用分配的显示模式：

```powershell
adb shell dumpsys display | Select-String -Pattern "mMode|supportedModes|refreshRate"
```

检查应用渲染帧统计：

```powershell
adb shell dumpsys gfxinfo com.mystyle.purelive reset
# 在手机上连续滚动首页、收藏页并进入/退出直播间
adb shell dumpsys gfxinfo com.mystyle.purelive framestats > .\local-artifacts\gfxinfo-framestats.txt
```

重点观察：

1. 首页和收藏列表的快速滚动；
2. 直播间控制栏淡入淡出；
3. 普通弹幕高密度场景；
4. Android 系统画中画与应用内悬浮窗；
5. 设备温度上升后的持续表现。

发布性能结论时记录设备型号、Android 版本、屏幕 Hz、应用版本、播放器、直播清晰度、弹幕 FPS，以及测试是否处于充电/省电/高温状态。

本轮 Android 16 / 120 Hz 设备实测：`mActiveRenderFrameRate=120.00001`，系统记录 `AppRequestRefreshRates=120 Hz`；覆盖安装后的 5 次冷启动 `TotalTime` 为 239–274 ms，均保持前台可见且崩溃缓冲区为空。横竖屏切换后视频弹幕与弹幕列表继续更新。

参考：[Flutter Impeller 官方说明](https://docs.flutter.dev/perf/impeller)、[Android 帧率优化说明](https://developer.android.com/media/optimize/performance/frame-rate)。

返回 [文档索引](README.md)。
