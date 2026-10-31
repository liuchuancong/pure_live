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
    this.recordDanmakuGifts = false,
    this.namingTemplate = kDefaultNamingTemplate,
    this.maxSizeMb = 2048,
    this.segmentSeconds = 1800,
    this.readTimeoutSeconds = 15,
    this.queueSize = 1024,
    this.preferBestStream = true,
    this.keepAlive = true,
    this.verifyOutput = true,
    this.restartLimit = 5,
    this.restartBackoffSeconds = 30,
    this.stallTimeoutSeconds = 30,
    this.diskWatermarkMb = 2048,
    this.maxTasks = 3,
    this.container = RecordingFileContainer.mpegTs,
    this.combineAfterStop = true,
    this.deleteOriginalsAfterCombine = false,
    this.transcodeAfterCombine = false,
    this.transcodeBitrateKbps = 4000,
    this.tlsVerify = true,
    this.customCaPath = '',
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

  /// Whether gift messages join the recorded danmaku beside the chat.
  ///
  /// Off by default: the chat is what a viewer reads back, and a gift feed can
  /// be loud. The reference keeps the same independent switch
  /// (`record_danmaku_gifts`). Only meaningful while [recordDanmaku] is on.
  final bool recordDanmakuGifts;

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

  /// Whether a finished take is joined into one MP4 beside its segments.
  ///
  /// Segments are the crash-safe capture format, not the file a viewer wants
  /// to open: the reference converts TS to MP4 after recording, and this is
  /// that step. A failed join leaves the segments untouched.
  final bool combineAfterStop;

  /// Whether the segments are deleted after a successful join.
  ///
  /// Off keeps them under `original/` inside the take's folder, so a join
  /// that produced a bad file can be retried and nothing is lost.
  final bool deleteOriginalsAfterCombine;

  /// Whether the joined file is re-encoded to a smaller H.264 MP4.
  ///
  /// A recording is captured by stream copy; this is an optional second pass
  /// for the viewer who needs a smaller file. It costs CPU time proportional
  /// to the recording's length and trades source quality for size.
  final bool transcodeAfterCombine;

  /// Target video bitrate for [transcodeAfterCombine], in kbit/s.
  final int transcodeBitrateKbps;

  /// Whether an HTTPS input's certificate is verified.
  ///
  /// On by default. Off accepts a self-signed or proxy-intercepted certificate,
  /// which is the escape hatch for a TLS-terminating proxy; it also removes
  /// the protection against a real interception.
  final bool tlsVerify;

  /// A CA bundle of the viewer's own, in PEM text, that FFmpeg is pointed at
  /// instead of the bundled Mozilla store.
  ///
  /// This is the way to trust a corporate or TLS-intercepting root, or a
  /// self-signed chain, *without* turning verification off. '' means the
  /// bundled bundle. The path is the file the viewer picked; the engine copies
  /// it into its own certificate folder before handing it to FFmpeg, so a
  /// folder the viewer later moves or deletes cannot strand a recording.
  final String customCaPath;

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
    bool? recordDanmakuGifts,
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
    bool? combineAfterStop,
    bool? deleteOriginalsAfterCombine,
    bool? transcodeAfterCombine,
    int? transcodeBitrateKbps,
    bool? tlsVerify,
    String? customCaPath,
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
    recordDanmakuGifts: recordDanmakuGifts ?? this.recordDanmakuGifts,
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
    combineAfterStop: combineAfterStop ?? this.combineAfterStop,
    deleteOriginalsAfterCombine: deleteOriginalsAfterCombine ?? this.deleteOriginalsAfterCombine,
    transcodeAfterCombine: transcodeAfterCombine ?? this.transcodeAfterCombine,
    transcodeBitrateKbps: transcodeBitrateKbps ?? this.transcodeBitrateKbps,
    tlsVerify: tlsVerify ?? this.tlsVerify,
    customCaPath: customCaPath ?? this.customCaPath,
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
    return RecordingSettings(
      defaultQuality: _storedString('recorder.defaultQuality') ?? RecordingSettings.defaults.defaultQuality,
      recordDanmaku: _storedBool('recorder.recordDanmaku') ?? false,
      recordDanmakuGifts: _storedBool('recorder.chatGifts') ?? false,
      namingTemplate: _storedString('recorder.naming') ?? kDefaultNamingTemplate,
      maxSizeMb: _storedSize() ?? RecordingSettings.defaults.maxSizeMb,
      segmentSeconds: (_storedInt('recorder.segment') ?? RecordingSettings.defaults.segmentSeconds).clamp(10, 86400),
      readTimeoutSeconds: (_storedInt('recorder.rwTimeout') ?? 15).clamp(5, 120),
      queueSize: (_storedInt('recorder.queue') ?? RecordingSettings.defaults.queueSize).clamp(256, 32768),
      preferBestStream: _storedBool('recorder.preferBest') ?? true,
      keepAlive: _storedBool('recorder.keepAlive') ?? true,
      verifyOutput: _storedBool('recorder.verify') ?? true,
      restartLimit: (_storedInt('recorder.restartLimit') ?? 5).clamp(0, 20),
      restartBackoffSeconds: (_storedInt('recorder.restartBackoff') ?? 30).clamp(5, 120),
      stallTimeoutSeconds: (_storedInt('recorder.stallTimeout') ?? 30).clamp(10, 600),
      diskWatermarkMb: _storedDiskWatermark() ?? RecordingSettings.defaults.diskWatermarkMb,
      maxTasks: _storedMaxTasks() ?? 3,
      container:
          RecordingFileContainer.values.asNameMap()[_storedString('recorder.container') ?? ''] ??
          RecordingFileContainer.mpegTs,
      combineAfterStop: _storedBool('recorder.combine') ?? true,
      deleteOriginalsAfterCombine: _storedBool('recorder.combineDeleteOriginals') ?? false,
      transcodeAfterCombine: _storedBool('recorder.transcode') ?? false,
      transcodeBitrateKbps: (_storedInt('recorder.transcodeBitrate') ?? 4000).clamp(500, 50000),
      tlsVerify: _storedBool('recorder.tlsVerify') ?? true,
      // A stored empty path is the same answer as nothing stored: the bundled
      // bundle is in force.
      customCaPath: (_storedString('recorder.customCa') ?? '').trim(),
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
      // Zero is the viewer's own answer — no size limit — and must survive
      // a reload as itself, not as the smallest bounded value.
      if (megabytes != null) return megabytes == 0 ? 0 : megabytes.clamp(100, 20480);
      final gigabytes = StoragePrefs.getDouble('recorder.maxSizeGb');
      if (gigabytes != null && gigabytes <= 20) return (gigabytes * 1024).round().clamp(100, 20480);
      return null;
    } on Object {
      return null;
    }
  }

  /// The stored free-space floor, or null when storage never opened. Zero is
  /// the viewer lifting the guard and stays zero; anything else is clamped.
  static int? _storedDiskWatermark() {
    final stored = _storedInt('recorder.diskWatermark');
    if (stored == null) return null;
    return stored == 0 ? 0 : stored.clamp(50, 4096);
  }

  /// The stored concurrency cap, with zero as "no cap".
  static int? _storedMaxTasks() {
    final stored = _storedInt('recorder.maxTasks');
    if (stored == null) return null;
    return stored == 0 ? 0 : stored.clamp(1, 10);
  }

  /// The quality a new recording asks the platform for.
  String get defaultQuality => state.defaultQuality;

  /// Whether a recording saves the room's chat beside its video.
  bool get recordDanmaku => state.recordDanmaku;

  /// Whether gift messages are written beside the chat in the danmaku file.
  bool get recordDanmakuGifts => state.recordDanmakuGifts;

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

  /// Whether a finished take is joined into one MP4.
  bool get combineAfterStop => state.combineAfterStop;

  /// Whether the joined take's segments are deleted afterwards.
  bool get deleteOriginalsAfterCombine => state.deleteOriginalsAfterCombine;

  /// Whether the joined file is re-encoded after the join.
  bool get transcodeAfterCombine => state.transcodeAfterCombine;

  /// Target video bitrate for the post-record transcode, in kbit/s.
  int get transcodeBitrateKbps => state.transcodeBitrateKbps;

  /// Whether an HTTPS input's certificate is verified.
  bool get tlsVerify => state.tlsVerify;

  /// The CA bundle of the viewer's own, or '' when the bundled one is in force.
  String get customCaPath => state.customCaPath;

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

  /// Chooses whether gift messages join the recorded danmaku.
  set recordDanmakuGifts(bool value) {
    state = state.copyWith(recordDanmakuGifts: value);
    unawaited(_write('recorder.chatGifts', value));
  }

  /// Chooses whether recordings save the room's chat as a same-name XML.
  set recordDanmaku(bool value) {
    state = state.copyWith(recordDanmaku: value);
    unawaited(_write('recorder.recordDanmaku', value));
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
    final clamped = megabytes == 0 ? 0 : megabytes.clamp(100, 20480);
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
    final clamped = megabytes == 0 ? 0 : megabytes.clamp(50, 4096);
    state = state.copyWith(diskWatermarkMb: clamped);
    unawaited(_write('recorder.diskWatermark', clamped));
  }

  /// Changes how many recordings may run at once.
  set maxTasks(int count) {
    final clamped = count == 0 ? 0 : count.clamp(1, 10);
    state = state.copyWith(maxTasks: clamped);
    unawaited(_write('recorder.maxTasks', clamped));
  }

  /// Chooses the segment container.
  set container(RecordingFileContainer value) {
    state = state.copyWith(container: value);
    unawaited(_write('recorder.container', value.name));
  }

  /// Chooses whether a finished take is joined into one MP4.
  set combineAfterStop(bool value) {
    state = state.copyWith(combineAfterStop: value);
    unawaited(_write('recorder.combine', value));
  }

  /// Chooses whether the segments are deleted after a successful join.
  set deleteOriginalsAfterCombine(bool value) {
    state = state.copyWith(deleteOriginalsAfterCombine: value);
    unawaited(_write('recorder.combineDeleteOriginals', value));
  }

  /// Chooses whether the joined file is re-encoded.
  set transcodeAfterCombine(bool value) {
    state = state.copyWith(transcodeAfterCombine: value);
    unawaited(_write('recorder.transcode', value));
  }

  /// Changes the post-record transcode's target video bitrate.
  set transcodeBitrateKbps(int value) {
    final next = value.clamp(500, 50000);
    state = state.copyWith(transcodeBitrateKbps: next);
    unawaited(_write('recorder.transcodeBitrate', next));
  }

  /// Chooses whether HTTPS certificates are verified.
  set tlsVerify(bool value) {
    state = state.copyWith(tlsVerify: value);
    unawaited(_write('recorder.tlsVerify', value));
  }

  /// Points the recorder at the viewer's own CA bundle; a blank path falls back
  /// to the bundled Mozilla store. The engine re-reads this per start, so a new
  /// choice takes effect on the next take without a restart.
  set customCaPath(String path) {
    final value = path.trim();
    state = state.copyWith(customCaPath: value);
    unawaited(_write('recorder.customCa', value));
  }

  /// Puts every recording tunable back to the designed defaults.
  ///
  /// The save folder, the danmaku save formats and a chosen CA file are
  /// deliberately not reset: the folder belongs to the storage page, the
  /// formats to the danmaku page, and a certificate bundle is a file the viewer
  /// picked once and cannot easily re-pick. Undoing a recording setting must
  /// not take any of those away.
  Future<void> reset() async {
    const d = RecordingSettings.defaults;
    // The chosen CA bundle is not a tunable and is not reset: carry it over the
    // default copy, or the state would say "bundled store" while the pref still
    // holds the viewer's file — and the next launch would bring it back.
    state = d.copyWith(customCaPath: state.customCaPath);
    await Future.wait([
      _write('recorder.defaultQuality', d.defaultQuality),
      _write('recorder.recordDanmaku', d.recordDanmaku),
      _write('recorder.chatGifts', d.recordDanmakuGifts),
      _write('recorder.naming', d.namingTemplate),
      _write('recorder.maxSizeMb', d.maxSizeMb),
      _write('recorder.segment', d.segmentSeconds),
      _write('recorder.rwTimeout', d.readTimeoutSeconds),
      _write('recorder.queue', d.queueSize),
      _write('recorder.preferBest', d.preferBestStream),
      _write('recorder.keepAlive', d.keepAlive),
      _write('recorder.verify', d.verifyOutput),
      _write('recorder.restartLimit', d.restartLimit),
      _write('recorder.restartBackoff', d.restartBackoffSeconds),
      _write('recorder.stallTimeout', d.stallTimeoutSeconds),
      _write('recorder.diskWatermark', d.diskWatermarkMb),
      _write('recorder.maxTasks', d.maxTasks),
      _write('recorder.container', d.container.name),
      _write('recorder.combine', d.combineAfterStop),
      _write('recorder.combineDeleteOriginals', d.deleteOriginalsAfterCombine),
      _write('recorder.transcode', d.transcodeAfterCombine),
      _write('recorder.transcodeBitrate', d.transcodeBitrateKbps),
      _write('recorder.tlsVerify', d.tlsVerify),
      _write('recorder.cacheLimitEnabled', d.cacheLimitEnabled),
      _write('recorder.cacheLimitMb', d.cacheLimitMb),
      _write('recorder.pollingEnabled', d.pollingEnabled),
      _write('recorder.liveCheckSeconds', d.liveCheckSeconds),
      _write('recorder.checkBackoffEnabled', d.checkBackoffEnabled),
      _write('recorder.maxCheckSeconds', d.maxCheckSeconds),
      _write('recorder.autoStartOnBoot', d.autoStartOnBoot),
    ]);
  }
}

/// The recorder settings.
final recordingSettingsProvider = NotifierProvider<RecordingSettingsController, RecordingSettings>(
  RecordingSettingsController.new,
);
