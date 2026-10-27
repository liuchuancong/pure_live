/// Device and operating-system capability services for PureLive.
///
/// This package intentionally hides third-party plugin types from callers.
library;

export 'src/audio/volume/volume.dart';
export 'src/display/brightness/brightness.dart';
export 'src/display/orientation/orientation.dart';
export 'src/display/refresh_rate/refresh_rate.dart';
export 'src/network/adapter/adapter.dart';
export 'src/network/connectivity/connectivity.dart';
export 'src/network/system_proxy/platform_system_proxy_service.dart' show PlatformSystemProxyService;
export 'src/network/system_proxy/system_proxy.dart'
    show SystemProxyCapabilities, SystemProxyEndpoint, SystemProxyService, SystemProxyStatus;
export 'src/network/wifi/wifi.dart';
export 'src/power/battery/battery.dart';
export 'src/power/screen_awake/screen_awake.dart';
export 'src/system/device_identity/device_identity.dart' show DeviceIdentity;
export 'src/system/device_identity/device_identity_capabilities.dart' show DeviceIdentityCapabilities;
export 'src/system/device_identity/device_identity_exception.dart' show DeviceIdentityException;
export 'src/system/device_identity/device_identity_service.dart' show DeviceIdentityService;
export 'src/system/device_identity/platform_device_identity_service.dart' show PlatformDeviceIdentityService;
export 'src/system/startup/startup.dart';
