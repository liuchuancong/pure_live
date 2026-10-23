import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/material.dart' show Icons;
import 'package:pure_live/app/icons/app_icon_keys.dart';
import 'package:pure_uikit/pure_uikit.dart' show PureDesignLanguage, PureIconGlyph, PureIconMapping;

/// Tier 1: the single-icon specials, keyed by platform AND design language.
///
/// Platform and language are separate dimensions, so a key is answered for
/// one platform only where the fluent chrome needs a different glyph there.
/// Each table here answers only the keys it lists; the rest of that
/// platform+language pair falls to the language default.
///
/// The seed pair keeps the search glyph legible in the dense Fluent chrome
/// (the plain Material magnifier instead of the rounded variant the global
/// table's skin would otherwise get); add to these tables the way the old
/// 3.x per-platform patches were collected, one justified key at a time.
const Map<(TargetPlatform, PureDesignLanguage), PureIconMapping> appIconOverrides = {
  (TargetPlatform.windows, PureDesignLanguage.fluent): PureIconMapping({
    AppIconKey.search: PureIconGlyph(Icons.search),
    AppIconKey.more: PureIconGlyph(Icons.more_horiz),
  }),
};
