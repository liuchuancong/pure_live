import 'package:flutter/foundation.dart' show TargetPlatform, visibleForTesting;
import 'package:pure_uikit/src/icons/api/pure_icon_key.dart';
import 'package:pure_uikit/src/icons/registry/icon_mapping.dart';
import 'package:pure_uikit/src/icons/registry/icon_resolver.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';

/// The app's icon registration, reached through the one static entry.
///
/// This is deliberately the ONLY public registration class: mappings,
/// resolution and fallback are its collaborators, not competing doors.
/// The kit never installs anything itself — the app calls [install] from
/// its bootstrap before the first frame, and every icon draw then reads
/// [current].
class PureIconRegistry {
  /// Builds an empty registry.
  new({this.onDiagnostic});

  /// Called for every resolution whose tier deserves a developer note (the
  /// fallback). The app decides where it surfaces — a debug log, an assert,
  /// a diagnostics screen.
  final void Function(PureIconResolution resolution)? onDiagnostic;

  final Map<(TargetPlatform, PureDesignLanguage), PureIconMapping> _overrides = {};
  final Map<PureDesignLanguage, PureIconMapping> _languages = {};
  PureIconMapping? _global;

  /// The platform+language override table (tier 1): a single key on one
  /// platform in one language — "Windows Fluent draws the book key with
  /// Material".
  void registerPlatformOverride(TargetPlatform platform, PureDesignLanguage language, PureIconMapping mapping) {
    _overrides[(platform, language)] = mapping;
  }

  /// A design language's default mapping (tier 2).
  void registerLanguage(PureDesignLanguage language, PureIconMapping mapping) {
    _languages[language] = mapping;
  }

  /// The app-wide mapping consulted before the fallback (tier 3) — the
  /// neutral library, e.g. Lucide.
  // ignore: use_setters_to_change_properties — there is no field to set through.
  void setGlobal(PureIconMapping mapping) => _global = mapping;

  /// The four-tier lookup; see [PureIconResolver.resolve].
  PureIconResolution resolve(
    PureIconKey key, {
    required TargetPlatform platform,
    required PureDesignLanguage language,
  }) {
    final resolution = PureIconResolver(
      _overrides,
      _languages,
      _global,
    ).resolve(key, platform: platform, language: language);
    if (resolution.diagnostic != null) onDiagnostic?.call(resolution);
    return resolution;
  }

  static PureIconRegistry? _installed;

  /// Publishes the app's registry; calling it twice is a bug, not a merge.
  static void install(PureIconRegistry registry) {
    assert(_installed == null, 'PureIconRegistry.install called twice — the app bootstraps its icons once.');
    _installed = registry;
  }

  /// The installed registry; throws with guidance when nothing registered.
  static PureIconRegistry get current {
    final registry = _installed;
    if (registry == null) {
      throw StateError('No PureIconRegistry installed: call the app icon bootstrap first.');
    }
    return registry;
  }

  /// Whether [current] would answer (tests, diagnostics screens).
  static bool get hasInstalled => _installed != null;

  /// Clears the installed registry (test isolation only).
  @visibleForTesting
  static void resetInstalledForTest() => _installed = null;
}
