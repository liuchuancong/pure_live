import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pure_live/app/app_providers.dart';
import 'package:pure_live/features/about/update_feed.dart';

/// One read of the version facts: the running build, the fetched releases,
/// the check's progress and its failure, if any.
final class VersionState {
  /// The state.
  const new({this.packageInfo, this.releases = const [], this.checking = false, this.error});

  /// The running build's facts, null until the first check read them.
  final PackageInfo? packageInfo;

  /// The fetched releases, newest first; empty before the first success.
  final List<AppRelease> releases;

  /// Whether a check is running.
  final bool checking;

  /// Why the last check failed; null after a check that succeeded. A new
  /// check clears it up front.
  final Object? error;

  /// Whether the newest release is newer than the running build.
  bool get hasUpdate {
    final version = packageInfo?.version;
    if (version == null || releases.isEmpty || !releases.first.hasVersion) {
      return false;
    }
    try {
      final latest = Version.parse(releases.first.tag.replaceFirst(RegExp('^[vV]'), ''));
      final running = Version.parse(version);
      return latest > running;
    } on Object {
      return false;
    }
  }

  /// The next state; [error] replaces unconditionally, so passing null
  /// clears a previous failure.
  VersionState copyWith({PackageInfo? packageInfo, List<AppRelease>? releases, bool? checking, Object? error}) =>
      VersionState(
        packageInfo: packageInfo ?? this.packageInfo,
        releases: releases ?? this.releases,
        checking: checking ?? this.checking,
        error: error,
      );
}

/// The version page's state holder (3.x `VersionController`): the update
/// check over the app's shared [updateFeedProvider], on the riverpod graph
/// the rest of the app uses.
///
/// The reference drove a download pipeline from the same check; this app
/// ships none — the page's update action opens the release's page instead
/// (app_update_flow), so the check only needs to gather the feed.
final class VersionController extends Notifier<VersionState> {
  bool _checking = false;

  @override
  VersionState build() {
    // The reference's onInit: the page opens on a check already running.
    // The microtask keeps the first mutation out of the build itself.
    unawaited(Future<void>.microtask(check));
    return const VersionState();
  }

  /// Reads the running build and the release feed. A re-entry while a check
  /// runs is a no-op; a failure keeps the last good state and surfaces the
  /// error.
  Future<void> check() async {
    if (_checking) {
      return;
    }
    _checking = true;
    // A new check starts from a fresh verdict, keeping the last good data.
    state = VersionState(packageInfo: state.packageInfo, releases: state.releases, checking: true);
    try {
      final info = await PackageInfo.fromPlatform();
      final fetched = await ref.read(updateFeedProvider).fetch();
      state = state.copyWith(packageInfo: info, releases: fetched, checking: false);
    } on Object catch (error) {
      state = state.copyWith(checking: false, error: error);
    } finally {
      _checking = false;
    }
  }
}

/// The version page's controller.
final versionControllerProvider = NotifierProvider<VersionController, VersionState>(VersionController.new);
