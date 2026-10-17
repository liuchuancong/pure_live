/// Throws for a `DevicePlatform.device` (auto-detect) that reached [where],
/// which needs the style that `SettingsList` resolves it to. Internal.
Never throwUnresolvedPlatform(String where) => throw Exception(
  'You can\'t use the DevicePlatform.device in this context. '
  'Incorrect platform: $where',
);
