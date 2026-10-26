import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// The live-alert choice (the reference's `liveAlertEnabled` /
/// `liveAlertTagIds`): whether followed rooms raise a system notification
/// when they begin broadcasting, and which local tags the alerts cover. No
/// chosen tag means every follow.
typedef LiveAlertSettings = ({bool enabled, List<String> tagIds});

const String _enabledKey = 'refresh.liveAlerts.enabled';
const String _tagsKey = 'refresh.liveAlerts.tags';

/// How often covered follows are checked while the app runs when no page is
/// refreshing them (the reference's 15 minutes).
const Duration kLiveAlertCheckInterval = Duration(minutes: 15);

/// Owns the live-alert switch and its tag filter.
final class LiveAlertSettingsController extends Notifier<LiveAlertSettings> {
  @override
  LiveAlertSettings build() {
    try {
      return (
        enabled: StoragePrefs.getBool(_enabledKey) ?? false,
        tagIds: _cleanTags(StoragePrefs.getStringList(_tagsKey) ?? const []),
      );
    } on Object {
      return (enabled: false, tagIds: const []);
    }
  }

  static List<String> _cleanTags(Iterable<String> values) {
    final seen = <String>{};
    return [
      for (final value in values)
        if (value.trim() case final id when id.isNotEmpty && seen.add(id)) id,
    ];
  }

  /// Flips the alerts, writing the choice through; turning it off keeps the
  /// tag filter for the next time.
  Future<void> setEnabled({required bool value}) async {
    state = (enabled: value, tagIds: state.tagIds);
    try {
      await StoragePrefs.setBool(_enabledKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Replaces the tag filter; an empty list covers every follow.
  Future<void> setTags(List<String> tagIds) async {
    final tags = _cleanTags(tagIds);
    state = (enabled: state.enabled, tagIds: tags);
    try {
      await StoragePrefs.setStringList(_tagsKey, tags);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The live-alert choice.
final liveAlertSettingsProvider = NotifierProvider<LiveAlertSettingsController, LiveAlertSettings>(
  LiveAlertSettingsController.new,
);
