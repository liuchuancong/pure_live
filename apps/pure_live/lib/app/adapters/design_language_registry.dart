import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_cupertino/live_uikit_cupertino.dart';
import 'package:live_uikit_fluent/live_uikit_fluent.dart';
import 'package:live_uikit_forui/live_uikit_forui.dart';
import 'package:live_uikit_glass/live_uikit_glass.dart';
import 'package:live_uikit_macos/live_uikit_macos.dart';
import 'package:live_uikit_material/live_uikit_material.dart';
import 'package:live_uikit_neumorphic/live_uikit_neumorphic.dart';
import 'package:live_uikit_wind/live_uikit_wind.dart';

/// The composition root's adapter registry: every third-party design language
/// this build ships, keyed by the language it renders.
///
/// Adapters never self-register — the core ships contracts plus the shared
/// adapters only, so the app is the single place that decides which libraries
/// are linked in. There is no fallback to register: a language listed here
/// without an adapter, or a language this build does not list, is a
/// `LiveUiResolutionException` at boot rather than a silently foreign-looking
/// window.
const appLanguageRegistry = LanguageRegistry(
  adapters: {
    LiveDesignLanguage.macos: macosAdapter,
    LiveDesignLanguage.fluent: fluentAdapter,
    LiveDesignLanguage.forui: foruiAdapter,
    LiveDesignLanguage.neumorphic: neumorphicAdapter,
    LiveDesignLanguage.glass: glassAdapter,
    LiveDesignLanguage.wind: windAdapter,
    LiveDesignLanguage.cupertino: cupertinoAdapter,
    LiveDesignLanguage.material: materialAdapter,
  },
);
