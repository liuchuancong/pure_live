/// The design languages Pure Live can render in.
///
/// A design language is a *look*, not a platform: Windows may run Fluent or
/// Material, an Android phone Material or Neumorphic. Which one is active
/// comes from the user's preferences ([LiveDesignLanguage.id] is what gets
/// stored), never from `Platform.isX`, so the two axes stay independent.
enum LiveDesignLanguage {
  /// Material, the cross-platform default and the fallback for every
  /// language that does not implement a component.
  material('material'),

  /// iOS-style Cupertino.
  cupertino('cupertino'),

  /// Windows-style Fluent.
  fluent('fluent'),

  /// macOS-native styling.
  macos('macos'),

  /// Ubuntu's Yaru.
  yaru('yaru'),

  /// Soft-embossed Neumorphic.
  neumorphic('neumorphic');

  new(this.id);

  /// The stable registry id, also the stored preference value.
  final String id;

  /// The language named by [id], or null when the id is unknown.
  ///
  /// Unknown ids are expected — a document written by a newer build may
  /// name a language this build does not have — and the caller decides the
  /// fallback (the app uses the platform's default language).
  static LiveDesignLanguage? fromId(String id) {
    final normalized = id.trim().toLowerCase();
    for (final language in values) {
      if (language.id == normalized) {
        return language;
      }
    }
    return null;
  }
}
