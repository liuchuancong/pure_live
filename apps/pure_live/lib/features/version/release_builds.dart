import 'dart:convert' show jsonDecode;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest;

import 'package:pure_live/features/version/update_feed.dart' show UpdateFeedException, versionProjectUrl;
import 'package:pure_live/l10n/translations.dart';

/// The repository whose releases carry the installers.
const String updateReleaseApiBase = 'https://api.github.com/repos/liuchuancong/pure_live/releases';

/// The platform an asset installs on.
enum ReleasePlatform { android, ios, windows, macOS, linux, other }

/// What kind of package an asset is.
enum PackageKind { apk, ipa, installer, dmg, msix, deb, tarGz, portable, other }

/// One installation package a release publishes.
///
/// The names are the build's own (`PureLive-3.1.19-4108-windows-x64-setup.exe`),
/// and they carry everything the page needs: the platform, the architecture
/// and the package kind are all readable from the file name, which is where
/// the classification below comes from.
final class ReleaseBuild {
  /// Creates the record.
  const ReleaseBuild({
    required this.name,
    required this.url,
    required this.size,
    required this.downloads,
    required this.platform,
    required this.arch,
    required this.kind,
  });

  /// The file name, as the release publishes it.
  final String name;

  /// Where to download it from.
  final String url;

  /// Its size in bytes, as the release states.
  final int size;

  /// How often it has been downloaded.
  final int downloads;

  /// The platform it installs on.
  final ReleasePlatform platform;

  /// The architecture it is built for (`x64`, `arm64-v8a`, `universal`…),
  /// or empty when the name does not say.
  final String arch;

  /// What kind of package it is.
  final PackageKind kind;

  /// The version the name carries (`3.1.19`), empty when it does not.
  String get version {
    final match = RegExp(r'-(\d+\.\d+\.\d+)-').firstMatch(name);
    return match?.group(1) ?? '';
  }
}

/// Reads one GitHub release asset; null for anything that is not an
/// installable package (a checksum file, the build metadata).
ReleaseBuild? releaseBuildFromJson(Map<String, Object?> json) {
  final name = json['name']?.toString().trim() ?? '';
  final url = (json['browser_download_url'] ?? json['url'])?.toString().trim() ?? '';
  if (name.isEmpty || url.isEmpty) return null;
  final lowered = name.toLowerCase();
  final platform = switch (true) {
    _ when lowered.contains('-android-') => ReleasePlatform.android,
    _ when lowered.contains('-ios-') => ReleasePlatform.ios,
    _ when lowered.contains('-windows-') => ReleasePlatform.windows,
    _ when lowered.contains('-macos-') => ReleasePlatform.macOS,
    _ when lowered.contains('-linux-') => ReleasePlatform.linux,
    _ => ReleasePlatform.other,
  };
  if (platform == ReleasePlatform.other) return null;
  final kind = switch (true) {
    _ when lowered.endsWith('.apk') => PackageKind.apk,
    _ when lowered.endsWith('.ipa') => PackageKind.ipa,
    _ when lowered.endsWith('.msix') => PackageKind.msix,
    _ when lowered.endsWith('.dmg') => PackageKind.dmg,
    _ when lowered.endsWith('.deb') => PackageKind.deb,
    _ when lowered.endsWith('.tar.gz') => PackageKind.tarGz,
    _ when lowered.endsWith('-setup.exe') => PackageKind.installer,
    _ when lowered.endsWith('.exe') => PackageKind.installer,
    _ when lowered.endsWith('.zip') => PackageKind.portable,
    _ => PackageKind.other,
  };
  if (kind == PackageKind.other) return null;
  final archMatch = RegExp('-(arm64-v8a|armeabi-v7a|x86_64|arm64|x64|universal|aarch64)-').firstMatch(lowered);
  return ReleaseBuild(
    name: name,
    url: url,
    size: switch (json['size']) {
      final int value => value,
      final String value => int.tryParse(value) ?? 0,
      _ => 0,
    },
    downloads: switch (json['download_count'] ?? json['downloadCount']) {
      final int value => value,
      final String value => int.tryParse(value) ?? 0,
      _ => 0,
    },
    platform: platform,
    arch: archMatch?.group(1) ?? '',
    kind: kind,
  );
}

/// The releases' endpoint for [version] (`3.1.19` → `tags/v3.1.19`), or the
/// repository's latest when no version is given.
String releaseAssetsUrl({String? version}) {
  final tag = version?.trim() ?? '';
  if (tag.isEmpty) return '$updateReleaseApiBase/latest';
  return '$updateReleaseApiBase/tags/${tag.startsWith('v') ? tag : 'v$tag'}';
}

/// The installable packages of one release, newest platform first within the
/// release's own order.
Future<List<ReleaseBuild>> fetchReleaseBuilds(LiveHttp http, {String? version}) async {
  final response = await http.send(
    LiveRequest.get(
      Uri.parse(releaseAssetsUrl(version: version)),
      headers: const {'accept': 'application/vnd.github+json'},
      timeout: const Duration(seconds: 20),
    ),
  );
  if (!response.isOk) throw UpdateFeedException('HTTP ${response.statusCode}');
  Object? decoded;
  try {
    decoded = jsonDecode(response.text);
  } on FormatException catch (error) {
    throw UpdateFeedException('The release payload is not valid JSON: ${error.message}');
  }
  if (decoded is! Map<String, Object?>) throw const UpdateFeedException('The release payload is not an object');
  final assets = decoded['assets'];
  if (assets is! List<Object?>) return const [];
  return [for (final asset in assets.whereType<Map<String, Object?>>()) ?releaseBuildFromJson(asset)];
}

/// The build this device would install: its own platform, preferring the
/// native architecture and, within that, an installer over a portable
/// archive. Null when the release carries nothing for this platform.
ReleaseBuild? recommendedBuild(List<ReleaseBuild> builds) {
  if (builds.isEmpty) return null;
  final own = currentReleasePlatform();
  final mine = [for (final build in builds) if (build.platform == own) build];
  if (mine.isEmpty) return null;
  final arch = preferredArch(own);
  final ranked = [...mine]..sort((a, b) {
    final byArch = (b.arch == arch ? 1 : 0) - (a.arch == arch ? 1 : 0);
    if (byArch != 0) return byArch;
    return _kindRank(a.kind).compareTo(_kindRank(b.kind));
  });
  return ranked.first;
}

/// The platform this build runs on, as the release names it.
ReleasePlatform currentReleasePlatform() {
  if (kIsWeb) return ReleasePlatform.other;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => ReleasePlatform.android,
    TargetPlatform.iOS => ReleasePlatform.ios,
    TargetPlatform.windows => ReleasePlatform.windows,
    TargetPlatform.macOS => ReleasePlatform.macOS,
    TargetPlatform.linux => ReleasePlatform.linux,
    TargetPlatform.fuchsia => ReleasePlatform.other,
  };
}

/// The architecture this platform's build is named for, used only to rank the
/// list — an Android device reports its own ABI, the desktop builds are x64 or
/// universal.
String preferredArch(ReleasePlatform platform) => switch (platform) {
  ReleasePlatform.windows => 'x64',
  ReleasePlatform.linux => 'x64',
  ReleasePlatform.macOS => 'universal',
  ReleasePlatform.ios => 'arm64',
  ReleasePlatform.android => 'arm64-v8a',
  ReleasePlatform.other => '',
};

int _kindRank(PackageKind kind) => switch (kind) {
  PackageKind.installer => 0,
  PackageKind.msix => 1,
  PackageKind.apk => 0,
  PackageKind.ipa => 0,
  PackageKind.dmg => 0,
  PackageKind.deb => 1,
  PackageKind.tarGz => 2,
  PackageKind.portable => 3,
  PackageKind.other => 9,
};

/// What a platform is called on the download page.
String releasePlatformLabel(Translations t, ReleasePlatform platform) => switch (platform) {
  ReleasePlatform.android => t.settings.releaseOsAndroid,
  ReleasePlatform.ios => t.settings.releaseOsIos,
  ReleasePlatform.windows => t.settings.releaseOsWindows,
  ReleasePlatform.macOS => t.settings.releaseOsMacos,
  ReleasePlatform.linux => t.settings.releaseOsLinux,
  ReleasePlatform.other => t.settings.releaseOsOther,
};

/// What a package kind is called on the download page.
String releaseKindLabel(Translations t, PackageKind kind) => switch (kind) {
  PackageKind.apk => t.settings.releaseKindApk,
  PackageKind.ipa => t.settings.releaseKindIpa,
  PackageKind.installer => t.settings.releaseKindInstaller,
  PackageKind.dmg => t.settings.releaseKindDmg,
  PackageKind.msix => t.settings.releaseKindMsix,
  PackageKind.deb => t.settings.releaseKindDeb,
  PackageKind.tarGz => t.settings.releaseKindTarGz,
  PackageKind.portable => t.settings.releaseKindPortable,
  PackageKind.other => t.settings.releaseKindOther,
};

/// The project's release page, for when a release carries no address.
String releasePageUrl(String version) {
  final tag = version.trim();
  if (tag.isEmpty) return '$versionProjectUrl/releases';
  return '$versionProjectUrl/releases/tag/${tag.startsWith('v') ? tag : 'v$tag'}';
}

/// A size in megabytes, the way a download page states it.
String formatReleaseSize(int bytes) => bytes <= 0 ? '—' : '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
