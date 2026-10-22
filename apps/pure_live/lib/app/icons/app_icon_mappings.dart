import 'package:pure_live/app/icons/adapters/cupertino_icon_adapter.dart';
import 'package:pure_live/app/icons/adapters/fluent_icon_adapter.dart';
import 'package:pure_live/app/icons/adapters/material_icon_adapter.dart';
import 'package:pure_live/app/icons/adapters/yaru_icon_adapter.dart';
import 'package:pure_uikit/pure_uikit.dart' show PureDesignLanguage, PureIconMapping;

/// Tier 2: each design language's own answer table.
///
/// These are partial: a language table names only the keys its font owns
/// natively, and everything else falls to the global backstop — so a new
/// skin joins by adding one map here, never by touching a call site.
const Map<PureDesignLanguage, PureIconMapping> appIconLanguageMappings = {
  PureDesignLanguage.material: materialIcons,
  PureDesignLanguage.cupertino: cupertinoIconsOverrides,
  PureDesignLanguage.yaru: yaruIconsOverrides,
  PureDesignLanguage.fluent: fluentIconsOverrides,
};
