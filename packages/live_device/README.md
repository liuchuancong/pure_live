# live_device

PureLive 的设备与系统能力服务。本包负责调用设备能力，不负责识别设备形态（由 `live_platform` 负责），也不决定何时操作（由 `live_playback` 或 App 业务负责）。

目前封装：

- **屏幕亮度**：`device_screen_brightness`
- **系统音量**：`volume_controller`
- **电量与充电状态**：`battery_plus`
- **屏幕刷新率**：`refresh_rate`
- **网络连接状态**：`connectivity_plus`
- **Wi-Fi 网络信息**：`network_info_plus`
- **设备身份信息**：`device_info_plus`
- **屏幕常亮**：`wakelock_plus`

扫码（`mobile_scanner`）不属于本包，也没有列在依赖里：它的控制器 `start()` 会等
`attach()`，而 `attach()` 只由预览 widget 的 `initState` 调用，widget 不进 widget tree
就抛 `controllerNotAttached`。也就是说真正渲染相机预览的那一层必须自己声明这个插件，
在这里套一层"隐藏插件类型"的服务只会误导调用方以为预览是可选的。

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

## 电量

```dart
import 'package:live_device/live_device.dart';

final BatteryService battery = const PlatformBatteryService();

final int level = await battery.readLevel(); // 0–100，-1 表示这台设备没有电池
final BatteryStatus status = await battery.readStatus();
final bool saving = await battery.isInPowerSaveMode();

final subscription = battery.watchStatus().listen((status) {
  // 更新充电指示
});
await subscription.cancel();
```

- 台式机这类没有电池的设备返回 `-1` / `unknown`，不抛异常；要按值判断，别按异常判断。
- Linux 没有省电模式查询，`isInPowerSaveMode()` 抛 `BatteryException(code: 'unsupported_on_platform')`，先读 `BatteryCapabilities.canReadPowerSaveMode`。
- `watchStatus()` 映射插件的广播流，可以多方监听，每个订阅各自 `cancel()`。

## 屏幕刷新率

```dart
final DisplayRefreshRateService refresh = const PlatformDisplayRefreshRateService();

final DisplayRefreshRate rate = await refresh.read();
if (rate.canExceedSixtyHertz) {
  await refresh.matchContent(hz: 60); // 让内容与屏幕刷新率对齐
}
```

- Windows、macOS、Linux 的原生实现把支持位写死为 false：查询照常，`preferMaximum()`、`preferDefault()`、`matchContent()` 返回 `DisplayRefreshRatePreference.unsupported`，既不改动系统也不抛异常。
- `isLowPowerMode` 与 `thermalState` 是同步读取的快照，可能落后于系统状态；省电/发热降级时 `currentHz` 会变。
- 插件的 `superseded` 归入本包的 `failed`，调用方不需要区分是被后来的请求顶掉还是失败。

## 网络连接状态

```dart
final NetworkConnectivityService connectivity = const PlatformNetworkConnectivityService();

final NetworkConnectivity snapshot = await connectivity.read();
if (snapshot.isOnline) { ... }

final subscription = connectivity.watch().listen((event) { ... });
```

- 插件的变化流经过 `distinct` 后是**单订阅**流，`watch()` 为每个返回的流自己建订阅、`cancel()` 时收回；同一个流不能听第二次。
- 一次报告可能同时列出多个接口（Wi-Fi + VPN），`NetworkConnectivity.interfaces` 是去重集合，`isOnline` 只在平台只报了 `none` 时为 false。

## Wi-Fi 网络信息

```dart
final WifiNetworkInfo info = await const PlatformWifiInfoService().read();
```

- 没有变化流，只有快照读。
- `read()` 把"这个平台没有这项查询"按字段吞成 `null`（`UnsupportedError`、`UnimplementedError`、`MissingPluginException`），其余异常仍抛 `WifiInfoException`；能力位见 `WifiInfoCapabilities`。
- Android 10+ 读 SSID/BSSID 需要定位权限，拿不到时是 `null`（插件已把 `<unknown ssid>` 归一为 `null`），`requiresAndroidLocationPermission` 用来提示用户。

## 屏幕常亮

```dart
final ScreenAwakeService awake = const PlatformScreenAwakeService();

await awake.setEnabled(enabled: true); // 播放期间保持屏幕点亮
final bool on = await awake.isEnabled;
await awake.disable();
```

- 这只是屏幕 wakelock，不让 Dart isolate 或 CPU 在应用退到后台后继续运行。
- 何时开关由 `live_playback` 或 App 业务决定，本包不从播放状态推断策略。

## 设备身份信息

```dart
final DeviceIdentity device = await const PlatformDeviceIdentityService().read();
```

- 模型只留诊断字段。`identifierForVendor`、Android ID、`machineId`、`digitalProductId` 一类稳定标识符刻意不暴露，本包不做设备追踪。
- 内存统一到 MB：Android/iOS/Windows 原生给出的就是 MB，macOS 是字节、浏览器是 GiB，由封装内折算；平台报告 0 或 `-1` 记为 `null`。

## 依赖边界

- `live_platform`：识别运行环境和设备形态。
- `live_device`：提供亮度、音量、电量、刷新率、网络、屏幕常亮和设备身份等设备 API。
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

### 电量

- `BatteryService`
- `PlatformBatteryService`
- `BatteryCapabilities`
- `BatteryStatus`
- `BatteryException`

### 屏幕刷新率

- `DisplayRefreshRateService`
- `PlatformDisplayRefreshRateService`
- `DisplayRefreshRate`
- `DisplayRefreshRateCapabilities`
- `DisplayRefreshRatePreference`
- `DisplayThermalState`
- `DisplayRefreshRateException`

### 网络连接状态

- `NetworkConnectivityService`
- `PlatformNetworkConnectivityService`
- `NetworkConnectivity`
- `NetworkInterface`
- `NetworkConnectivityCapabilities`
- `NetworkConnectivityException`

### Wi-Fi 网络信息

- `WifiInfoService`
- `PlatformWifiInfoService`
- `WifiNetworkInfo`
- `WifiInfoCapabilities`
- `WifiInfoException`

### 屏幕常亮

- `ScreenAwakeService`
- `PlatformScreenAwakeService`
- `ScreenAwakeException`

### 设备身份信息

- `DeviceIdentityService`
- `PlatformDeviceIdentityService`
- `DeviceIdentity`
- `DeviceIdentityCapabilities`
- `DeviceIdentityException`
