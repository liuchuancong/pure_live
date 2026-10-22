/// What an icon MEANS, never which font draws it.
///
/// The consuming app declares its own enum implementing this interface
/// (`enum AppIconKey implements PureIconKey { ...; String get id => name; }`
/// — the one line is needed because the compiler does not let an enum's
/// implicit `name` satisfy an interface member); the kit only routes keys
/// to registered sources, so it never learns what a "follow" icon is or
/// which library draws it.
abstract interface class PureIconKey {
  /// The stable identifier used in diagnostics and resolution notices.
  String get id;
}
