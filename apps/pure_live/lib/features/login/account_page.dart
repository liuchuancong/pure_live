import 'dart:async' show unawaited;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveCredential, LiveSite;
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/features/login/login_providers.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The account page (`/settings/account`): who the app signs each site's
/// requests with.
///
/// The reference's hub shape (`account_page.dart:16-231`): one card of rows, each
/// a leading mark, the platform's name, a state line and a trailing control that
/// is a sign-out once a credential is live; a second card carries the destructive
/// clear-everything, inert while no site holds one.
///
/// Two things differ from the reference on purpose. The rows come from the site
/// registry's auth capabilities rather than a hardcoded list of nine platforms —
/// this build ships the three that have adapters today, and a platform that grows
/// a login appears here by itself. And the page is written as one
/// `pure_settings_ui` tree, so it re-skins with the rest of the settings cluster.
final class AccountPage extends ConsumerWidget {
  /// The account page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(authSitesProvider);
    final accounts = ref.watch(signedInAccountsProvider);
    final t = context.t;
    return PureScaffold(
      appBar: PureAppBar(title: t.account.title),
      body: SettingsList(
        sections: [
          SettingsSection(
            tiles: [
              if (sites.isEmpty)
                SettingsTile(title: Text(t.account.noAuthSites), description: Text(t.account.notSignedInHint))
              else
                for (final site in sites) _row(context, ref, site, accounts[site.manifest.id]),
            ],
          ),
          SettingsSection(
            tiles: [
              SettingsTile.navigation(
                leading: Icon(
                  Icons.delete_sweep_outlined,
                  color: accounts.isEmpty ? null : PureTheme.of(context).colors.error,
                ),
                title: Text(t.account.clearAllAccounts),
                description: Text(t.account.clearAllAccountsHint),
                enabled: accounts.isNotEmpty,
                onPressed: (_) => unawaited(_confirmClearAll(context, ref)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// One platform's row. Every row points at the platform's own page: the
  /// cookie editor for the paste sites (signed in or not — the editor opens
  /// on its stored credential), the QR login for the scan site. The
  /// reference keeps the same split (`account_page.dart` dispatches to
  /// `CookieEditorScaffold` per platform).
  AbstractSettingsTile _row(BuildContext context, WidgetRef ref, LiveSite site, LiveCredential? credential) {
    final t = context.t;
    final name = _siteName(site, context);
    final signedIn = credential != null;
    final state = switch (credential) {
      null => t.account.notSignedInHint,
      final LiveCredential value when value.nickname != null && value.nickname!.isNotEmpty => value.nickname!,
      final LiveCredential value => t.account.userId(id: value.userId ?? value.siteId),
    };
    return SettingsTile.navigation(
      leading: PureAvatar(
        name: credential?.nickname ?? name,
        src: credential == null ? null : _imageOf(credential.avatar),
        size: 32,
      ),
      title: Text(name),
      // The value column is where the reference puts the live state, and it is
      // the line that changes when a login lands — not a description of the row.
      value: Text(state),
      trailing: signedIn
          ? Icon(Icons.logout_rounded, color: PureTheme.of(context).colors.error)
          : const Icon(Icons.chevron_right_rounded),
      onPressed: (_) => unawaited(
        siteUsesQrLogin(site.manifest.id)
            ? const LoginRoute().push<void>(context)
            : AccountCookieRoute(siteId: site.manifest.id).push<void>(context),
      ),
    );
  }

  static Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showPureDialog<bool>(
      context: context,
      title: context.t.account.clearAllAccounts,
      child: Text(context.t.account.clearAllAccountsHint),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PureButton(
          label: dialogContext.t.account.signOut,
          variant: ButtonVariant.danger,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (!(confirmed ?? false)) {
      return;
    }
    // One sign-out per site, awaited: the reference wraps the same sequence in a
    // single logout transaction so a half-cleared list never renders.
    for (final site in ref.read(authSitesProvider)) {
      await ref.read(accountProvider(site.manifest.id).notifier).signOut();
    }
  }
}

/// The platform's own display name, in the language the app is showing. The
/// manifest carries it, so a new platform needs no row of literals here.
String _siteName(LiveSite site, BuildContext context) =>
    site.manifest.localizedName(Localizations.localeOf(context).toLanguageTag(), 'zh-CN');

ImageProvider? _imageOf(String? url) {
  final value = url?.trim() ?? '';
  return value.isEmpty ? null : CachedNetworkImageProvider(value);
}
