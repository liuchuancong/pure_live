import 'package:pure_uikit/src/styling/config/pure_design_language.dart';

/// Why this process runs the design language it runs.
///
/// The value is diagnostics, not behaviour: every case except [recorded] means
/// the configuration the user stored did not decide the host on its own, and
/// [PureUiStartupConfig.reason] turns it into the sentence the boot log prints.
enum PureUiStartupOrigin {
  /// The stored design language was decoded and mounted as chosen.
  recorded,

  /// Nothing was stored yet, so the product default answered.
  notRecorded,

  /// Something was stored, but it names no language this build knows.
  unrecognised,

  /// A launch argument pinned the language for this run.
  launchPin,

  /// The language was chosen but its dependency could not be used, so the
  /// build fell back to the product default.
  degraded,
}

/// The design language this process was started with.
///
/// It is resolved once, before the first frame, and then never changes: the
/// app host is picked from it and every [PureDesignLanguage] read below the
/// provider comes from it too. Editing the stored preference afterwards does
/// not touch this object — that edit is what the settings page shows as
/// pending, and it takes effect in the next process (§2.4 of the v4 spec).
final class PureUiStartupConfig {
  /// A frozen startup configuration.
  const new({
    required this.language,
    required this.origin,
    required this.defaultLanguage,
    this.storedLanguageId,
    this.pin,
  });

  /// The language this process renders with, host included.
  final PureDesignLanguage language;

  /// Why [language] is the one.
  final PureUiStartupOrigin origin;

  /// The product default the resolver was handed; the fallback every
  /// abnormal origin degrades to.
  final PureDesignLanguage defaultLanguage;

  /// The raw stored id, kept for the boot log; null when nothing was stored.
  final String? storedLanguageId;

  /// The language a launch argument pinned, if any.
  final PureDesignLanguage? pin;

  /// Whether [language] came from anything other than the stored choice.
  bool get isForced => origin != PureUiStartupOrigin.recorded;

  /// One line saying what was mounted and why, for the boot log.
  ///
  /// "I switched the style and nothing changed" is the question this answers:
  /// the log says whether the store was read, whether it decoded, and whether
  /// a pin or a fallback overrode it. The fallback cases name
  /// [defaultLanguage] rather than [language] so the sentence stays true for a
  /// configuration built by hand as well as one the resolver produced.
  String get reason => switch (origin) {
    PureUiStartupOrigin.recorded => 'design language ${language.name} from stored configuration',
    PureUiStartupOrigin.notRecorded =>
      'no stored design language; product default ${defaultLanguage.name} (stored id: ${storedLanguageId ?? '<none>'})',
    PureUiStartupOrigin.unrecognised =>
      'stored design language "${storedLanguageId ?? ''}" is unknown to this build; product default '
          '${defaultLanguage.name}',
    PureUiStartupOrigin.launchPin => 'design language ${language.name} pinned by launch argument',
    PureUiStartupOrigin.degraded =>
      'design language ${storedLanguageId ?? language.name} unavailable; degraded to ${defaultLanguage.name}',
  };
}
