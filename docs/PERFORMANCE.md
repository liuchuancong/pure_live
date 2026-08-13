# Android 高刷新率与性能验证

Pure Live 在 Android 上默认启用高刷新率模式：应用会在当前屏幕分辨率的可用显示模式中请求最高刷新率。用户可在“设置 → 通用 → 高刷新率显示”查看当前/最高 Hz 并关闭该选项。

## 本次性能路径

- 恢复 Flutter 在 Android API 29+ 的默认 Impeller 渲染路径；不支持 Vulkan 的设备由 Flutter 回退到兼容渲染器。
- Android 原生层按当前物理分辨率选择最高刷新率显示模式，避免为追求 Hz 切换到不同分辨率。
- 直播卡片封面统一使用磁盘/内存缓存，并按控件像素宽度下采样，减少大图解码和滚动时重复下载。
- 网格封面加载占位改为静态绘制，减少大量卡片同时创建动画控制器。
- 主播放器与小窗弹幕使用独立重绘边界，并限制表情图片缓存，降低视频、控制栏和弹幕之间的无关重绘及内存压力。

高刷新率会增加 GPU、CPU 和电量消耗。设备处于省电模式、过热、低电量或厂商应用级刷新率限制时，系统仍可能降低实际刷新率。

## 真机检查

安装 QA APK 后，可先确认系统给应用分配的显示模式：

```powershell
adb shell dumpsys display | Select-String -Pattern "mMode|supportedModes|refreshRate"
```

检查应用渲染帧统计：

```powershell
adb shell dumpsys gfxinfo com.mystyle.purelive.qa reset
# 在手机上连续滚动首页、收藏页并进入/退出直播间
adb shell dumpsys gfxinfo com.mystyle.purelive.qa framestats > .\local-artifacts\gfxinfo-framestats.txt
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
