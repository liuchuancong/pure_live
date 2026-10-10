// Module: lib/src/channels.dart
// Purpose: Which release a track may offer, and which file inside it a device should download.
// Author: liuchuancong
// Created: 2026-10-11
//
// Two decisions the feed parser could not make. A stable build must not be offered a beta just because it is
// newer, and "the APK for this release" is not one file: an ABI-split release carries arm64-v8a, armeabi-v7a
// and x86_64 installers whose names differ only by the ABI, and installing the wrong one is a signature
// mismatch on the user's home screen. The Windows side has the same shape with MSIX against the plain exe
// against the portable folder - a choice that also decides where the app's data ends up.

import 'update_feed.dart';
import 'version.dart';

/// Which feed entries a running build may be offered.
enum ReleaseTrack {
  /// Stable releases only.
  stable,

  /// Stable plus beta and release-candidate tags.
  beta,

  /// Everything the feed carries, including nightly tags.
  nightly,
}

extension ReleaseTrackRules on ReleaseTrack {
  /// Whether [version] belongs to this track.
  bool allows(AppVersion version) {
    if (!version.isPreRelease) {
      return true;
    }
    final tag = version.preRelease.toLowerCase();
    return switch (this) {
      ReleaseTrack.stable => false,
      ReleaseTrack.beta => tag.startsWith('beta') || tag.startsWith('rc'),
      ReleaseTrack.nightly => true,
    };
  }

  /// The tag a build must carry to *stay* on this track: a build that switches tracks should not keep
  /// believing a newer prerelease is a downgrade.
  bool acceptsBuildTag(String tag) {
    if (tag.isEmpty) {
      return true;
    }
    final lower = tag.toLowerCase();
    return switch (this) {
      ReleaseTrack.stable => false,
      ReleaseTrack.beta => lower.startsWith('beta') || lower.startsWith('rc'),
      ReleaseTrack.nightly => true,
    };
  }
}

/// The newest entry [track] may offer to [current].
///
/// A skipped candidate is counted rather than dropped silently: a feed whose newest row is a beta the stable
/// track refuses looks, from the user's side, exactly like having no update at all.
ReleaseCandidate selectRelease(
  Iterable<ReleaseEntry> entries, {
  required ReleaseTrack track,
  required AppVersion current,
}) {
  ReleaseEntry? newest;
  var skipped = 0;
  for (final entry in entries) {
    if (!track.allows(entry.version)) {
      skipped++;
      continue;
    }
    if (newest == null || entry.version > newest.version) {
      newest = entry;
    }
  }
  final decision = decideUpdate(current: current, latest: newest?.version);
  return ReleaseCandidate(
    entry: newest,
    track: track,
    current: current,
    decision: decision,
    skippedOutsideTrack: skipped,
  );
}

/// What a track selection concluded.
final class ReleaseCandidate {
  const ReleaseCandidate({
    required this.entry,
    required this.track,
    required this.current,
    required this.decision,
    required this.skippedOutsideTrack,
  });

  final ReleaseEntry? entry;
  final ReleaseTrack track;
  final AppVersion current;
  final UpdateDecision decision;

  /// Feed rows the track refused. Non-zero means "there is a newer release you are not eligible for", which is
  /// worth one line in the about screen and nothing more.
  final int skippedOutsideTrack;

  bool get hasUpdate => entry != null && decision.action != UpdateAction.none;

  @override
  String toString() =>
      'ReleaseCandidate(${track.name}, current=$current, newest=${entry?.version ?? '-'}'
      '${skippedOutsideTrack > 0 ? ', skipped $skippedOutsideTrack' : ''})';
}

/// The Android ABI a device runs.
enum ApkAbi { arm64V8a, armeabiV7a, x86_64, x86, universal }

extension ApkAbiNames on ApkAbi {
  /// The substring the artifact name carries for this ABI. Universal has none, which is why the picker treats
  /// it as the fallback rather than as a pattern.
  String? get nameTag {
    return switch (this) {
      ApkAbi.arm64V8a => 'arm64-v8a',
      ApkAbi.armeabiV7a => 'armeabi-v7a',
      ApkAbi.x86_64 => 'x86_64',
      ApkAbi.x86 => 'x86',
      ApkAbi.universal => null,
    };
  }
}

/// Why an asset was not selected.
enum AssetSelectionFailure {
  /// The release carries nothing for this platform.
  nothingForPlatform,

  /// Files exist but none matches the requested ABI or flavour.
  noMatch,
}

/// The installer an update prompt should offer for one device ABI.
///
/// The name match is a substring search over the artifact name, which is what a GitHub release actually
/// publishes; the fallback order is exact ABI, then `universal`, then nothing. Handing an armeabi-v7a installer
/// to an arm64 device is not a slower install - it is a signature mismatch against the app already there.
ReleaseAsset? selectApk(Iterable<ReleaseAsset> assets, {required ApkAbi abi}) {
  final all = assets.where((asset) => asset.name.toLowerCase().endsWith('.apk')).toList(growable: false);
  if (all.isEmpty) {
    return null;
  }
  final tag = abi.nameTag;
  if (tag == null) {
    final universal = all
        .where((asset) {
          final lower = asset.name.toLowerCase();
          return !ApkAbi.values.any((candidate) => candidate.nameTag != null && lower.contains(candidate.nameTag!));
        })
        .toList(growable: false);
    return universal.isEmpty ? all.first : universal.first;
  }
  final exact = all.where((asset) => asset.name.toLowerCase().contains(tag)).toList(growable: false);
  if (exact.isNotEmpty) {
    return exact.first;
  }
  // A universal build also satisfies the device; an unrelated ABI's build does not.
  final universal = all
      .where((asset) {
        final lower = asset.name.toLowerCase();
        return !ApkAbi.values.any((candidate) => candidate.nameTag != null && lower.contains(candidate.nameTag!));
      })
      .toList(growable: false);
  return universal.isEmpty ? null : universal.first;
}

/// How a Windows build is delivered, which also decides where its data lives.
enum WindowsFlavor {
  /// MSIX: installed under `%LOCALAPPDATA%\Packages\<PFN>`, self-updating, sandboxed storage.
  msix,

  /// A plain exe installer: classic Program Files layout, user data in AppData.
  installer,

  /// A zip folder the user moves: data travels with the executable when the portable marker is set.
  portable,
}

/// The Windows artifact of [flavour] inside [assets].
///
/// The requested flavour wins outright; without one the order is MSIX, installer, portable - the least
/// surprising for a user who installed the app the normal way, and a portable build never overwrites a
/// packaged install.
ReleaseAsset? selectWindowsAsset(Iterable<ReleaseAsset> assets, {WindowsFlavor? flavour}) {
  final byFlavour = <WindowsFlavor, List<String>>{
    WindowsFlavor.msix: <String>['.msix'],
    WindowsFlavor.installer: <String>['setup', 'installer'],
    WindowsFlavor.portable: <String>['portable'],
  };
  final wanted = flavour == null ? null : byFlavour[flavour]!;
  for (final asset in assets) {
    final lower = asset.name.toLowerCase();
    if (!lower.contains('windows') && !lower.endsWith('.exe') && !lower.endsWith('.msix') && !lower.endsWith('.zip')) {
      continue;
    }
    if (wanted != null && wanted.any(lower.contains)) {
      return asset;
    }
  }
  if (flavour != null) {
    return null;
  }
  final all = assets.toList(growable: false);
  return _firstWhere(all, (asset) => asset.name.toLowerCase().endsWith('.msix')) ??
      _firstWhere(all, (asset) {
        final lower = asset.name.toLowerCase();
        return lower.contains('setup') || lower.contains('installer');
      }) ??
      _firstWhere(all, (asset) => asset.name.toLowerCase().endsWith('.exe')) ??
      _firstWhere(all, (asset) => asset.name.toLowerCase().contains('portable')) ??
      _firstWhere(all, (asset) => asset.name.toLowerCase().endsWith('.zip'));
}

/// The first element matching [test], or null. `package:collection`'s firstOrNull is not a
/// dependency here, and this file must not need one.
T? _firstWhere<T>(List<T> items, bool Function(T item) test) {
  for (final item in items) {
    if (test(item)) {
      return item;
    }
  }
  return null;
}
