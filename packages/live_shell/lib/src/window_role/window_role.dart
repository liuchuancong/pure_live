/// What a window is for, and what that entitles it to.
///
/// The role — not the window id, not "the first one we made" — decides who owns
/// the application's global state and whose disappearance may end the process.
/// Everything in this package asks the role instead of guessing from a title or
/// a creation order, because a shell that treats any visible window as "the
/// main one" will quit the app the moment the viewer closes a floating video
/// window while the library window is still open.
enum WindowRole {
  /// The one window that owns global state: navigation, playback session,
  /// follows, settings. There is exactly one, it is created and rebuilt rather
  /// than duplicated, and it is the only role whose close can mean "quit".
  main,

  /// A detached video window: always on top, no menu, out of the taskbar.
  /// Belongs to a session the main window still owns, so destroying it must
  /// not affect the app's lifetime.
  videoFloat,

  /// A secondary tool window the viewer may want several of — the cast
  /// panel, a log view, the WebDAV browser.
  panel,

  /// A corner notification surface: update progress, "channel is live".
  /// Shown without stealing focus and never a reason to stay alive.
  popup,
}

/// What the role implies, as data rather than as scattered conditionals.
extension WindowRoleX on WindowRole {
  /// Whether this role owns the application's state and lifetime.
  bool get ownsAppState => this == WindowRole.main;

  /// Whether the window is listed in the taskbar / Dock's window menu.
  ///
  /// A floating video window and a corner toast are deliberately invisible
  /// there: they are transient views of something the main window owns, and
  /// giving them taskbar entries makes alt-tab a list of leftovers.
  bool get showsInTaskbar => this == WindowRole.main || this == WindowRole.panel;

  /// Whether showing this window may take keyboard focus.
  ///
  /// A corner popup is presented *inactive* — it is a toast, not a dialog, and
  /// stealing the viewer's focus mid-typing to announce a bitrate is rude.
  bool get takesFocusOnShow => this != WindowRole.popup;
}
