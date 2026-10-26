import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// The file naming the recorder will use: a template with the placeholders
/// the engine fills in — the date, the time, the platform, the room id and
/// the room title.
const String kDefaultNamingTemplate = '{date}_{title}';

/// The smallest recording-cache cap: the reference's one megabyte.
const int kRecordingCacheLimitMinMb = 1;

/// A generous ceiling for the cap (1 TB), so a malformed backup cannot ask
/// the trim walk for an unbounded directory.
const int kRecordingCacheLimitMaxMb = 1024 * 1024;

/// The container each recording segment is written into.
enum RecordingFileContainer {
  /// Segmented MPEG-TS: every segment stands alone and joining them is a
  /// byte copy; the most forgiving container for a live capture.
  mpegTs,

  /// Fragmented MP4: ordinary players open it, at the cost of a remux when
  /// segments join.
  mp4,
}

/// The recorder's own tunables, consumed by `recorder_engine.dart`.
///
/// Every field maps to an FFmpeg argument or the engine's own session
/// policy; nothing here is a note without an effect.
final class RecordingSettings {
  /// Creates a settings set; the fields default to the engine's own
  /// choices.
  const RecordingSettings({
    this.defaultQuality = '原画',
    this.recordDanmaku = false,
    this.saveDir = '',
    this.namingTemplate = kDefaultNamingTemplate,
    this.maxSizeMb = 2048,
    this.segmentSeconds = 300,
    this.readTimeoutSeconds = 15,
    this.queueSize = 2048,
    this.preferBestStream = true,
    this.keepAlive = true,
    this.verifyOutput = true,
    this.restartLimit = 5,
    this.restartBackoffSeconds = 30,
    this.stallTimeoutSeconds = 30,
    this.diskWatermarkMb = 200,
    this.maxTasks = 3,
    this.container = RecordingFileContainer.mpegTs,
    this.cacheLimitEnabled = false,
    this.cacheLimitMb = 1024,
    this.pollingEnabled = false,
    this.liveCheckSeconds = 30,
    this.checkBackoffEnabled = false,
    this.maxCheckSeconds = 300,
    this.autoStartOnBoot = false,
  });

  /// The designed defaults.
  static const RecordingSettings defaults = RecordingSettings();

  /// The quality a new recording asks the platform for; the room falls back
  /// to its current line when the platform does not offer it. The reference's
  /// default is the first resolution.
  final String defaultQuality;

  /// Whether the live chat is saved beside the video as a same-name XML
  /// (the reference's "record chat" switch).
  final bool recordDanmaku;

  /// Where recordings land; '' means the engine's own default directory.
  final String saveDir;

  /// The file naming template the engine fills in.
  final String namingTemplate;

  /// How large one recording may grow before it is ended, in megabytes.
  final int maxSizeMb;

  /// Length of one segment, in seconds.
  final int segmentSeconds;

  /// How long FFmpeg waits for input before failing the read, in seconds.
  final int readTimeoutSeconds;

  /// Input packet queue size.
  final int queueSize;

  /// Whether only the first video and audio stream are mapped.
  final bool preferBestStream;

  /// Whether a recording holds a background session and a wake lock.
  final bool keepAlive;

  /// Whether the output is verified when the session ends.
  final bool verifyOutput;

  /// How many times a broken stream is reopened; 0 disables retries.
  final int restartLimit;

  /// The pause before a restart, in seconds.
  final int restartBackoffSeconds;

  /// How long without new data counts as a stalled stream, in seconds.
  final int stallTimeoutSeconds;

  /// Free space below which a recording stops, in megabytes.
  final int diskWatermarkMb;

  /// How many recordings may run at once.
  final int maxTasks;

  /// The segment container.
  final RecordingFileContainer container;

  /// Whether completed takes are trimmed to [cacheLimitMb].
  final bool cacheLimitEnabled;

  /// The managed recording folder's cap, in megabytes.
  final int cacheLimitMb;

  /// Whether waiting tasks check their rooms for a live stream and start
  /// recording when one begins.
  final bool pollingEnabled;

  /// Seconds between two checks of one waiting task.
  final int liveCheckSeconds;

  /// Whether repeated failures stretch the check interval.
  final bool checkBackoffEnabled;

  /// The ceiling the stretched interval approaches, in seconds.
  final int maxCheckSeconds;

  /// Whether interrupted (still recording) tasks return as waiting on boot.
  final bool autoStartOnBoot;

  /// A copy with the named fields replaced.
  RecordingSettings copyWith({
    String? defaultQuality,
    bool? recordDanmaku,
    String? saveDir,
    String? namingTemplate,
    int? maxSizeMb,
    int? segmentSeconds,
    int? readTimeoutSeconds,
    int? queueSize,
    bool? preferBestStream,
    bool? keepAlive,
    bool? verifyOutput,
    int? restartLimit,
    int? restartBackoffSeconds,
    int? stallTimeoutSeconds,
    int? diskWatermarkMb,
    int? maxTasks,
    RecordingFileContainer? container,
    bool? cacheLimitEnabled,
    int? cacheLimitMb,
    bool? pollingEnabled,
    int? liveCheckSeconds,
    bool? checkBackoffEnabled,
    int? maxCheckSeconds,
    bool? autoStartOnBoot,
  }) => RecordingSettings(
    defaultQuality: defaultQuality ?? this.defaultQuality,
    recordDanmaku: recordDanmaku ?? this.recordDanmaku,
    saveDir: saveDir ?? this.saveDir,
    namingTemplate: namingTemplate ?? this.namingTemplate,
    maxSizeMb: maxSizeMb ?? this.maxSizeMb,
    segmentSeconds: segmentSeconds ?? this.segmentSeconds,
    readTimeoutSeconds: readTimeoutSeconds ?? this.readTimeoutSeconds,
    queueSize: queueSize ?? this.queueSize,
    preferBestStream: preferBestStream ?? this.preferBestStream,
    keepAlive: keepAlive ?? this.keepAlive,
    verifyOutput: verifyOutput ?? this.verifyOutput,
    restartLimit: restartLimit ?? this.restartLimit,
    restartBackoffSeconds: restartBackoffSeconds ?? this.restartBackoffSeconds,
    stallTimeoutSeconds: stallTimeoutSeconds ?? this.stallTimeoutSeconds,
    diskWatermarkMb: diskWatermarkMb ?? this.diskWatermarkMb,
    maxTasks: maxTasks ?? this.maxTasks,
    container: container ?? this.container,
    cacheLimitEnabled: cacheLimitEnabled ?? this.cacheLimitEnabled,
    cacheLimitMb: cacheLimitMb ?? this.cacheLimitMb,
    pollingEnabled: pollingEnabled ?? this.pollingEnabled,
    liveCheckSeconds: liveCheckSeconds ?? this.liveCheckSeconds,
    checkBackoffEnabled: checkBackoffEnabled ?? this.checkBackoffEnabled,
    maxCheckSeconds: maxCheckSeconds ?? this.maxCheckSeconds,
    autoStartOnBoot: autoStartOnBoot ?? this.autoStartOnBoot,
  );
}

/// Owns the recorder settings the pane in `recorder_page.dart` edits.
///
/// The values live here, not in the widgets, so every setter writes the
/// stored key back at once and any later surface (the engine's own) reads
/// the same truth.
final class RecordingSettingsController extends Notifier<RecordingSettings> {
  @override
  RecordingSettings build() {
    final saved = _storedString('recorder.saveDir') ?? _storedString('recorder.dir') ?? '';
    return RecordingSettings(
      defaultQuality: _storedString('recorder.defaultQuality') ?? RecordingSettings.defaults.defaultQuality,
      recordDanmaku: _storedBool('recorder.recordDanmaku') ?? false,
      saveDir: saved,
      namingTemplate: _storedString('recorder.naming') ?? kDefaultNamingTemplate,
      maxSizeMb: _storedSize() ?? RecordingSettings.defaults.maxSizeMb,
      segmentSeconds: (_storedInt('recorder.segment') ?? 300).clamp(10, 86400),
      readTimeoutSeconds: (_storedInt('recorder.rwTimeout') ?? 15).clamp(5, 120),
      queueSize: (_storedInt('recorder.queue') ?? 2048).clamp(256, 32768),
      preferBestStream: _storedBool('recorder.preferBest') ?? true,
      keepAlive: _storedBool('recorder.keepAlive') ?? true,
      verifyOutput: _storedBool('recorder.verify') ?? true,
      restartLimit: (_storedInt('recorder.restartLimit') ?? 5).clamp(0, 20),
      restartBackoffSeconds: (_storedInt('recorder.restartBackoff') ?? 30).clamp(5, 120),
      stallTimeoutSeconds: (_storedInt('recorder.stallTimeout') ?? 30).clamp(10, 600),
      diskWatermarkMb: (_storedInt('recorder.diskWatermark') ?? 200).clamp(50, 4096),
      maxTasks: (_storedInt('recorder.maxTasks') ?? 3).clamp(1, 10),
      container:
          RecordingFileContainer.values.asNameMap()[_storedString('recorder.container') ?? ''] ??
          RecordingFileContainer.mpegTs,
      cacheLimitEnabled: _storedBool('recorder.cacheLimitEnabled') ?? false,
      cacheLimitMb: (_storedInt('recorder.cacheLimitMb') ?? 1024).clamp(
        kRecordingCacheLimitMinMb,
        kRecordingCacheLimitMaxMb,
      ),
      pollingEnabled: _storedBool('recorder.pollingEnabled') ?? false,
      liveCheckSeconds: (_storedInt('recorder.liveCheckSeconds') ?? 30).clamp(10, 300),
      checkBackoffEnabled: _storedBool('recorder.checkBackoffEnabled') ?? false,
      maxCheckSeconds: (_storedInt('recorder.maxCheckSeconds') ?? 300).clamp(60, 3600),
      autoStartOnBoot: _storedBool('recorder.autoStartOnBoot') ?? false,
    );
  }

  static String? _storedString(String key) {
    try {
      return StoragePrefs.getString(key);
    } on Object {
      return null;
    }
  }

  static int? _storedInt(String key) {
    try {
      return StoragePrefs.getInt(key);
    } on Object {
      return null;
    }
  }

  static bool? _storedBool(String key) {
    try {
      return StoragePrefs.getBool(key);
    } on Object {
      return null;
    }
  }

  /// The stored size cap, or null when storage never opened. The old key
  /// counted gigabytes as a double; a stored figure at or below 20 is read
  /// as gigabytes once, so an upgraded setting keeps its meaning.
  static int? _storedSize() {
    try {
      final megabytes = _storedInt('recorder.maxSizeMb');
      if (megabytes != null) return megabytes.clamp(100, 20480);
      final gigabytes = StoragePrefs.getDouble('recorder.maxSizeGb');
      if (gigabytes != null && gigabytes <= 20) return (gigabytes * 1024).round().clamp(100, 20480);
      return null;
    } on Object {
      return null;
    }
  }

  /// Where recordings land; '' means the engine's own default directory.
  String get saveDir => state.saveDir;

  /// The quality a new recording asks the platform for.
  String get defaultQuality => state.defaultQuality;

  /// Whether a recording saves the room's chat beside its video.
  bool get recordDanmaku => state.recordDanmaku;

  /// The file naming template the engine will fill in.
  String get namingTemplate => state.namingTemplate;

  /// How large one recording may grow before the engine ends the take,
  /// in megabytes.
  int get maxSizeMb => state.maxSizeMb;

  /// One segment's length, in seconds.
  int get segmentSeconds => state.segmentSeconds;

  /// The input read timeout, in seconds.
  int get readTimeoutSeconds => state.readTimeoutSeconds;

  /// The input packet queue size.
  int get queueSize => state.queueSize;

  /// Whether only the first video and audio streams are recorded.
  bool get preferBestStream => state.preferBestStream;

  /// Whether a recording keeps a background session alive.
  bool get keepAlive => state.keepAlive;

  /// Whether the output is verified on stop.
  bool get verifyOutput => state.verifyOutput;

  /// How often a broken stream is reopened.
  int get restartLimit => state.restartLimit;

  /// The pause before a restart, in seconds.
  int get restartBackoffSeconds => state.restartBackoffSeconds;

  /// How long silence counts as a stalled stream, in seconds.
  int get stallTimeoutSeconds => state.stallTimeoutSeconds;

  /// The free-space floor a recording stops at, in megabytes.
  int get diskWatermarkMb => state.diskWatermarkMb;

  /// How many recordings may run at once.
  int get maxTasks => state.maxTasks;

  /// The segment container.
  RecordingFileContainer get container => state.container;

  /// Whether completed takes are trimmed to the cap.
  bool get cacheLimitEnabled => state.cacheLimitEnabled;

  /// The managed folder's cap, in megabytes.
  int get cacheLimitMb => state.cacheLimitMb;

  /// Whether waiting tasks are checked for a live stream.
  bool get pollingEnabled => state.pollingEnabled;

  int get liveCheckSeconds => state.liveCheckSeconds;

  bool get checkBackoffEnabled => state.checkBackoffEnabled;

  int get maxCheckSeconds => state.maxCheckSeconds;

  bool get autoStartOnBoot => state.autoStartOnBoot;

  set cacheLimitEnabled(bool value) {
    state = state.copyWith(cacheLimitEnabled: value);
    unawaited(_write('recorder.cacheLimitEnabled', value));
  }

  set cacheLimitMb(int value) {
    final next = value.clamp(kRecordingCacheLimitMinMb, kRecordingCacheLimitMaxMb);
    state = state.copyWith(cacheLimitMb: next);
    unawaited(_write('recorder.cacheLimitMb', next));
  }

  /// Turns the live check of waiting tasks on or off.
  set pollingEnabled(bool value) {
    state = state.copyWith(pollingEnabled: value);
    unawaited(_write('recorder.pollingEnabled', value));
  }

  set liveCheckSeconds(int value) {
    final next = value.clamp(10, 300);
    state = state.copyWith(liveCheckSeconds: next);
    unawaited(_write('recorder.liveCheckSeconds', next));
  }

  set checkBackoffEnabled(bool value) {
    state = state.copyWith(checkBackoffEnabled: value);
    unawaited(_write('recorder.checkBackoffEnabled', value));
  }

  set maxCheckSeconds(int value) {
    final next = value.clamp(60, 3600);
    state = state.copyWith(maxCheckSeconds: next);
    unawaited(_write('recorder.maxCheckSeconds', next));
  }

  set autoStartOnBoot(bool value) {
    state = state.copyWith(autoStartOnBoot: value);
    unawaited(_write('recorder.autoStartOnBoot', value));
  }

  Future<void> _write(String key, Object value) async {
    try {
      if (value is String) await StoragePrefs.setString(key, value);
      if (value is int) await StoragePrefs.setInt(key, value);
      if (value is bool) await StoragePrefs.setBool(key, value);
    } on Object {
      // The recorder settings are preferences; a closed store loses them.
    }
  }

  /// Moves the recording quality; a blank value falls back to the first
  /// resolution.
  set defaultQuality(String quality) {
    final value = quality.trim().isEmpty ? RecordingSettings.defaults.defaultQuality : quality.trim();
    state = state.copyWith(defaultQuality: value);
    unawaited(_write('recorder.defaultQuality', value));
  }

  /// Chooses whether recordings save the room's chat as a same-name XML.
  set recordDanmaku(bool value) {
    state = state.copyWith(recordDanmaku: value);
    unawaited(_write('recorder.recordDanmaku', value));
  }

  /// Moves the recording directory; an empty path means the engine's own
  /// default.
  set saveDir(String dir) {
    final value = dir.trim();
    state = state.copyWith(saveDir: value);
    unawaited(_write('recorder.dir', value));
  }

  /// Changes the naming template; a blank one falls back to the default,
  /// so the engine never meets an empty pattern.
  set namingTemplate(String template) {
    final trimmed = template.trim();
    final next = trimmed.isEmpty ? kDefaultNamingTemplate : trimmed;
    state = state.copyWith(namingTemplate: next);
    unawaited(_write('recorder.naming', next));
  }

  /// Changes the recording size cap, in megabytes.
  set maxSizeMb(int megabytes) {
    final clamped = megabytes.clamp(100, 20480);
    state = state.copyWith(maxSizeMb: clamped);
    unawaited(_write('recorder.maxSizeMb', clamped));
  }

  /// Changes one segment's length.
  set segmentSeconds(int seconds) {
    final clamped = seconds.clamp(10, 86400);
    state = state.copyWith(segmentSeconds: clamped);
    unawaited(_write('recorder.segment', clamped));
  }

  /// Changes the input read timeout.
  set readTimeoutSeconds(int seconds) {
    final clamped = seconds.clamp(5, 120);
    state = state.copyWith(readTimeoutSeconds: clamped);
    unawaited(_write('recorder.rwTimeout', clamped));
  }

  /// Changes the input queue size.
  set queueSize(int size) {
    final clamped = size.clamp(256, 32768);
    state = state.copyWith(queueSize: clamped);
    unawaited(_write('recorder.queue', clamped));
  }

  /// Chooses whether only the first video and audio stream are recorded.
  set preferBestStream(bool value) {
    state = state.copyWith(preferBestStream: value);
    unawaited(_write('recorder.preferBest', value));
  }

  /// Chooses whether a recording keeps a background session alive.
  set keepAlive(bool value) {
    state = state.copyWith(keepAlive: value);
    unawaited(_write('recorder.keepAlive', value));
  }

  /// Chooses whether the output is verified on stop.
  set verifyOutput(bool value) {
    state = state.copyWith(verifyOutput: value);
    unawaited(_write('recorder.verify', value));
  }

  /// Changes how often a broken stream is reopened.
  set restartLimit(int count) {
    final clamped = count.clamp(0, 20);
    state = state.copyWith(restartLimit: clamped);
    unawaited(_write('recorder.restartLimit', clamped));
  }

  /// Changes the pause before a restart.
  set restartBackoffSeconds(int seconds) {
    final clamped = seconds.clamp(1, 120);
    state = state.copyWith(restartBackoffSeconds: clamped);
    unawaited(_write('recorder.restartBackoff', clamped));
  }

  /// Changes how long silence counts as a stalled stream.
  set stallTimeoutSeconds(int seconds) {
    final clamped = seconds.clamp(10, 600);
    state = state.copyWith(stallTimeoutSeconds: clamped);
    unawaited(_write('recorder.stallTimeout', clamped));
  }

  /// Changes the free-space floor a recording stops at.
  set diskWatermarkMb(int megabytes) {
    final clamped = megabytes.clamp(50, 4096);
    state = state.copyWith(diskWatermarkMb: clamped);
    unawaited(_write('recorder.diskWatermark', clamped));
  }

  /// Changes how many recordings may run at once.
  set maxTasks(int count) {
    final clamped = count.clamp(1, 10);
    state = state.copyWith(maxTasks: clamped);
    unawaited(_write('recorder.maxTasks', clamped));
  }

  /// Chooses the segment container.
  set container(RecordingFileContainer value) {
    state = state.copyWith(container: value);
    unawaited(_write('recorder.container', value.name));
  }
}

/// The recorder settings.
final recordingSettingsProvider = NotifierProvider<RecordingSettingsController, RecordingSettings>(
  RecordingSettingsController.new,
);
