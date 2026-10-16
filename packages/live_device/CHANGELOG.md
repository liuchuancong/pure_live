# Changelog

## Unreleased

### Added

- `ScreenBrightnessService` over `device_screen_brightness`: 0-100 integer
  percentages, application/system scope, a capability snapshot, permission
  request and a brightness change stream.
- `SystemVolumeService` over `volume_controller`: 0-100 integer percentages,
  mute, a volume change stream and the Android/iOS system overlay switch.
- Declared the device plugins this package owns: `battery_plus`,
  `connectivity_plus`, `device_info_plus`, `mobile_scanner`,
  `network_info_plus` and `refresh_rate`. Their services are not implemented
  yet; the app declared these plugins directly before they moved here.
