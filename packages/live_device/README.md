# live_device

PureLive 的设备与系统能力服务。本包负责调用设备能力，不负责识别设备形态（由 `live_platform` 负责），也不决定何时操作（由 `live_playback` 或 App 业务负责）。

目前封装：

- **屏幕亮度**：`device_screen_brightness`
- **系统音量**：`volume_controller`

以下设备插件已归本包声明，但还没有对应的服务实现：`battery_plus`（电量）、
`refresh_rate`（刷新率）、`connectivity_plus`（网络连接状态）、
`device_info_plus`（设备信息）、`network_info_plus`（网络与 Wi-Fi 信息）、
`mobile_scanner`（扫码）。实现时请按现有服务的写法隐藏插件类型。

## 接入

在 workspace 根配置中加入 `packages/live_device`，并在 `apps/pure_live/pubspec.yaml` 声明：

```yaml
dependencies:
  live_device:
```

## 屏幕亮度

```dart
import 'package:live_device/live_device.dart';

final ScreenBrightnessService brightness =
    const PlatformScreenBrightnessService();

final capabilities = await brightness.getCapabilities();
if (capabilities.canOfferBrightnessControl) {
  final current = await brightness.getBrightness();
  await brightness.setBrightness(current.clamp(0, 100).toInt());
}
```

Android 上，应用窗口亮度不需要 `WRITE_SETTINGS` 特殊访问；修改系统亮度需要用户授权：

```dart
final granted = await brightness.requestPermission(
  scope: ScreenBrightnessScope.system,
);
if (granted) {
  await brightness.setBrightness(
    65,
    scope: ScreenBrightnessScope.system,
  );
}
```

亮度值统一使用整数百分比 `0–100`。在 iOS、Windows、macOS、Linux 中，底层插件会忽略 Android 专用的应用/系统模式并尝试操作系统或显示器亮度。桌面端受硬件、驱动、权限、虚拟机和远程桌面环境影响，必须读取能力并处理异常。

## 系统音量

```dart
import 'package:live_device/live_device.dart';

final SystemVolumeService volume = const PlatformSystemVolumeService();

final capabilities = await volume.getCapabilities();
if (capabilities.canOfferVolumeControl) {
  final current = await volume.getVolume();
  await volume.setVolume((current + 5).clamp(0, 100));
}

final muted = await volume.isMuted();
await volume.setMuted(muted: !muted);

final subscription = volume.watchVolume().listen((percentage) {
  // Update system-volume UI when hardware buttons or other apps change volume.
});

// Cancel when the consumer is disposed.
await subscription.cancel();
```

系统音量统一使用整数百分比 `0–100`；底层插件的 `0.0–1.0` 值会在封装内转换。`watchVolume()` 发出初始音量和后续变化，取消订阅时会取消对应的原生监听。

### 系统音量注意事项

- 这是**设备/系统输出音量**，不是播放器独立音量。若只想调整直播流的音量，应使用 `media_core` / `live_playback` 的播放器音量接口。
- `setMuted()` 的底层语义因平台不同而异。Windows、macOS、Linux 通常是真正的系统静音；iOS 没有公开的系统媒体静音 API，插件以音量归零并恢复先前音量模拟静音。部分旧 Android 版本也使用类似回退。
- `setSystemUiVisible(visible: false)` 只在 Android 和 iOS 支持，用于隐藏系统音量提示；其他平台返回 `false`，表示没有应用该设置。
- 所有声明支持的平台仍可能因为没有可用音频设备、Linux 混音器、驱动或系统限制而在运行时失败。捕获 `SystemVolumeException`，不要仅依赖能力快照。
- iOS 音量控制需要在真机测试；模拟器不能准确验证系统音量控制。

## 依赖边界

- `live_platform`：识别运行环境和设备形态。
- `live_device`：提供亮度、系统音量等设备操作 API。
- `live_playback`：决定播放期间何时调节、在何时恢复状态，并控制播放器自身音量。
- `live_uikit`：只提供滑块、图标和交互呈现，不直接依赖这些设备插件。

## 公共 API

### 亮度

- `ScreenBrightnessService`
- `PlatformScreenBrightnessService`
- `ScreenBrightnessCapabilities`
- `ScreenBrightnessScope`
- `ScreenBrightnessException`

### 系统音量

- `SystemVolumeService`
- `PlatformSystemVolumeService`
- `SystemVolumeCapabilities`
- `SystemVolumeException`
