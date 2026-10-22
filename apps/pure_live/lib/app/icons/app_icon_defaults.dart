import 'package:pure_live/app/icons/adapters/lucide_icon_adapter.dart';
import 'package:pure_live/app/icons/app_icon_keys.dart';
import 'package:pure_uikit/pure_uikit.dart' show PureIconMapping;

/// Tier 3: the app-wide backstop consulted when no language table or
/// platform override names a key.
///
/// Lucide is the neutral library of v4: skins whose own kit ships no icon
/// font (fluent, macos, neumorphic, glass, wind, forui) draw from here, so
/// a line-style glyph — not a stray Material one — answers an unregistered
/// key. The table is complete over [AppIconKey], so nothing reaches the
/// kit's conspicuous fallback by accident.
const PureIconMapping appIconDefaults = lucideIcons;
