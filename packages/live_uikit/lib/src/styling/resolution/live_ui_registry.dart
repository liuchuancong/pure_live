import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';

/// The registered adapters by language (§7).
///
/// There is no fallback. Every language this build claims to support has to
/// bring its own adapter, because a shared renderer underneath the others is
/// what made every design language look like one library's Material widgets no
/// matter which was selected. A language with no adapter is therefore not a
/// degraded case to paper over — it is a composition fault, and the resolver
/// raises it as one.
final class LanguageRegistry {
  /// A registry of [adapters].
  const new({required this.adapters});

  /// The adapters by language.
  final Map<LiveDesignLanguage, LanguageAdapter> adapters;

  /// The adapter for [language], or null when this build did not register one.
  LanguageAdapter? adapterFor(LiveDesignLanguage language) => adapters[language];

  /// Whether [language] has a dedicated adapter.
  bool isRegistered(LiveDesignLanguage language) => adapters.containsKey(language);
}
