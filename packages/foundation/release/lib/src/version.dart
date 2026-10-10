// Module: lib/src/version.dart
// Purpose: Version parsing, comparison and the update decision the release channel is judged by.
// Author: liuchuancong
// Created: 2026-10-08
//
// A build number is not decoration: this repository ships the same semantic version across several
// platforms and orders candidates by build, so comparing versions as strings or as semver alone picks the
// wrong package. The split-per-ABI rule below is the trap BUILD_POLICY.md warns about, encoded once.

/// A released version: three semantic parts, an optional pre-release tag, plus a numeric build.
final class AppVersion implements Comparable<AppVersion> {
  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.build,
    this.preRelease = '',
  });

  /// Parses `4.0.0+5000`, `4.0.0` or `4.1.0-beta.1+5100`. A missing build is zero, not unknown.
  ///
  /// Throws [FormatException] with the offending text when a part is not a number, because a silently
  /// defaulted version would make an update check pass against the wrong build.
  factory AppVersion.parse(String text) {
    final trimmed = text.trim();
    final parts = trimmed.split('+');
    final coreAndPre = parts.first;
    // The hyphen that opens a pre-release tag is the first one after the third dot, not any hyphen: a build
    // name like `4.0.0-rc+1` would otherwise be read as a two-part version and refused.
    final hyphen = coreAndPre.indexOf('-');
    final numbers = (hyphen < 0 ? coreAndPre : coreAndPre.substring(0, hyphen)).split('.');
    if (numbers.length != 3 || numbers.any((part) => int.tryParse(part) == null)) {
      throw FormatException('not a major.minor.patch version', text);
    }
    final build = parts.length > 1 ? parts[1] : '0';
    if (build.isNotEmpty && int.tryParse(build) == null) {
      throw FormatException('build number is not an integer', text);
    }
    final pre = hyphen < 0 ? '' : coreAndPre.substring(hyphen + 1);
    if (pre.isNotEmpty && !RegExp(r'^[0-9A-Za-z.-]+$').hasMatch(pre)) {
      throw FormatException('pre-release tag is not dot-separated alphanumerics', text);
    }
    return AppVersion(
      major: int.parse(numbers[0]),
      minor: int.parse(numbers[1]),
      patch: int.parse(numbers[2]),
      build: int.parse(build.isEmpty ? '0' : build),
      preRelease: pre,
    );
  }

  /// Null when [text] is not a version, instead of throwing.
  static AppVersion? tryParse(String? text) {
    if (text == null || text.trim().isEmpty) {
      return null;
    }
    try {
      return AppVersion.parse(text);
    } on FormatException {
      return null;
    }
  }

  final int major;
  final int minor;
  final int patch;

  /// The numeric build code; the tie-breaker when two platforms share a semantic version.
  final int build;

  /// `beta.1` for `4.1.0-beta.1`, empty for a stable release.
  ///
  /// A pre-release sorts **before** the release it leads up to (semver 2.0.0 rule 11), so a stable track that
  /// ignores it does not offer `4.1.0-beta.1` to a user on `4.0.0` and call that an upgrade.
  final String preRelease;

  bool get isPreRelease => preRelease.isNotEmpty;

  /// `4.0.0` or `4.1.0-beta.1`, for display.
  String get display => isPreRelease ? '$major.$minor.$patch-$preRelease' : '$major.$minor.$patch';

  /// `4.0.0+5000`, the form pubspec.yaml and the artifact names use.
  String get full => build == 0 ? display : '$display+$build';

  /// The same version without its pre-release tag, for a stable track's candidate list.
  AppVersion get stableCore => AppVersion(major: major, minor: minor, patch: patch, build: build);

  /// The build code the Android manifest actually carries for an ABI-split release.
  ///
  /// `--split-per-abi` adds 2000 to the arm64 `versionCode`, so a gate that compares the pubspec build
  /// against the manifest value sees a mismatch on a good artifact. Both numbers must be checked, which is
  /// why this lives in code rather than in a comment.
  static int manifestBuildForArm64(int baseBuild, {bool splitPerAbi = true}) =>
      splitPerAbi ? baseBuild + 2000 : baseBuild;

  @override
  int compareTo(AppVersion other) {
    final bySemver = _compareTriple(other);
    if (bySemver != 0) {
      return bySemver;
    }
    // Rule 11: a pre-release has lower precedence than the associated normal version, and a build metadata
    // string is ignored for precedence - but this repository orders by build across platforms, so the build
    // is only consulted once both sides are equally stable.
    if (isPreRelease && !other.isPreRelease) {
      return -1;
    }
    if (!isPreRelease && other.isPreRelease) {
      return 1;
    }
    if (isPreRelease && other.isPreRelease) {
      final byTag = _compareIdentifiers(preRelease, other.preRelease);
      if (byTag != 0) {
        return byTag;
      }
    }
    return build.compareTo(other.build);
  }

  int _compareTriple(AppVersion other) {
    for (final pair in <(int, int)>[(major, other.major), (minor, other.minor), (patch, other.patch)]) {
      final result = pair.$1.compareTo(pair.$2);
      if (result != 0) {
        return result;
      }
    }
    return 0;
  }

  /// Dot-separated pre-release identifiers compared semver's way: numeric identifiers numerically and always
  /// lower than an alphanumeric one, shorter field sets lower when all their fields match.
  static int _compareIdentifiers(String left, String right) {
    final a = left.split('.');
    final b = right.split('.');
    final shared = a.length < b.length ? a.length : b.length;
    for (var index = 0; index < shared; index++) {
      final x = a[index];
      final y = b[index];
      final xn = int.tryParse(x);
      final yn = int.tryParse(y);
      if (xn != null && yn != null) {
        final result = xn.compareTo(yn);
        if (result != 0) {
          return result;
        }
        continue;
      }
      if (xn != null) {
        return -1;
      }
      if (yn != null) {
        return 1;
      }
      final result = x.compareTo(y);
      if (result != 0) {
        return result;
      }
    }
    return a.length.compareTo(b.length);
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;

  bool operator <=(AppVersion other) => compareTo(other) <= 0;

  bool operator >(AppVersion other) => compareTo(other) > 0;

  bool operator >=(AppVersion other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) => other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, build, preRelease);

  @override
  String toString() => full;
}

/// What the update check concluded.
enum UpdateAction {
  /// Stay on the current build.
  none,

  /// A newer build exists; the user decides.
  available,

  /// The current build is below the minimum supported one; the update is not optional.
  forced,
}

/// The outcome of comparing an installed app against a release feed.
final class UpdateDecision {
  const UpdateDecision({required this.action, required this.current, this.latest, this.reason});

  final UpdateAction action;
  final AppVersion current;

  /// The newest version the feed offered, when there is one.
  final AppVersion? latest;

  /// Why this decision, for the update dialog and for logs.
  final String? reason;

  bool get shouldUpdate => action != UpdateAction.none;
}

/// Decides whether [current] should move to [latest].
///
/// A release below [minimumSupported] is forced even when [latest] is only a build bump, because staying
/// would keep a client pointed at a protocol it can no longer satisfy.
UpdateDecision decideUpdate({required AppVersion current, AppVersion? latest, AppVersion? minimumSupported}) {
  if (minimumSupported != null && current < minimumSupported) {
    return UpdateDecision(
      action: UpdateAction.forced,
      current: current,
      latest: latest ?? minimumSupported,
      reason: 'below the minimum supported version ${minimumSupported.full}',
    );
  }
  if (latest == null) {
    return UpdateDecision(action: UpdateAction.none, current: current);
  }
  if (latest > current) {
    return UpdateDecision(
      action: UpdateAction.available,
      current: current,
      latest: latest,
      reason: 'a newer build is published',
    );
  }
  return UpdateDecision(action: UpdateAction.none, current: current, latest: latest);
}
