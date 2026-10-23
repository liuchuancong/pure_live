import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show StatefulNavigationShell;

import 'package:pure_live/app/environment/device_profile.dart' show DeviceProfile, deviceProfileProvider;
import 'package:pure_live/app/environment/layout_profile.dart' show LayoutProfile;
import 'package:pure_live/app/shell/desktop/desktop_shell.dart' show DesktopShell;
import 'package:pure_live/app/shell/mobile/mobile_shell.dart' show MobileShell;
import 'package:pure_live/app/shell/tablet/tablet_shell.dart' show TabletShell;
import 'package:pure_live/app/shell/tv/tv_shell.dart' show TvShell;

/// The shell's fork: one indexed-stack navigation shell, four devices.
///
/// The device profile picks the shell, the layout profile tunes it; the
/// branches themselves stay identical, so a device change never rebuilds
/// the pages under the shell.
final class AppShell extends ConsumerWidget {
  /// A shell around [shell].
  const new({required this.shell, super.key});

  /// The indexed-stack shell the router built.
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProfileProvider);
    final width = MediaQuery.sizeOf(context).width;
    return switch (device) {
      DeviceProfile.tv => TvShell(shell: shell),
      DeviceProfile.mobile => MobileShell(shell: shell),
      DeviceProfile.tablet => TabletShell(shell: shell),
      DeviceProfile.desktop => DesktopShell(shell: shell, profile: LayoutProfile.fromWidth(width)),
    };
  }
}
