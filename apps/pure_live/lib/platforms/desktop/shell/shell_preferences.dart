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
/// The self-drawn strip is taken over natively by the window plugin's own frame
/// takeover (`WindowOptions.customFrame`, armed from the chrome plan), which
/// answers `WM_NCCALCSIZE` and the edge hit-test while keeping `WS_THICKFRAME`.
/// The mode is resolved once, before the window is dressed, so a change here is
/// a next-start change and the settings screen says so.
///
/// Stored as nullable on purpose: **null is a third answer, "I never picked"**,
/// and then the mode comes from the operating system — Windows 11 composes a
/// custom frame's edge and rounded corners itself so the app-drawn strip is the
/// default, Windows 10 does neither so the native caption is. Keeping that
/// undecided rather than recording the first run's answer is what lets an
/// upgrade from 10 to 11 pick up the strip without anyone changing a setting.
enum ShellWindowChrome {
  /// The app draws the caption strip and its buttons in Flutter.
  app,

  /// The operating system draws the native caption.
  system;

  /// Resolves a stored identifier; null and unknown both mean "not chosen".
  ///
  /// Not falling back to [app] is the point: a document written by an older
  /// build, or a value edited by hand, must not silently become an explicit
  /// choice the viewer never made.
  static ShellWindowChrome? tryFromId(String? id) => switch (id) {
    'system' => ShellWindowChrome.system,
    'app' => ShellWindowChrome.app,
    _ => null,
  };

  /// The stable identifier persisted in the document.
  String get id => switch (this) {
    ShellWindowChrome.system => 'system',
    ShellWindowChrome.app => 'app',
  };
}

/// The desktop shell's own choices, as persisted.
final class ShellPreferences {
  /// The shipping defaults: leave the title bar to the operating system, and ask
  /// about closing until the viewer answers with "remember". Both are the answers
  /// for someone who has never opened the settings screen, which is why neither
  /// records a choice — see [ShellWindowChrome] for what the un-chosen title bar
  /// resolves to.
  const new({this.windowChrome, this.closeAction});

  /// Reads the document; unknown shapes decode to the defaults.
  factory ShellPreferences.fromJson(Map<String, Object?> json) => ShellPreferences(
    windowChrome: ShellWindowChrome.tryFromId(json['windowChrome'] as String?),
    closeAction: switch (json['closeAction'] as String?) {
      'hideToTray' => CloseAction.hideToTray,
      'minimise' => CloseAction.minimise,
      'quit' => CloseAction.quit,
      _ => null,
    },
  );

  /// The title bar mode the viewer chose, or null to leave it to the operating
  /// system.
  ///
  /// This is the *intent for the next start*, not what the live window is drawn
  /// in: `resolveWindowChrome` folds it with the launch arguments and the
  /// operating system's default into the mode this process runs in, and
  /// `DesktopEntry` publishes that as `windowChromeProvider`.
  final ShellWindowChrome? windowChrome;

  /// What the close button means, once the viewer has answered "remember" in
  /// the close prompt; null keeps asking every time.
  final CloseAction? closeAction;

  /// Writes the document.
  Map<String, Object?> toJson() => {
    if (windowChrome != null) 'windowChrome': windowChrome!.id,
    if (closeAction != null) 'closeAction': closeAction!.name,
  };

  /// Returns a copy with the given fields replaced.
  ShellPreferences copyWith({
    ShellWindowChrome? windowChrome,
    bool clearWindowChrome = false,
    CloseAction? closeAction,
    bool clearCloseAction = false,
  }) => ShellPreferences(
    windowChrome: clearWindowChrome ? null : (windowChrome ?? this.windowChrome),
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
