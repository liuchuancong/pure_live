import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// The face the platform's own design system sets its UI in, or null where
/// the library's default already IS that face.
///
/// - Windows ships **Segoe UI** on every install; naming it gives the
///   fluent-native reading (Chinese falls back to the system's YaHei),
///   where desen_ui's bundled face would otherwise draw.
/// - Android ships **Roboto**; its CJK companion (Noto Sans CJK) arrives
///   through the same per-glyph fallback.
/// - iOS and macOS answer null on purpose: desen_ui's `DsTypography`
///   already resolves its null family to `CupertinoSystemText`/`Display`,
///   i.e. San Francisco, Apple's own face. Linux and the web answer null
///   too and keep the library's bundled Schibsted Grotesk, which is the
///   face designed for those hosts.
///
/// A stored family always outranks this: it is a choice the viewer made.
String? platformFontFamily({bool? web, TargetPlatform? platform}) {
  if (web ?? kIsWeb) {
    return null;
  }
  return switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.windows => 'Segoe UI',
    TargetPlatform.android => 'Roboto',
    TargetPlatform.iOS || TargetPlatform.macOS => null,
    TargetPlatform.linux || TargetPlatform.fuchsia => null,
  };
}

/// The face [platformFontFamily] resolves to (or the library's designed
/// face where it answers null), named for the font manager's preview row.
String platformFontFamilyLabel({bool? web, TargetPlatform? platform}) {
  if (web ?? kIsWeb) return 'Schibsted Grotesk';
  return switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.windows => 'Segoe UI',
    TargetPlatform.android => 'Roboto',
    TargetPlatform.iOS || TargetPlatform.macOS => 'San Francisco',
    TargetPlatform.linux || TargetPlatform.fuchsia => 'Schibsted Grotesk',
  };
}

/// The official faces bundled with this app (`pubspec.yaml`'s
/// `flutter: fonts:`), offered as presets in the appearance pane. They are
/// app fonts, so a selected one is looked up with a null package; the two
/// Apple faces give Windows and Linux the Cupertino register, Roboto and
/// Inter the Google and shadcn/Tailwind ones, Ubuntu Sans Canonical's.
///
/// Segoe UI and Android's Roboto are NOT here: they are the system faces
/// and `platformFontFamily` already names them.
const List<(String id, String label)> kBundledFontPresets = [
  ('SFPro', 'SF Pro'),
  ('SFRounded', 'SF Pro Rounded'),
  ('Roboto', 'Roboto'),
  ('Inter', 'Inter'),
  ('Ubuntu', 'Ubuntu Sans'),
];
