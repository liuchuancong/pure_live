import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/l10n/translations.dart';

/// A platform's display name in the app's current language, falling back
/// through the manifests' localized names to their stable id.
String localizedSiteName(LiveSite site) {
  final locale = LocaleSettings.currentLocale.flutterLocale.toLanguageTag();
  return site.manifest.localizedName(locale, 'zh-CN');
}

/// The platform's own icon, when its manifest ships one; null when it does
/// not (the caller falls back to a glyph).
Widget? localizedSiteIcon(LiveSite? site, {double size = 16}) {
  final icon = site?.manifest.icon;
  if (icon == null) return null;
  // The switch's branches are ImageProvider subtypes; the annotation is
  // what lets the null fall through to DsImage's type.
  // ignore: omit_local_variable_types
  final ImageProvider<Object>? image = switch (icon.type) {
    LiveAssetType.bundled => (icon.path ?? '').trim().isEmpty
        ? null
        : AssetImage(icon.path!.trim(), package: 'live_sites'),
    LiveAssetType.remote => icon.uri == null ? null : NetworkImage(icon.uri.toString()),
    LiveAssetType.platformDefault => null,
  };
  if (image == null) return null;
  return DsImage(
    image: image,
    width: size,
    height: size,
    semanticLabel: site == null ? null : localizedSiteName(site),
    style: DsImageStyle(borderRadius: BorderRadius.circular(size <= 18 ? 4 : 6)),
  );
}
