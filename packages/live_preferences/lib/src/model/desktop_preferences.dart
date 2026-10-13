import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_shell/live_shell.dart' show CloseAction;

part 'desktop_preferences.freezed.dart';
part 'desktop_preferences.g.dart';

// What the close button does is spelled by the shell (`CloseAction`), not again
// here: this group used to carry its own copy of that enum, with the same three
// names, and the two could drift apart one value at a time while the JSON stayed
// readable — a `CloseAction` with a fourth case would simply fail to map, in the
// app's hand-written switch, at runtime. One vocabulary, owned by the package
// whose whole job is what closing means.

/// Desktop shell preferences: the window, the tray, and signing in.
///
/// This group is separate from the floating-window group on purpose: that one
/// is about the playback floating window, a feature of the player, while these are
/// about the application as a process on a desktop — and the difference matters
/// most on the platforms where one applies and the other does not, since
/// Android and Android TV have a PiP window but no tray, no caption and no
/// sign-in item.
///
/// Two of these are **escape hatches**, not tastes, and the settings screen
/// should present them that way: [effects] off fixes a window that shows black
/// at its corners or keeps a stale frame after a GPU cache invalidation, and
/// [hardwareAcceleration] off is the answer to a driver that corrupts the
/// surface. Neither is a preference the app can honour instantly —
/// the rendering choice is made before the first frame is drawn, so a change is
/// reported as taking effect on the next start rather than silently ignored.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class DesktopPreferences with _$DesktopPreferences {
  /// Desktop shell preferences with the shipping defaults.
  const factory DesktopPreferences({
    /// What pressing the close button means.
    ///
    /// Read and written by the two functions below rather than by the generator's
    /// enum decode, which throws on anything it does not recognise: a document
    /// written by a newer build — one that added a fourth case — would otherwise
    /// stop this build from starting at all. A rolled-back install is an ordinary
    /// path for a desktop app, and a saved preference must never be able to say
    /// "no interface for you". An unrecognised or mistyped value costs a reset to
    /// the shipping default, which is the whole price.
    @JsonKey(fromJson: _closeActionFromJson, toJson: _closeActionToJson)
    @Default(CloseAction.hideToTray)
    CloseAction closeAction,

    /// Whether an icon sits in the notification area / menu bar at all.
    ///
    /// Turning this off makes [closeAction] `hideToTray` meaningless, and the
    /// shell then quits on close by design rather than leaving a windowless
    /// process nobody can reach.
    @Default(true) bool showTrayIcon,

    /// Whether the window's place and size are remembered between starts.
    @Default(true) bool rememberWindowBounds,

    /// Whether the app registers itself to start at sign-in.
    @Default(false) bool launchAtLogin,

    /// Whether a start comes up in the tray without showing a window.
    @Default(false) bool startHidden,

    /// Whether the interface may be destroyed to give its memory back once the
    /// window has been out of sight for [idleReclaimAfter].
    ///
    /// Never while something is recording or a stream is being pulled — the
    /// shell checks that separately, because the rebuild path is where a dropped
    /// segment would be found days later, not now.
    @Default(false) bool reclaimWhenIdle,

    /// How long out of sight and untouched before the interface is reclaimed.
    @Default(Duration(minutes: 30)) Duration idleReclaimAfter,

    /// Whether the platform's translucent window material may be used.
    @Default(true) bool effects,

    /// Whether the GPU may draw. Off means the software rasteriser.
    @Default(true) bool hardwareAcceleration,

    /// Whether the app may post system notifications (recording finished, a
    /// followed channel went live).
    ///
    /// The body of a notification lands in the system's notification centre and
    /// on the lock screen, so nothing identifying a private room belongs there —
    /// which is why this is one switch over all of them.
    @Default(true) bool systemNotifications,
  }) = _DesktopPreferences;

  /// Restores desktop shell preferences from JSON.
  factory DesktopPreferences.fromJson(Map<String, Object?> json) => _$DesktopPreferencesFromJson(json);
}

/// Maps a stored name to a [CloseAction], defaulting on anything unrecognised.
///
/// The switch is over the **strings**, not over `CloseAction.values`, on purpose:
/// reading by name is what makes an added case in a newer build a non-event here,
/// and the default branch is the rollback path rather than an error.
CloseAction _closeActionFromJson(Object? value) => switch (value) {
  'minimise' => CloseAction.minimise,
  'quit' => CloseAction.quit,
  _ => CloseAction.hideToTray,
};

/// Writes a [CloseAction] as the name shipped builds already have on disk.
String _closeActionToJson(CloseAction action) => action.name;
