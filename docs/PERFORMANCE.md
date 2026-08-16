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
- 弹幕列表使用独立响应式消息源，播放器状态变化不再触发列表自动滚动；消息项使用对象键复用，列表固定保留最近 100 条。
- 播放器内弹幕样式变化按渲染帧合并更新，持久化写入使用 160 ms 尾端去抖并在退出前补写最终值，减少拖动滑块时的配置重建和磁盘写入。
- 延迟初始化的 FFmpeg、缓存、录制、解析和账号服务分别隔离故障；单个可选服务初始化异常不再阻断后续服务，并记录不含请求参数的错误类型与调用栈。
- 缓存目录统计与清理使用异步文件 I/O，缩略图自动刷新带有并发保护，减少大缓存目录阻塞界面的概率。

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

参考：[Flutter Impeller 官方说明](https://docs.flutter.dev/perf/impeller)、[Android 帧率优化说明](https://developer.android.com/media/optimize/performance/frame-rate)。

返回 [文档索引](README.md)。
