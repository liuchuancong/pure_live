import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile;

import 'package:pure_live/app/providers/network_providers.dart' show networkFactoryProvider;
import 'package:pure_live/features/version/app_version.dart';
import 'package:pure_live/features/version/update_feed.dart';

/// What the about page knows after a check: the newest release when it is
/// newer than this build, why the check failed, and whether one has run.
typedef VersionCheck = ({bool checking, UpdateInfo? latest, String? error, bool checked, String? installed});

VersionCheck _initial() => (checking: false, latest: null, error: null, checked: false, installed: null);

/// The manual update check: read this build's version, read the project's
/// release feed through the app's shared transport (so the proxy applies),
/// and keep the release only when it is genuinely newer. Nothing is
/// downloaded here; the page links to the release address.
final class VersionCheckController extends Notifier<VersionCheck> {
  @override
  VersionCheck build() => _initial();

  /// Runs the check once at a time; a second press while one is in flight
  /// is ignored.
  Future<void> check() async {
    if (state.checking) return;
    state = (checking: true, latest: null, error: null, checked: state.checked, installed: state.installed);
    try {
      final installed = await readInstalledVersion();
      final http = ref.read(networkFactoryProvider).create(profile: ClientProfile.api);
      final latest = await fetchUpdateInfo(http);
      if (!ref.mounted) return;
      state = (
        checking: false,
        latest: latest.isNewerThan(installed) ? latest : null,
        error: null,
        checked: true,
        installed: installed.version,
      );
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = (
        checking: false,
        latest: null,
        error: error is UpdateFeedException ? error.message : error.toString(),
        checked: true,
        installed: null,
      );
    }
  }
}

/// The manual update check's state.
final versionCheckProvider = NotifierProvider<VersionCheckController, VersionCheck>(VersionCheckController.new);
