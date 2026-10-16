import 'package:live_uikit/styling.dart';
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
/// token fallback only, so the app is the single place that decides which
/// libraries are linked in. `LiveDesignLanguage.token` is not listed because it
/// *is* that fallback; registering it would hide the `adapterMissing` report for
/// anything this build genuinely does not support.
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
  fallback: SharedLanguageAdapter(),
);
