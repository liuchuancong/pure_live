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

/// The recorder's own choices, as persisted: where recordings land and how
/// long one capture segment runs.
///
/// Everything here is read by the recording engine adapter — the output
/// directory becomes the `RecordNaming` root, the segment length becomes the
/// FFmpeg capture's `segmentTime` at the moment a capture opens.
@immutable
final class RecorderPreferences {
  /// The shipping defaults: the app's own recordings tree, five-minute
  /// segments.
  const new({this.outputDirectory = '', this.segmentMinutes = 5});

  /// Reads the document; unknown shapes decode to the defaults.
  factory RecorderPreferences.fromJson(Map<String, Object?> json) => RecorderPreferences(
    outputDirectory: json['outputDirectory'] as String? ?? '',
    segmentMinutes: (json['segmentMinutes'] as num?)?.toInt() ?? 5,
  );

  /// The directory recordings are written under; empty means the app's own
  /// `AppDirectory.recordings` tree.
  final String outputDirectory;

  /// How much media one capture segment holds, in minutes. The engine clamps
  /// the value into its own working range.
  final int segmentMinutes;

  /// The segment length as the engine reads it, clamped to 1..60 minutes —
  /// a shorter segment multiplies container overhead, a longer one turns a
  /// crash into minutes of unclosed media.
  int get clampedSegmentMinutes => segmentMinutes.clamp(1, 60);

  /// Writes the document.
  Map<String, Object?> toJson() => {'outputDirectory': outputDirectory, 'segmentMinutes': clampedSegmentMinutes};

  /// Returns a copy with the given fields replaced.
  RecorderPreferences copyWith({String? outputDirectory, int? segmentMinutes}) => RecorderPreferences(
    outputDirectory: outputDirectory ?? this.outputDirectory,
    segmentMinutes: segmentMinutes ?? this.segmentMinutes,
  );

  @override
  bool operator ==(Object other) =>
      other is RecorderPreferences &&
      other.outputDirectory == outputDirectory &&
      other.segmentMinutes == segmentMinutes;

  @override
  int get hashCode => Object.hash(outputDirectory, segmentMinutes);
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

  RecorderPreferences _value = const RecorderPreferences();
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
