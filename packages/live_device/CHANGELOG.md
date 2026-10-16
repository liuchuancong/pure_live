# Changelog

## Unreleased

### Added

- `ScreenBrightnessService` over `device_screen_brightness`: 0-100 integer
  percentages, application/system scope, a capability snapshot, permission
  request and a brightness change stream.
- `SystemVolumeService` over `volume_controller`: 0-100 integer percentages,
  mute, a volume change stream and the Android/iOS system overlay switch.
- `BatteryService` over `battery_plus`: level, charging status, power-save
  reading and a status stream, with `-1`/`unknown` kept as the platform's way of
  saying "this machine has no battery".
- `DisplayRefreshRateService` over `refresh_rate`: current/max/supported rates,
  a rate stream, low-power and thermal snapshots, and the prefer-max,
  prefer-default and match-content intents.
- `NetworkConnectivityService` over `connectivity_plus`: the interface set that
  is up, an online verdict, and a change stream that owns one native
  subscription per returned stream, because the plugin's own stream is
  single-subscription.
- `WifiInfoService` over `network_info_plus`: SSID, BSSID, addressing and
  broadcast name, read per field so one unavailable lookup does not discard the
  rest.
- `DeviceIdentityService` over `device_info_plus`: one narrow identity model
  across the six platform backends, memory normalized to megabytes, and
  deliberately no vendor or hardware tracking identifiers.

- `ScreenAwakeService` over `wakelock_plus`: enable, disable and read the
  screen wakelock, with playback policy left to the caller.
- `NetworkAdapterService` over `dart:io`: every adapter with every address bound
  to it, including prefix length and broadcast, because a host legitimately
  holds several addresses at once — `192.168.x.x` beside a VPN `10.x.x.x`.

### Changed

- `DeviceIdentity.processorCount` is `logicalProcessorCount`, and
  `DeviceIdentityCapabilities.reportsProcessorCount` follows: every source behind
  it counts scheduling threads (`dwNumberOfProcessors`, `hw.availcpu`,
  `hardwareConcurrency`), not physical cores.
- `ScreenBrightnessCapabilities.targetsPrimaryDisplay` and
  `BatteryCapabilities.aggregatesPowerSources` are required fields;
  `DisplayRefreshRate.monitorCount` is optional. All three exist because the
  underlying plugins answer for one display or one folded power source while the
  machine may have several.

### Notes

- `WifiNetworkInfo.ipv4Address`/`ipv6Address` are renamed
  `primaryIpv4Address`/`primaryIpv6Address`: the plugin truncates to the first
  address per family on every platform, and the old names implied otherwise.
- `mobile_scanner` is not a dependency of this package: its controller only
  emits frames once its preview widget is attached to the widget tree, so the
  layer that renders the scanner has to declare the plugin itself.
- Declared here are the device plugins the app used to declare directly:
  `battery_plus`, `connectivity_plus`, `device_info_plus`, `network_info_plus`,
  `refresh_rate` and `wakelock_plus`.
