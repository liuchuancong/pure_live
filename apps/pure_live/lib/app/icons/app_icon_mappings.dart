import 'package:pure_live/app/icons/adapters/fluent_icon_adapter.dart';
import 'package:pure_uikit/pure_uikit.dart' show PureDesignLanguage, PureIconMapping;

/// Tier 2: the design language's own answer table.
///
/// It is partial: the table names only the keys the fluent font owns
/// natively, and everything else falls to the global backstop — so a new
/// key joins by adding one entry here, never by touching a call site.
const Map<PureDesignLanguage, PureIconMapping> appIconLanguageMappings = {
  PureDesignLanguage.fluent: fluentIconsOverrides,
};
