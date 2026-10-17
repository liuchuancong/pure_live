// ignore_for_file: unnecessary_type_name_in_constructor -- the fromJson
// factory cannot use the `new` shorthand.
import 'dart:async';

import 'package:live_storage/live_storage.dart' show StorageRepository;

/// Where the multi-view document is persisted.
///
/// One document per preference group in the shared `settings.preferences`
/// box, versioned in its key — the same discipline the appearance document
/// follows (`lib/app/theme/appearance_preferences`), so a reshaped
/// multi-view document resets the multi-view layout and never another
/// group's settings. The rooms a wall held are not here: a wall is a
/// session, and the rooms live in the follow and history lists.
abstract final class MultiviewKeys {
  /// The box every preference group document lives in (`settings.preferences`).
  static const String box = 'settings.preferences';

  /// The multi-view group key.
  static const String document = 'preferences.multiview.v1';
}

/// How the wall divides its surface.
///
/// The grid is always rows of equal cells: [columns] by the rows its
/// [capacity] needs. Nine is the largest the reference app offered and the
/// most simultaneous decoders a desktop plays smoothly.
enum MultiviewLayout {
  /// One cell, full surface.
  single,

  /// Two cells side by side.
  dual,

  /// Four cells, two by two.
  quad,

  /// Six cells, two rows of three.
  six,

  /// Nine cells, three by three.
  nine;

  /// How many cells the layout shows.
  int get capacity => switch (this) {
    MultiviewLayout.single => 1,
    MultiviewLayout.dual => 2,
    MultiviewLayout.quad => 4,
    MultiviewLayout.six => 6,
    MultiviewLayout.nine => 9,
  };

  /// How many columns the grid draws.
  int get columns => switch (this) {
    MultiviewLayout.single => 1,
    MultiviewLayout.dual || MultiviewLayout.quad => 2,
    MultiviewLayout.six || MultiviewLayout.nine => 3,
  };

  /// Resolves a stored identifier; an unknown one falls back to [quad],
  /// which is the layout the page opened with before there was a document.
  static MultiviewLayout fromId(String? id) => switch (id) {
    'single' => MultiviewLayout.single,
    'dual' => MultiviewLayout.dual,
    'six' => MultiviewLayout.six,
    'nine' => MultiviewLayout.nine,
    _ => MultiviewLayout.quad,
  };

  /// The stable identifier persisted in the document.
  String get id => name;
}

/// The multi-view viewer's own choices, as persisted: the layout a session
/// ended on.
final class MultiviewPreferences {
  /// The shipping defaults: a two-by-two wall, the reference app's opening
  /// layout.
  const new({this.layout = MultiviewLayout.quad});

  /// Reads the document; unknown shapes decode to the defaults.
  factory MultiviewPreferences.fromJson(Map<String, Object?> json) =>
      MultiviewPreferences(layout: MultiviewLayout.fromId(json['layout'] as String?));

  /// The layout the wall drew last.
  final MultiviewLayout layout;

  /// Writes the document.
  Map<String, Object?> toJson() => {'layout': layout.id};

  /// Returns a copy with the given fields replaced.
  MultiviewPreferences copyWith({MultiviewLayout? layout}) => MultiviewPreferences(layout: layout ?? this.layout);
}

/// What a [MultiviewPreferencesStore.load] or write found wrong.
///
/// The same shape as the appearance store's failures: a broken document keeps
/// its defaults and the fact is reported, never thrown.
enum MultiviewPreferencesFailure {
  /// The box read threw.
  read,

  /// A document was stored but is not a JSON object.
  shape,

  /// A JSON object was stored but did not decode.
  decode,

  /// A document was built but could not be written.
  write,
}

/// The multi-view viewer's persisted choices: one in-memory
/// [MultiviewPreferences], one JSON document through a storage repository.
///
/// Reads are synchronous so the page can lay out before its first frame;
/// writes are immediate (a layout switch happens a few times per session,
/// unlike the font-scale slider, so it needs no debounce) — the same shape
/// the desktop shell's store uses.
final class MultiviewPreferencesStore {
  /// A store persisting through [repository].
  new({required this.repository, this.onError});

  /// The repository the document is persisted in.
  final StorageRepository<Map<dynamic, dynamic>> repository;

  /// Reports every failed read or write; null swallows them, and the
  /// composition root installs a logger.
  final void Function(MultiviewPreferencesFailure failure, Object error, StackTrace stack)? onError;
  final StreamController<MultiviewPreferences> _controller = StreamController<MultiviewPreferences>.broadcast();

  MultiviewPreferences _value = const MultiviewPreferences();
  bool _disposed = false;

  /// The current choices: the shipping defaults until [load] runs.
  MultiviewPreferences get value => _value;

  /// Emits on every applied change, including [load].
  Stream<MultiviewPreferences> get changes => _controller.stream;

  /// Reads the stored document, applying it when it decodes.
  ///
  /// A document that cannot be read or decoded leaves [value] as it is and is
  /// recorded through [onError]; a missing document is not a failure, it is
  /// simply the first run.
  Future<MultiviewPreferences> load() async {
    _checkNotDisposed();
    final Map<dynamic, dynamic>? raw;
    try {
      raw = repository.get(MultiviewKeys.document);
    } on Object catch (error, stack) {
      _report(MultiviewPreferencesFailure.read, error, stack);
      return _value;
    }
    if (raw == null) {
      return _value;
    }
    final MultiviewPreferences loaded;
    try {
      loaded = MultiviewPreferences.fromJson(Map<String, Object?>.from(raw));
    } on Object catch (error, stack) {
      _report(MultiviewPreferencesFailure.decode, error, stack);
      return _value;
    }
    if (loaded != _value) {
      _value = loaded;
      _emit();
    }
    return loaded;
  }

  /// Applies [transform] to the choices and persists the result.
  ///
  /// The returned future completes once the change is durable.
  Future<void> update(MultiviewPreferences Function(MultiviewPreferences preferences) transform) async {
    _checkNotDisposed();
    final fresh = transform(_value);
    if (fresh == _value) {
      return;
    }
    _value = fresh;
    _emit();
    try {
      await repository.save(MultiviewKeys.document, fresh.toJson());
    } on Object catch (error, stack) {
      _report(MultiviewPreferencesFailure.write, error, stack);
    }
  }

  /// Flushes nothing (writes are immediate) and closes the store; later
  /// [load] and [update] throw, [value] and [changes] stay readable.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _controller.close();
  }

  void _report(MultiviewPreferencesFailure failure, Object error, StackTrace stack) =>
      onError?.call(failure, error, stack);

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_value);
    }
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('MultiviewPreferencesStore was disposed');
    }
  }
}
