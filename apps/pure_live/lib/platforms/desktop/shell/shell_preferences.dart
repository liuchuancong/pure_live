// ignore_for_file: unnecessary_type_name_in_constructor -- the fromJson factory
// cannot use the `new` shorthand.
import 'dart:async';

import 'package:live_shell/live_shell.dart' show CloseAction;
import 'package:live_storage/live_storage.dart' show StorageRepository;

/// Where the shell document is persisted.
///
/// One document per preference group in the shared `settings.preferences` box,
/// versioned in its key — the same discipline the appearance document follows,
/// so a reshaped shell document resets the shell and never another group's
/// settings.
abstract final class ShellKeys {
  /// The box every preference group document lives in (`settings.preferences`).
  static const String box = 'settings.preferences';

  /// The shell group key.
  static const String document = 'preferences.shell.v1';
}

/// How the window's top edge is drawn.
///
/// The self-drawn strip is taken over natively by the `bitsdojo_window` fork
/// (`BDW_CUSTOM_FRAME` in `windows/runner/main.cpp`), which is configured
/// before the window exists and has no runtime toggle — a change here is a
/// next-start change, and the settings screen says so.
enum ShellWindowChrome {
  /// The app draws the caption strip and its buttons in Flutter.
  app,

  /// The operating system draws the native caption.
  system;

  /// Resolves a stored identifier; an unknown one falls back to [app].
  static ShellWindowChrome fromId(String? id) => switch (id) {
    'system' => ShellWindowChrome.system,
    _ => ShellWindowChrome.app,
  };

  /// The stable identifier persisted in the document.
  String get id => switch (this) {
    ShellWindowChrome.system => 'system',
    ShellWindowChrome.app => 'app',
  };
}

/// The desktop shell's own choices, as persisted.
final class ShellPreferences {
  /// The shipping defaults: draw the app's own strip, ask about closing until
  /// the viewer answers with "remember".
  const new({this.windowChrome = ShellWindowChrome.app, this.closeAction});

  /// Reads the document; unknown shapes decode to the defaults.
  factory ShellPreferences.fromJson(Map<String, Object?> json) => ShellPreferences(
    windowChrome: ShellWindowChrome.fromId(json['windowChrome'] as String?),
    closeAction: switch (json['closeAction'] as String?) {
      'hideToTray' => CloseAction.hideToTray,
      'minimise' => CloseAction.minimise,
      'quit' => CloseAction.quit,
      _ => null,
    },
  );

  /// Which title bar mode this start (and the next) uses.
  final ShellWindowChrome windowChrome;

  /// What the close button means, once the viewer has answered "remember" in
  /// the close prompt; null keeps asking every time.
  final CloseAction? closeAction;

  /// Writes the document.
  Map<String, Object?> toJson() => {
    'windowChrome': windowChrome.id,
    if (closeAction != null) 'closeAction': closeAction!.name,
  };

  /// Returns a copy with the given fields replaced.
  ShellPreferences copyWith({
    ShellWindowChrome? windowChrome,
    CloseAction? closeAction,
    bool clearCloseAction = false,
  }) => ShellPreferences(
    windowChrome: windowChrome ?? this.windowChrome,
    closeAction: clearCloseAction ? null : (closeAction ?? this.closeAction),
  );
}

/// What a [ShellPreferencesStore.load] or write found wrong.
///
/// The same shape as the appearance store's failures: a broken document keeps
/// its defaults and the fact is reported, never thrown.
enum ShellPreferencesFailure {
  /// The box read threw.
  read,

  /// A document was stored but is not a JSON object.
  shape,

  /// A JSON object was stored but did not decode.
  decode,

  /// A document was built but could not be written.
  write,
}

/// The desktop shell's persisted choices: one in-memory [ShellPreferences],
/// one JSON document through a storage repository.
///
/// Reads are synchronous so the window setup and the close flow can consult
/// the values before the first frame; writes are immediate (this document
/// changes a few times in the app's life, unlike the font-scale slider, so it
/// needs no debounce).
final class ShellPreferencesStore {
  /// A store persisting through [repository].
  new({required this.repository, this.onError});

  /// The repository the document is persisted in.
  final StorageRepository<Map<dynamic, dynamic>> repository;

  /// Reports every failed read or write; null swallows them, and the
  /// composition root installs a logger.
  final void Function(ShellPreferencesFailure failure, Object error, StackTrace stack)? onError;

  final StreamController<ShellPreferences> _controller = StreamController<ShellPreferences>.broadcast();

  ShellPreferences _value = const ShellPreferences();

  /// The current preferences, readable before the first frame.
  ShellPreferences get value => _value;

  /// Every applied change, in memory and then on disk.
  Stream<ShellPreferences> get changes => _controller.stream;

  /// Loads the document; a missing, stale or broken one keeps the defaults.
  Future<void> load() async {
    final Map<dynamic, dynamic>? stored;
    try {
      stored = repository.get(ShellKeys.document);
    } on Object catch (error, stack) {
      _report(ShellPreferencesFailure.read, error, stack);
      return;
    }
    if (stored == null) {
      return;
    }
    try {
      _value = ShellPreferences.fromJson(Map<String, Object?>.from(stored));
    } on Object catch (error, stack) {
      _report(ShellPreferencesFailure.decode, error, stack);
    }
  }

  /// Applies [transform] to the in-memory value, notifies and persists.
  Future<void> update(ShellPreferences Function(ShellPreferences preferences) transform) async {
    final next = transform(_value);
    _value = next;
    if (!_controller.isClosed) {
      _controller.add(next);
    }
    try {
      await repository.save(ShellKeys.document, next.toJson());
    } on Object catch (error, stack) {
      _report(ShellPreferencesFailure.write, error, stack);
    }
  }

  /// Releases the change stream.
  Future<void> dispose() => _controller.close();

  void _report(ShellPreferencesFailure failure, Object error, StackTrace stack) => onError?.call(failure, error, stack);
}
