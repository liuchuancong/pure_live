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
import 'package:pure_live/features/settings/widgets/settings_sections.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The settings cluster's index page: the 3.x sectioned layout — a labelled
/// group per area, each a rounded card of icon + title + subtitle entry rows —
/// rebuilt on the uikit's rows.
///
/// A section appears with its feature wave: the reference ships one group per
/// settings sub-page, and this index carries the ones this build has backing
/// for, in the reference's order.
final class SettingsPage extends ConsumerWidget {
  /// The settings index.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return PureScaffold(
      appBar: PureAppBar(title: t.tabs.settings, actions: const [SettingsEntryButton()]),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const AccountSection(),
          const SettingsSectionGap(),
          SettingsSection.card(
            label: t.settings.sectionGeneral,
            tiles: [
              SettingsEntryTile(
                icon: Icons.tune_outlined,
                title: t.settings.general,
                subtitle: t.settings.generalSubtitle,
                onTap: () => const GeneralSettingsRoute().push<void>(context),
              ),
              SettingsEntryTile(
                icon: Icons.refresh_outlined,
                title: t.settings.refreshSettings,
                subtitle: t.settings.refreshSettingsSubtitle,
                onTap: () => const RefreshSettingsRoute().push<void>(context),
              ),
              SettingsEntryTile(
                icon: Icons.view_quilt_outlined,
                title: t.settings.pageSettings,
                subtitle: t.settings.pageSettingsSubtitle,
                onTap: () => const PageSettingsRoute().push<void>(context),
              ),
              SettingsEntryTile(
                icon: Icons.navigation_outlined,
                title: t.settings.navigationSettings,
                subtitle: t.settings.navigationSettingsSubtitle,
                onTap: () => const NavigationSettingsRoute().push<void>(context),
                divided: false,
              ),
            ],
          ),
          const SettingsSectionGap(),
          SettingsSection.card(
            label: t.settings.sectionTheme,
            tiles: [
              SettingsEntryTile(
                icon: Icons.palette_outlined,
                title: t.settings.appearance,
                subtitle: t.settings.appearanceSubtitle,
                onTap: () => const AppearanceRoute().push<void>(context),
              ),
              SettingsEntryTile(
                icon: Icons.font_download_outlined,
                title: t.settings.fonts,
                subtitle: t.settings.fontsSubtitle,
                onTap: () => const FontManagerRoute().push<void>(context),
                divided: false,
              ),
            ],
          ),
          const SettingsSectionGap(),
          SettingsSection.card(
            label: t.settings.sectionFeedDisplay,
            tiles: [
              SettingsEntryTile(
                icon: Icons.hourglass_top_outlined,
                title: t.settings.loadingStyle,
                subtitle: t.settings.loadingStyleSubtitle,
                onTap: () => const LoadingStyleSettingsRoute().push<void>(context),
              ),
              SettingsEntryTile(
                icon: Icons.dashboard_outlined,
                title: t.settings.roomCardSettings,
                subtitle: t.settings.roomCardSettingsSubtitle,
                onTap: () => const RoomCardSettingsRoute().push<void>(context),
                divided: false,
              ),
            ],
          ),
          const SettingsSectionGap(),
          SettingsSection.card(
            label: t.settings.sectionNetwork,
            tiles: [
              SettingsEntryTile(
                icon: Icons.vpn_key_outlined,
                title: t.settings.proxySettings,
                subtitle: t.settings.proxySettingsSubtitle,
                onTap: () => const NetworkProxySettingsRoute().push<void>(context),
                divided: false,
              ),
            ],
          ),
          const SettingsSectionGap(),
          SettingsSection.card(
            label: t.settings.sectionRecorder,
            tiles: [
              SettingsEntryTile(
                icon: Icons.video_settings_outlined,
                title: t.recorder.title,
                subtitle: t.settings.recorderSubtitle,
                onTap: () => const RecorderRoute().push<void>(context),
                divided: false,
              ),
            ],
          ),
          const SettingsSectionGap(),
          SettingsSection.card(
            label: t.settings.sectionIptv,
            tiles: [
              SettingsEntryTile(
                icon: Icons.dns_outlined,
                title: t.iptv.title,
                subtitle: t.settings.iptvSubtitle,
                onTap: () => const IptvRoute().push<void>(context),
                divided: false,
              ),
            ],
          ),
          const SettingsSectionGap(),
          SettingsSection.card(
            label: t.settings.sectionDanmaku,
            tiles: [
              SettingsEntryTile(
                icon: Icons.shield_outlined,
                title: t.shield.title,
                subtitle: t.settings.shieldSubtitle,
                onTap: () => const ShieldRoute().push<void>(context),
                divided: false,
              ),
            ],
          ),
          const SettingsSectionGap(),
          SettingsSection.card(
            label: t.settings.sectionData,
            tiles: [
              SettingsEntryTile(
                icon: Icons.storage_outlined,
                title: t.settings.cacheAndData,
                subtitle: t.settings.cacheAndDataSubtitle,
                onTap: () => const CacheDataRoute().push<void>(context),
                divided: false,
              ),
            ],
          ),
          const SettingsSectionGap(),
          SettingsSection.card(
            label: t.settings.sectionBackup,
            tiles: [
              SettingsEntryTile(
                icon: Icons.backup_outlined,
                title: t.backup.title,
                subtitle: t.settings.backupSubtitle,
                onTap: () => const BackupRoute().push<void>(context),
              ),
              SettingsEntryTile(
                icon: Icons.sync_outlined,
                title: t.settings.remoteSync,
                subtitle: t.settings.remoteSyncSubtitle,
                // The remote-sync route is declared by hand (no typed class);
                // its path constant is the address.
                onTap: () => context.push<void>(RoutePath.remoteSync),
                divided: false,
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// The settings index's account entry, the reference's account card: the
/// signed-in account's avatar and name once a login landed, the bilibili QR
/// sign-in invitation before it. Either way the row opens the account page.
final class AccountSection extends ConsumerWidget {
  /// The account section.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    return SettingsSection.card(
      label: context.t.settings.sectionAccount,
      tiles: [
        switch (account) {
          null => SettingsEntryTile(
            icon: Icons.person_outline_rounded,
            title: context.t.settings.scanToLogin,
            subtitle: context.t.settings.accountSubtitle,
            onTap: () => const AccountRoute().push<void>(context),
          ),
          final LiveCredential credential => PureListRow(
            leading: _AccountAvatar(credential: credential),
            title: credential.nickname ?? context.t.account.title,
            subtitle: credential.userId == null
                ? context.t.settings.accountSubtitle
                : context.t.account.userId(id: credential.userId!),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => const AccountRoute().push<void>(context),
          ),
        },
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
