enum AppRefreshRateMode {
  /// Leave frame-rate selection to Android. This is the fresh-install default.
  powerSaving('powerSaving'),

  /// Request the highest compatible rate only while the user is interacting.
  balanced('balanced'),

  /// Keep the highest compatible rate requested while the app is foregrounded.
  performance('performance');

  const AppRefreshRateMode(this.storageValue);

  final String storageValue;

  static AppRefreshRateMode parse(Object? value, {AppRefreshRateMode fallback = AppRefreshRateMode.powerSaving}) {
    final normalized = value?.toString().trim();
    for (final mode in values) {
      if (mode.storageValue == normalized) return mode;
    }
    return fallback;
  }
}
