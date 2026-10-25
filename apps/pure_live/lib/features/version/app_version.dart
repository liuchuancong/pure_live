import 'package:package_info_plus/package_info_plus.dart' show PackageInfo;

/// The installed build as the version check compares it.
typedef InstalledVersion = ({String version, int build});

/// Reads the installed version from the platform's package metadata; a
/// missing or unreadable build number counts as zero, which only ever makes
/// a release look newer, never older.
Future<InstalledVersion> readInstalledVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return (version: info.version.trim(), build: int.tryParse(info.buildNumber.trim()) ?? 0);
  } on Object {
    return (version: '', build: 0);
  }
}

/// The numeric parts of a dotted version: a leading `v` and anything after
/// `-` or `+` are ignored; null when a part is not a number.
List<int>? versionParts(String version) {
  final clean = version.trim().split(RegExp('[-+]')).first.replaceFirst(RegExp('^[vV]'), '').trim();
  if (clean.isEmpty) return null;
  final parts = <int>[];
  for (final part in clean.split('.')) {
    final value = int.tryParse(part);
    if (value == null) return null;
    parts.add(value);
  }
  return parts;
}

/// Whether [latest] names a newer version than [current]: part by part,
/// missing parts are zero, and an unreadable version is never newer.
bool isNewerVersion(String latest, String current) {
  final a = versionParts(latest);
  final b = versionParts(current);
  if (a == null || b == null) return false;
  for (var index = 0; index < a.length || index < b.length; index++) {
    final left = index < a.length ? a[index] : 0;
    final right = index < b.length ? b[index] : 0;
    if (left != right) return left > right;
  }
  return false;
}

/// Whether [latest] is this exact version (a `v` and a build suffix aside).
bool sameVersion(String latest, String current) {
  final a = versionParts(latest);
  final b = versionParts(current);
  return a != null && b != null && !isNewerVersion(latest, current) && !isNewerVersion(current, latest);
}
