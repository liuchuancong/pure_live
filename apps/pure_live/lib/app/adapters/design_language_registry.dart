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
/// this build ships, keyed by the language it renders.
///
/// Adapters never self-register — the core ships contracts plus the shared
/// token fallback only, so the app is the single place that decides which
/// libraries are linked in. `material` and `cupertino` are deliberately
/// absent: the shared token base renders them, and registering only the
/// third-party languages keeps `adapterMissing` honest for anything the build
/// genuinely does not support.
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
