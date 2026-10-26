/// Every provider the app shares across its windows and pages, grouped by
/// what it owns: boot, theme, settings, browsing, navigation, windows, the
/// player, the network and the device. Import this one file instead of the
/// providers it happens to use.
library;

export 'boot/boot.dart';
export 'browse/browse.dart';
export 'device/device.dart';
export 'navigation/navigation.dart';
export 'network/network.dart';
export 'player/player.dart';
export 'settings/settings.dart';
export 'theme/theme.dart';
export 'window/window.dart';
