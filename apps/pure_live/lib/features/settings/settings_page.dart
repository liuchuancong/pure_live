import 'dart:async' show unawaited;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:live_sites/live_sites.dart' show LiveCredential;
import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/app/routing/routes/backup/backup_routes.dart';
import 'package:pure_live/app/routing/routes/iptv/iptv_routes.dart';
import 'package:pure_live/app/routing/routes/login/login_routes.dart';
import 'package:pure_live/app/routing/routes/settings/settings_routes.dart';
import 'package:pure_live/app/routing/routes/settings/shield_routes.dart';
import 'package:pure_live/features/login/login_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_rows.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The settings cluster's index, written as one declarative tree.
///
/// This is `pure_settings_ui`'s `SettingsList`: a section is a titled group of
/// tiles and a tile is a row, so the index re-skins with the rest of the app —
/// Android's cards under Material, iOS grouped cards under Cupertino, the Windows
/// 11 Settings list under Fluent, libadwaita's boxed rows under Yaru — instead of
/// carrying one hand-drawn card layout that only ever looked like Material.
///
/// Each row still pushes the app's own typed route rather than a
/// `SettingsDestination`, because the pages are routable from elsewhere too (the
/// rail menu, the room's overflow) and a destination held inside this widget
/// would make those entries second-class.
final class SettingsPage extends ConsumerWidget {
  /// The settings index.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return PureScaffold(
      // No settings action here: this *is* the settings page. The reference
      // puts the local-config preview in this slot; it is a row below, which
      // keeps it reachable from a keyboard as well as the bar.
      appBar: PureAppBar(title: t.tabs.settings),
      body: SettingsList(
        sections: [
          _account(context, ref),
          SettingsSection(
            title: Text(t.settings.sectionGeneral),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.tune_outlined),
                title: Text(t.settings.general),
                description: Text(t.settings.generalSubtitle),
                onPressed: (_) => unawaited(const GeneralSettingsRoute().push<void>(context)),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.refresh_outlined),
                title: Text(t.settings.refreshSettings),
                description: Text(t.settings.refreshSettingsSubtitle),
                onPressed: (_) => unawaited(const RefreshSettingsRoute().push<void>(context)),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.view_quilt_outlined),
                title: Text(t.settings.pageSettings),
                description: Text(t.settings.pageSettingsSubtitle),
                onPressed: (_) => unawaited(const PageSettingsRoute().push<void>(context)),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.navigation_outlined),
                title: Text(t.settings.navigationSettings),
                description: Text(t.settings.navigationSettingsSubtitle),
                onPressed: (_) => unawaited(const NavigationSettingsRoute().push<void>(context)),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.sectionVideo),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.play_circle_outline),
                title: Text(t.settings.video),
                description: Text(t.settings.videoSubtitle),
                onPressed: (_) => unawaited(const VideoSettingsRoute().push<void>(context)),
              ),
              // The reference's mpv option pages, reached from the same section
              // as the video defaults.
              SettingsTile.navigation(
                leading: const Icon(Icons.tune_outlined),
                title: Text(t.settings.mpvTuning),
                description: Text(t.settings.mpvTuningSubtitle),
                onPressed: (_) => unawaited(const MpvSettingsRoute().push<void>(context)),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.description_outlined),
                title: Text(t.settings.localConfig),
                description: Text(t.settings.localConfigSubtitle),
                onPressed: (_) => unawaited(const LocalConfigPreviewRoute().push<void>(context)),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.sectionTheme),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.palette_outlined),
                title: Text(t.settings.appearance),
                description: Text(t.settings.appearanceSubtitle),
                onPressed: (_) => unawaited(const AppearanceRoute().push<void>(context)),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.font_download_outlined),
                title: Text(t.settings.fonts),
                description: Text(t.settings.fontsSubtitle),
                onPressed: (_) => unawaited(const FontManagerRoute().push<void>(context)),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.sectionFeedDisplay),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.hourglass_top_outlined),
                title: Text(t.settings.loadingStyle),
                description: Text(t.settings.loadingStyleSubtitle),
                onPressed: (_) => unawaited(const LoadingStyleSettingsRoute().push<void>(context)),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.dashboard_outlined),
                title: Text(t.settings.roomCardSettings),
                description: Text(t.settings.roomCardSettingsSubtitle),
                onPressed: (_) => unawaited(const RoomCardSettingsRoute().push<void>(context)),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.sectionNetwork),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.vpn_key_outlined),
                title: Text(t.settings.proxySettings),
                description: Text(t.settings.proxySettingsSubtitle),
                onPressed: (_) => unawaited(const NetworkProxySettingsRoute().push<void>(context)),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.sectionRecorder),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.video_settings_outlined),
                title: Text(t.recorder.title),
                description: Text(t.settings.recorderSubtitle),
                onPressed: (_) => unawaited(const RecorderSettingsRoute().push<void>(context)),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.sectionIptv),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.dns_outlined),
                title: Text(t.iptv.title),
                description: Text(t.settings.iptvSubtitle),
                onPressed: (_) => unawaited(const IptvRoute().push<void>(context)),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.sectionDanmaku),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.shield_outlined),
                title: Text(t.shield.title),
                description: Text(t.settings.shieldSubtitle),
                onPressed: (_) => unawaited(const ShieldRoute().push<void>(context)),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.sectionData),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.storage_outlined),
                title: Text(t.settings.cacheAndData),
                description: Text(t.settings.cacheAndDataSubtitle),
                onPressed: (_) => unawaited(const CacheDataRoute().push<void>(context)),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.sectionBackup),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.backup_outlined),
                title: Text(t.backup.title),
                description: Text(t.settings.backupSubtitle),
                onPressed: (_) => unawaited(const BackupRoute().push<void>(context)),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.sync_outlined),
                title: Text(t.settings.remoteSync),
                description: Text(t.settings.remoteSyncSubtitle),
                // The remote-sync route is declared by hand (no typed class);
                // its path constant is the address.
                onPressed: (_) => unawaited(context.push<void>(RoutePath.remoteSync)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The account section: the signed-in accounts' summary once a login landed
  /// anywhere, the sign-in invitation before it. The avatar row is the app's
  /// own — a tile kit has no notion of a picture, and this one is the account's
  /// identity, not decoration.
  SettingsSection _account(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(signedInAccountsProvider);
    if (accounts.isEmpty) {
      return SettingsSection(
        title: Text(context.t.settings.sectionAccount),
        tiles: [
          SettingsTile.navigation(
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(context.t.settings.scanToLogin),
            description: Text(context.t.settings.accountSubtitle),
            onPressed: (_) => unawaited(const AccountRoute().push<void>(context)),
          ),
        ],
      );
    }
    final first = accounts.values.first;
    return SettingsSection(
      title: Text(context.t.settings.sectionAccount),
      tiles: [
        SettingsRowTile(
          row: PureListRow(
            leading: _AccountAvatar(credential: first),
            title: first.nickname ?? context.t.account.title,
            subtitle: accounts.length > 1
                ? context.t.settings.accountSignedInCount(count: accounts.length)
                : first.userId == null
                ? context.t.settings.accountSubtitle
                : context.t.account.userId(id: first.userId!),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => unawaited(const AccountRoute().push<void>(context)),
          ),
        ),
      ],
    );
  }
}

/// The account row's leading avatar, initials when the login named no picture.
final class _AccountAvatar extends StatelessWidget {
  const new({required this.credential});

  final LiveCredential credential;

  @override
  Widget build(BuildContext context) {
    final avatar = credential.avatar;
    return PureAvatar(
      name: credential.nickname,
      size: 32,
      src: avatar == null || avatar.isEmpty ? null : CachedNetworkImageProvider(avatar),
    );
  }
}
