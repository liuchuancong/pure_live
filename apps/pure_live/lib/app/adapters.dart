import 'package:live_uikit/styling.dart';
import 'package:live_uikit_cupertino_ui/live_uikit_cupertino_ui.dart';
import 'package:live_uikit_fluent/live_uikit_fluent.dart';
import 'package:live_uikit_forui/live_uikit_forui.dart';
import 'package:live_uikit_glass/live_uikit_glass.dart';
import 'package:live_uikit_macos/live_uikit_macos.dart';
import 'package:live_uikit_material_ui/live_uikit_material_ui.dart';
import 'package:live_uikit_neumorphic/live_uikit_neumorphic.dart';
import 'package:live_uikit_wind/live_uikit_wind.dart';

/// The composition root's adapter registry: every third-party design language
/// the build ships, keyed by the language it renders. The shared token base
/// serves the `material`/`cupertino` languages (the `material` language is the
/// default fallback); the `materialUi`/`cupertinoUi` forks are the separate
/// native adapters below.
const appLanguageRegistry = LanguageRegistry(
  adapters: {
    LiveDesignLanguage.macos: macosUiAdapter,
    LiveDesignLanguage.fluent: fluentUiAdapter,
    LiveDesignLanguage.forui: foruiUiAdapter,
    LiveDesignLanguage.neumorphic: neumorphicUiAdapter,
    LiveDesignLanguage.glass: glassUiAdapter,
    LiveDesignLanguage.wind: windUiAdapter,
    LiveDesignLanguage.cupertinoUi: cupertinoUiAdapter,
    LiveDesignLanguage.materialUi: materialUiAdapter,
  },
  fallback: SharedLanguageAdapter(),
);
