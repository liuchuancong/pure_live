// ignore_for_file: unnecessary_type_name_in_constructor -- the fromJson
// factories cannot use the `new` shorthand.
import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:live_storage/live_storage.dart' show StorageRepository;

/// Where the recorder's preference document is persisted.
///
/// One document per preference group in the shared `settings.preferences`
/// box, versioned in its key — the same discipline the IPTV and multi-view
/// documents follow, so a reshaped recorder document resets only the
/// recorder's own choices.
abstract final class RecorderKeys {
  /// The box every preference group document lives in (`settings.preferences`).
  static const String box = 'settings.preferences';

  /// The recorder group key.
  static const String document = 'preferences.recorder.v1';

  /// The box the recording task ledger's JSON documents live in — one slot
  /// per task, keyed by task id (the `live_record_core` `RecordJsonStore`
  /// shape).
  static const String tasksBox = 'recorder.tasks';
}

/// The five quality preferences of the recording settings, best first — the
/// reference's `recordQualityPreferences` (3.x `PlayerConsts.resolutions`);
/// the stored values are these names.
const List<String> recordQualityChoices = ['原画', '蓝光8M', '蓝光4M', '超清', '流畅'];

/// The recorder's own choices, as persisted: where recordings land, how long
/// one segment runs, and every rule the recording engine decides by.
///
/// Everything here is read by the recording engine adapter as it works: the
/// output directory becomes the `RecordNaming` root, the segment length the
/// FFmpeg capture's `segmentTime`, the retry/poll/backoff answers the
/// orchestrator's live `RecordPolicy`, the FFmpeg trio the capture's config,
/// the quality preference the line a capture is opened on, the danmaku pair
/// the chat file written beside each recording, and the cache pair the folder
/// cleaner. Out-of-range values are normalized on construction, the
/// reference's own discipline.
@immutable
final class RecorderPreferences {
  /// The shipping defaults: the app's own recordings tree, five-minute
  /// segments, the reference's answers for the rest.
  new({
    this.outputDirectory = '',
    int segmentMinutes = 5,
    int maxTaskCount = 3,
    this.autoReconnect = true,
    int maxRetryCount = 5,
    int retryDelaySeconds = 30,
    this.enablePolling = false,
    int liveCheckInterval = 30,
    this.enableBackoff = false,
    int maxCheckInterval = 300,
    this.autoStartOnBoot = false,
    this.preferBestStream = true,
    int rwTimeout = 15,
    int threadQueueSize = 2048,
    String defaultQuality = '原画',
    this.pinyinFolders = false,
    this.recordDanmaku = false,
    this.recordDanmakuGifts = false,
    this.enableCacheLimit = false,
    int maxCacheMB = 1024,
  }) : segmentMinutes = segmentMinutes.clamp(1, 60),
       maxTaskCount = maxTaskCount.clamp(1, 10),
       maxRetryCount = maxRetryCount.clamp(1, 20),
       retryDelaySeconds = retryDelaySeconds.clamp(5, 120),
       liveCheckInterval = liveCheckInterval.clamp(10, 300),
       maxCheckInterval = maxCheckInterval.clamp(300, 3600),
       rwTimeout = supportedRwTimeouts.contains(rwTimeout) ? rwTimeout : 15,
       threadQueueSize = supportedThreadQueueSizes.contains(threadQueueSize) ? threadQueueSize : 2048,
       defaultQuality = recordQualityChoices.contains(defaultQuality) ? defaultQuality : recordQualityChoices.first,
       maxCacheMB = maxCacheMB < 1 ? 1 : maxCacheMB;

  /// Reads the document; unknown shapes decode to the defaults.
  factory RecorderPreferences.fromJson(Map<String, Object?> json) => RecorderPreferences(
    outputDirectory: json['outputDirectory'] as String? ?? '',
    segmentMinutes: (json['segmentMinutes'] as num?)?.toInt() ?? 5,
    maxTaskCount: (json['maxTaskCount'] as num?)?.toInt() ?? 3,
    autoReconnect: json['autoReconnect'] as bool? ?? true,
    maxRetryCount: (json['maxRetryCount'] as num?)?.toInt() ?? 5,
    retryDelaySeconds: (json['retryDelaySeconds'] as num?)?.toInt() ?? 30,
    enablePolling: json['enablePolling'] as bool? ?? false,
    liveCheckInterval: (json['liveCheckInterval'] as num?)?.toInt() ?? 30,
    enableBackoff: json['enableBackoff'] as bool? ?? false,
    maxCheckInterval: (json['maxCheckInterval'] as num?)?.toInt() ?? 300,
    autoStartOnBoot: json['autoStartOnBoot'] as bool? ?? false,
    preferBestStream: json['preferBestStream'] as bool? ?? true,
    rwTimeout: (json['rwTimeout'] as num?)?.toInt() ?? 15,
    threadQueueSize: (json['threadQueueSize'] as num?)?.toInt() ?? 2048,
    defaultQuality: json['defaultQuality'] as String? ?? '原画',
    pinyinFolders: json['pinyinFolders'] as bool? ?? false,
    recordDanmaku: json['recordDanmaku'] as bool? ?? false,
    recordDanmakuGifts: json['recordDanmakuGifts'] as bool? ?? false,
    enableCacheLimit: json['enableCacheLimit'] as bool? ?? false,
    maxCacheMB: (json['maxCacheMB'] as num?)?.toInt() ?? 1024,
  );

  /// Choices of [rwTimeout], seconds — the reference's supported set.
  static const List<int> supportedRwTimeouts = [15, 30, 60];

  /// Choices of [threadQueueSize] — the reference's supported set.
  static const List<int> supportedThreadQueueSizes = [512, 1024, 2048, 4096, 8192];

  /// The directory recordings are written under; empty means the app's own
  /// `AppDirectory.recordings` tree.
  final String outputDirectory;

  /// How much media one capture segment holds, in minutes. The engine clamps
  /// the value into its own working range.
  final int segmentMinutes;

  /// How many rooms may be recording at once (1..10).
  final int maxTaskCount;

  /// Whether an interrupted capture is retried; off ends the attempt at once.
  final bool autoReconnect;

  /// Failed captures in a row before the task gives up on the session (1..20).
  final int maxRetryCount;

  /// The wait after a capture died while the room was still live, seconds.
  final int retryDelaySeconds;

  /// Whether rooms that have never gone live are re-checked for their first
  /// broadcast (the reference's 开播检测, off by default).
  final bool enablePolling;

  /// The ordinary wait between those checks, seconds (10..300).
  final int liveCheckInterval;

  /// Whether the wait doubles after each offline answer (递增检测间隔).
  final bool enableBackoff;

  /// The ceiling of the doubled wait, seconds (300..3600).
  final int maxCheckInterval;

  /// Whether waiting and interrupted tasks resume when the app starts.
  final bool autoStartOnBoot;

  /// Whether the capture maps only the first video and audio stream
  /// (`-map 0:v:0?`) rather than every stream in the container.
  final bool preferBestStream;

  /// FFmpeg's read/write timeout for the input, seconds (15, 30 or 60).
  final int rwTimeout;

  /// FFmpeg's input packet queue size (512 to 8192).
  final int threadQueueSize;

  /// The recording quality preference, best first; the line a capture opens
  /// on is chosen against it when the platform names its lines.
  final String defaultQuality;

  /// Whether the anchor's directory component is pinyin (`zhubo8891`) or the
  /// plain room id. Both are ASCII — FFmpeg only ever opens ASCII paths.
  final bool pinyinFolders;

  /// Whether the room's chat is saved beside each recording.
  final bool recordDanmaku;

  /// Whether the saved chat also carries gifts and super chats (H01.8); acts
  /// only while [recordDanmaku] saves the chat.
  final bool recordDanmakuGifts;

  /// Whether recordings above [maxCacheMB] in the managed folder are pruned.
  final bool enableCacheLimit;

  /// The size cap of the recording folder, MiB.
  final int maxCacheMB;

  /// The segment length as the engine reads it, clamped to 1..60 minutes —
  /// a shorter segment multiplies container overhead, a longer one turns a
  /// crash into minutes of unclosed media.
  int get clampedSegmentMinutes => segmentMinutes.clamp(1, 60);

  /// Writes the document.
  Map<String, Object?> toJson() => {
    'outputDirectory': outputDirectory,
    'segmentMinutes': segmentMinutes,
    'maxTaskCount': maxTaskCount,
    'autoReconnect': autoReconnect,
    'maxRetryCount': maxRetryCount,
    'retryDelaySeconds': retryDelaySeconds,
    'enablePolling': enablePolling,
    'liveCheckInterval': liveCheckInterval,
    'enableBackoff': enableBackoff,
    'maxCheckInterval': maxCheckInterval,
    'autoStartOnBoot': autoStartOnBoot,
    'preferBestStream': preferBestStream,
    'rwTimeout': rwTimeout,
    'threadQueueSize': threadQueueSize,
    'defaultQuality': defaultQuality,
    'pinyinFolders': pinyinFolders,
    'recordDanmaku': recordDanmaku,
    'recordDanmakuGifts': recordDanmakuGifts,
    'enableCacheLimit': enableCacheLimit,
    'maxCacheMB': maxCacheMB,
  };

  /// Returns a copy with the given fields replaced.
  RecorderPreferences copyWith({
    String? outputDirectory,
    int? segmentMinutes,
    int? maxTaskCount,
    bool? autoReconnect,
    int? maxRetryCount,
    int? retryDelaySeconds,
    bool? enablePolling,
    int? liveCheckInterval,
    bool? enableBackoff,
    int? maxCheckInterval,
    bool? autoStartOnBoot,
    bool? preferBestStream,
    int? rwTimeout,
    int? threadQueueSize,
    String? defaultQuality,
    bool? pinyinFolders,
    bool? recordDanmaku,
    bool? recordDanmakuGifts,
    bool? enableCacheLimit,
    int? maxCacheMB,
  }) => RecorderPreferences(
    outputDirectory: outputDirectory ?? this.outputDirectory,
    segmentMinutes: segmentMinutes ?? this.segmentMinutes,
    maxTaskCount: maxTaskCount ?? this.maxTaskCount,
    autoReconnect: autoReconnect ?? this.autoReconnect,
    maxRetryCount: maxRetryCount ?? this.maxRetryCount,
    retryDelaySeconds: retryDelaySeconds ?? this.retryDelaySeconds,
    enablePolling: enablePolling ?? this.enablePolling,
    liveCheckInterval: liveCheckInterval ?? this.liveCheckInterval,
    enableBackoff: enableBackoff ?? this.enableBackoff,
    maxCheckInterval: maxCheckInterval ?? this.maxCheckInterval,
    autoStartOnBoot: autoStartOnBoot ?? this.autoStartOnBoot,
    preferBestStream: preferBestStream ?? this.preferBestStream,
    rwTimeout: rwTimeout ?? this.rwTimeout,
    threadQueueSize: threadQueueSize ?? this.threadQueueSize,
    defaultQuality: defaultQuality ?? this.defaultQuality,
    pinyinFolders: pinyinFolders ?? this.pinyinFolders,
    recordDanmaku: recordDanmaku ?? this.recordDanmaku,
    recordDanmakuGifts: recordDanmakuGifts ?? this.recordDanmakuGifts,
    enableCacheLimit: enableCacheLimit ?? this.enableCacheLimit,
    maxCacheMB: maxCacheMB ?? this.maxCacheMB,
  );

  @override
  bool operator ==(Object other) =>
      other is RecorderPreferences &&
      other.outputDirectory == outputDirectory &&
      other.segmentMinutes == segmentMinutes &&
      other.maxTaskCount == maxTaskCount &&
      other.autoReconnect == autoReconnect &&
      other.maxRetryCount == maxRetryCount &&
      other.retryDelaySeconds == retryDelaySeconds &&
      other.enablePolling == enablePolling &&
      other.liveCheckInterval == liveCheckInterval &&
      other.enableBackoff == enableBackoff &&
      other.maxCheckInterval == maxCheckInterval &&
      other.autoStartOnBoot == autoStartOnBoot &&
      other.preferBestStream == preferBestStream &&
      other.rwTimeout == rwTimeout &&
      other.threadQueueSize == threadQueueSize &&
      other.defaultQuality == defaultQuality &&
      other.pinyinFolders == pinyinFolders &&
      other.recordDanmaku == recordDanmaku &&
      other.recordDanmakuGifts == recordDanmakuGifts &&
      other.enableCacheLimit == enableCacheLimit &&
      other.maxCacheMB == maxCacheMB;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    outputDirectory,
    segmentMinutes,
    maxTaskCount,
    autoReconnect,
    maxRetryCount,
    retryDelaySeconds,
    enablePolling,
    liveCheckInterval,
    enableBackoff,
    maxCheckInterval,
    autoStartOnBoot,
    preferBestStream,
    rwTimeout,
    threadQueueSize,
    defaultQuality,
    pinyinFolders,
    recordDanmaku,
    recordDanmakuGifts,
    enableCacheLimit,
    maxCacheMB,
  ]);
}

/// What a [RecorderPreferencesStore.load] or write found wrong.
///
/// The same shape as the IPTV store's failures: a broken document keeps its
/// defaults and the fact is reported, never thrown.
enum RecorderPreferencesFailure {
  /// The box read threw.
  read,

  /// A document was stored but is not a JSON object.
  shape,

  /// A JSON object was stored but did not decode.
  decode,

  /// A document was built but could not be written.
  write,
}

/// The recorder's persisted choices: one in-memory [RecorderPreferences],
/// one JSON document through a storage repository.
///
/// Reads are synchronous so the engine adapter can consult the values as it
/// builds a capture; writes are immediate (a settings change happens a few
/// times per session) — the same shape the IPTV store uses.
final class RecorderPreferencesStore {
  /// A store persisting through [repository].
  new({required this.repository, this.onError});

  /// The repository the document is persisted in.
  final StorageRepository<Map<dynamic, dynamic>> repository;

  /// Reports every failed read or write; null swallows them.
  final void Function(RecorderPreferencesFailure failure, Object error, StackTrace stack)? onError;
  final StreamController<RecorderPreferences> _controller = StreamController<RecorderPreferences>.broadcast();

  RecorderPreferences _value = RecorderPreferences();
  bool _disposed = false;

  /// The current choices: the shipping defaults until [load] runs.
  RecorderPreferences get value => _value;

  /// Emits on every applied change, including [load].
  Stream<RecorderPreferences> get changes => _controller.stream;

  /// Reads the stored document, applying it when it decodes.
  Future<RecorderPreferences> load() async {
    _checkNotDisposed();
    final Map<dynamic, dynamic>? raw;
    try {
      raw = repository.get(RecorderKeys.document);
    } on Object catch (error, stack) {
      _report(RecorderPreferencesFailure.read, error, stack);
      return _value;
    }
    if (raw == null) {
      return _value;
    }
    final RecorderPreferences loaded;
    try {
      loaded = RecorderPreferences.fromJson(Map<String, Object?>.from(raw));
    } on Object catch (error, stack) {
      _report(RecorderPreferencesFailure.decode, error, stack);
      return _value;
    }
    if (loaded != _value) {
      _value = loaded;
      _emit();
    }
    return _value;
  }

  /// Applies [transform] to the choices and persists the result. The
  /// returned future completes once the change is durable.
  Future<void> update(RecorderPreferences Function(RecorderPreferences preferences) transform) async {
    _checkNotDisposed();
    final fresh = transform(_value);
    if (fresh == _value) {
      return;
    }
    _value = fresh;
    _emit();
    try {
      await repository.save(RecorderKeys.document, fresh.toJson());
    } on Object catch (error, stack) {
      _report(RecorderPreferencesFailure.write, error, stack);
    }
  }

  /// Flushes nothing and closes the store; later [load] and [update] throw,
  /// [value] and [changes] stay readable.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _controller.close();
  }

  void _report(RecorderPreferencesFailure failure, Object error, StackTrace stack) {
    onError?.call(failure, error, stack);
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_value);
    }
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('RecorderPreferencesStore was disposed');
    }
  }
}
