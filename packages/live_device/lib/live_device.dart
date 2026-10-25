/// Device and operating-system capability services for PureLive.
///
/// This package intentionally hides third-party plugin types from callers.
library;

export 'src/audio/volume/platform_system_volume_service.dart' show PlatformSystemVolumeService;
export 'src/audio/volume/system_volume_capabilities.dart' show SystemVolumeCapabilities;
export 'src/audio/volume/system_volume_exception.dart' show SystemVolumeException;
export 'src/audio/volume/system_volume_service.dart' show SystemVolumeService;
export 'src/display/brightness/platform_screen_brightness_service.dart' show PlatformScreenBrightnessService;
export 'src/display/brightness/screen_brightness_capabilities.dart'
    show ScreenBrightnessCapabilities, ScreenBrightnessWriteSupport;
export 'src/display/brightness/screen_brightness_exception.dart' show ScreenBrightnessException;
export 'src/display/brightness/screen_brightness_scope.dart' show ScreenBrightnessScope;
export 'src/display/brightness/screen_brightness_service.dart' show ScreenBrightnessService;
export 'src/display/refresh_rate/display_refresh_rate.dart' show DisplayRefreshRate, DisplayThermalState;
export 'src/display/refresh_rate/display_refresh_rate_capabilities.dart' show DisplayRefreshRateCapabilities;
export 'src/display/refresh_rate/display_refresh_rate_exception.dart' show DisplayRefreshRateException;
export 'src/display/refresh_rate/display_refresh_rate_preference.dart' show DisplayRefreshRatePreference;
export 'src/display/refresh_rate/display_refresh_rate_service.dart' show DisplayRefreshRateService;
export 'src/display/refresh_rate/platform_display_refresh_rate_service.dart' show PlatformDisplayRefreshRateService;
export 'src/network/adapter/ip_address.dart' show IpAddress, IpAddressVersion;
export 'src/network/adapter/network_adapter.dart' show NetworkAdapter;
export 'src/network/adapter/network_adapter_capabilities.dart' show NetworkAdapterCapabilities;
export 'src/network/adapter/network_adapter_exception.dart' show NetworkAdapterException;
export 'src/network/adapter/network_adapter_service.dart' show NetworkAdapterService;
export 'src/network/adapter/platform_network_adapter_service.dart' show PlatformNetworkAdapterService;
export 'src/network/connectivity/network_connectivity.dart' show NetworkConnectivity;
export 'src/network/connectivity/network_connectivity_capabilities.dart' show NetworkConnectivityCapabilities;
export 'src/network/connectivity/network_connectivity_exception.dart' show NetworkConnectivityException;
export 'src/network/connectivity/network_connectivity_service.dart' show NetworkConnectivityService;
export 'src/network/connectivity/network_interface.dart' show NetworkInterface;
export 'src/network/connectivity/platform_network_connectivity_service.dart' show PlatformNetworkConnectivityService;
export 'src/network/wifi/platform_wifi_info_service.dart' show PlatformWifiInfoService;
export 'src/network/wifi/wifi_info_capabilities.dart' show WifiInfoCapabilities;
export 'src/network/wifi/wifi_info_exception.dart' show WifiInfoException;
export 'src/network/wifi/wifi_info_service.dart' show WifiInfoService;
export 'src/network/wifi/wifi_network_info.dart' show WifiNetworkInfo;
export 'src/power/battery/battery_capabilities.dart' show BatteryCapabilities;
export 'src/power/battery/battery_exception.dart' show BatteryException;
export 'src/power/battery/battery_service.dart' show BatteryService;
export 'src/power/battery/battery_status.dart' show BatteryStatus;
export 'src/power/battery/platform_battery_service.dart' show PlatformBatteryService;
export 'src/power/screen_awake/platform_screen_awake_service.dart' show PlatformScreenAwakeService;
export 'src/power/screen_awake/screen_awake_exception.dart' show ScreenAwakeException;
export 'src/power/screen_awake/screen_awake_service.dart' show ScreenAwakeService;
export 'src/system/device_identity/device_identity.dart' show DeviceIdentity;
export 'src/system/device_identity/device_identity_capabilities.dart' show DeviceIdentityCapabilities;
export 'src/system/device_identity/device_identity_exception.dart' show DeviceIdentityException;
export 'src/system/device_identity/device_identity_service.dart' show DeviceIdentityService;
export 'src/system/device_identity/platform_device_identity_service.dart' show PlatformDeviceIdentityService;
export 'src/system/startup/platform_startup_service.dart' show PlatformStartupService;
export 'src/system/startup/startup_service.dart' show StartupCapabilities, StartupException, StartupService;
