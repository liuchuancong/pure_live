import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// The file naming the recorder will use when the engine arrives: a
/// template with the placeholders the engine will fill in — the date, the
/// time, the platform, the room id and the room title.
const String kDefaultNamingTemplate = '{date}_{title}';

/// The recorder's own tunables, until the engine arrives and grows them.
typedef RecordingSettings = ({String saveDir, String namingTemplate, double maxSizeGb});

/// Owns the recorder settings the pane in `recorder_page.dart` edits.
///
/// The values live here, not in the widgets, so every setter writes the
/// stored key back at once and any later surface (the engine's own) reads
/// the same truth; the initial values come from the stored
/// `recorder.dir`/`recorder.naming`/`recorder.maxSizeGb`, like the
/// browsing settings beside them.
final class RecordingSettingsController extends Notifier<RecordingSettings> {
  @override
  RecordingSettings build() {
    return (
      saveDir: _readStoredString('recorder.dir') ?? '',
      namingTemplate: _readStoredString('recorder.naming') ?? kDefaultNamingTemplate,
      maxSizeGb: _readStoredSize() ?? 4,
    );
  }

  /// The stored string under [key], or null when storage never opened
  /// (its boot failure is logged); the defaults then stay.
  static String? _readStoredString(String key) {
    try {
      return StoragePrefs.getString(key);
    } on Object {
      return null;
    }
  }

  /// The stored size cap, or null when storage never opened.
  static double? _readStoredSize() {
    try {
      return StoragePrefs.getDouble('recorder.maxSizeGb');
    } on Object {
      return null;
    }
  }

  /// Where recordings land; '' means the engine's own default directory.
  String get saveDir => state.saveDir;

  /// The file naming template the engine will fill in.
  String get namingTemplate => state.namingTemplate;

  /// How large one recording file may grow before it is split, in GB.
  double get maxSizeGb => state.maxSizeGb;

  /// Moves the recording directory; the row shows it at once. An empty
  /// path means the engine's own default.
  set saveDir(String dir) {
    state = (saveDir: dir.trim(), namingTemplate: state.namingTemplate, maxSizeGb: state.maxSizeGb);
    unawaited(StoragePrefs.setString('recorder.dir', state.saveDir));
  }

  /// Changes the naming template; a blank one falls back to the default,
  /// so the engine never meets an empty pattern.
  set namingTemplate(String template) {
    final trimmed = template.trim();
    final next = trimmed.isEmpty ? kDefaultNamingTemplate : trimmed;
    state = (saveDir: state.saveDir, namingTemplate: next, maxSizeGb: state.maxSizeGb);
    unawaited(StoragePrefs.setString('recorder.naming', next));
  }

  /// Changes the single-file size cap, in GB.
  set maxSizeGb(double gigabytes) {
    // num.clamp answers num; the setting is a double.
    final clamped = gigabytes.clamp(1, 20).toDouble();
    state = (saveDir: state.saveDir, namingTemplate: state.namingTemplate, maxSizeGb: clamped);
    unawaited(StoragePrefs.setDouble('recorder.maxSizeGb', clamped));
  }
}

/// The recorder settings.
final recordingSettingsProvider = NotifierProvider<RecordingSettingsController, RecordingSettings>(
  RecordingSettingsController.new,
);
