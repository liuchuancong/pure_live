import 'package:pure_uikit/src/bootstrap/pure_ui_startup_config.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';

/// Decides the design language a process starts with, and never again.
///
/// The rules are the §6.3 table of the v4 spec, and they all run here rather
/// than being spread across the hosts: nothing stored takes the product
/// default, a stored value that decodes to nothing takes the product default,
/// a language whose dependency is unavailable degrades to the product default,
/// and a launch pin wins over the store for the run it was passed to.
///
/// What is deliberately *not* here: re-resolving. The app calls [resolve] once
/// during boot and freezes the result; a settings change writes the store and
/// waits for the next process (§2.4). An abstract class with one static
/// member so there is no instance to hold and no state to go stale.
abstract final class PureUiStartupResolver {
  /// Resolves this process's [PureUiStartupConfig].
  ///
  /// [defaultLanguage] is the product's own default, supplied by the app
  /// rather than guessed per platform — §6.3 asks for one explicit value.
  /// [storedLanguageId] is the raw persisted id; [decode] turns an id into a
  /// language and returns null when it names none (an empty id included).
  /// [launchPin] is the language a debug launch argument asked for, null when
  /// the argument was absent. [isAvailable] answers whether a language can
  /// actually be mounted in this build; a build that compiles every language
  /// in always returns true.
  static PureUiStartupConfig resolve({
    required PureDesignLanguage defaultLanguage,
    required String? storedLanguageId,
    required PureDesignLanguage? Function(String? id) decode,
    PureDesignLanguage? launchPin,
    bool Function(PureDesignLanguage language) isAvailable = _alwaysAvailable,
  }) {
    final stored = decode(storedLanguageId);

    // A pin is a developer asking for one run, so it is reported as the
    // origin even when the store also holds a language — the store stays
    // untouched, which is what lets a checked language be left selected
    // without the user having to un-pick it later.
    if (launchPin != null) {
      return PureUiStartupConfig(
        language: launchPin,
        origin: PureUiStartupOrigin.launchPin,
        defaultLanguage: defaultLanguage,
        storedLanguageId: storedLanguageId,
        pin: launchPin,
      );
    }

    // Nothing was ever stored: a first run, not a broken document.
    if (storedLanguageId == null || storedLanguageId.isEmpty) {
      return _withDefault(
        defaultLanguage: defaultLanguage,
        origin: PureUiStartupOrigin.notRecorded,
        storedLanguageId: storedLanguageId,
      );
    }

    // A value was stored and names no language this build has — a rename or a
    // removed language. The store is left as it is (the id keeps the record of
    // what the user chose), and the default answers.
    if (stored == null) {
      return _withDefault(
        defaultLanguage: defaultLanguage,
        origin: PureUiStartupOrigin.unrecognised,
        storedLanguageId: storedLanguageId,
      );
    }

    // The chosen language is known but cannot be mounted here; degrade rather
    // than fail the boot.
    if (!isAvailable(stored)) {
      return _withDefault(
        defaultLanguage: defaultLanguage,
        origin: PureUiStartupOrigin.degraded,
        storedLanguageId: storedLanguageId,
        pin: launchPin,
      );
    }

    return PureUiStartupConfig(
      language: stored,
      origin: PureUiStartupOrigin.recorded,
      defaultLanguage: defaultLanguage,
      storedLanguageId: storedLanguageId,
      pin: launchPin,
    );
  }

  static PureUiStartupConfig _withDefault({
    required PureDesignLanguage defaultLanguage,
    required PureUiStartupOrigin origin,
    required String? storedLanguageId,
    PureDesignLanguage? pin,
  }) => PureUiStartupConfig(
    language: defaultLanguage,
    origin: origin,
    defaultLanguage: defaultLanguage,
    storedLanguageId: storedLanguageId,
    pin: pin,
  );

  static bool _alwaysAvailable(PureDesignLanguage language) => true;
}
