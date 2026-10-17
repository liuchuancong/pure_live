import 'dart:async' show unawaited;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveCredential;
import 'package:pure_live/app/routing/routes/login/login_routes.dart';
import 'package:pure_live/features/login/login_providers.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The account page (`/settings/account`): who the app signs each site's
/// requests with.
///
/// One row per sign-in site: signed in it shows the account the login
/// granted (avatar, nickname, id) and the sign-out, which detaches the
/// credential from that site and removes the stored secret; signed out it
/// shows the way into the login page.
final class AccountPage extends ConsumerWidget {
  /// The account page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(signedInAccountsProvider);
    final t = context.t;
    return PureScaffold(
      appBar: PureAppBar(title: t.account.title),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final siteId in loginSites) ...[
            PureCard(
              padding: const EdgeInsets.all(20),
              child: switch (accounts[siteId]) {
                null => _SignedOutCard(siteId: siteId, onSignIn: () => const LoginRoute().push<void>(context)),
                final LiveCredential credential => _SignedInCard(siteId: siteId, credential: credential),
              },
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// The display name of a site's platform, as the account rows say it.
String _platformName(String siteId, Translations t) => switch (siteId) {
  'bilibili' => t.account.platformBilibili,
  'douyu' => t.account.platformDouyu,
  _ => t.account.platformHuya,
};

/// The signed-out half of one site's row: what the login is for, and the way
/// into it.
final class _SignedOutCard extends ConsumerWidget {
  const new({required this.siteId, required this.onSignIn});

  final String siteId;

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = PureTheme.of(context);
    final canSignIn = ref.watch(authCapabilityProvider(siteId)) != null;
    return Column(
      children: [
        PureAvatar(name: _platformName(siteId, context.t), size: 64),
        const SizedBox(height: 12),
        Text(_platformName(siteId, context.t), style: theme.text.title),
        const SizedBox(height: 6),
        Text(
          context.t.account.notSignedInHint,
          textAlign: TextAlign.center,
          style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
        ),
        const SizedBox(height: 16),
        PureButton(
          label: siteId == qrLoginSite ? context.t.settings.scanToLogin : context.t.settings.pasteCookie,
          icon: siteId == qrLoginSite ? Icons.qr_code_scanner_rounded : Icons.content_paste_rounded,
          onPressed: canSignIn ? onSignIn : null,
        ),
      ],
    );
  }
}

/// The signed-in half of one site's row: the account and the sign-out.
final class _SignedInCard extends ConsumerWidget {
  const new({required this.siteId, required this.credential});

  final String siteId;

  final LiveCredential credential;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = PureTheme.of(context);
    final nickname = credential.nickname;
    return Column(
      children: [
        PureAvatar(name: nickname, src: _avatarOf(credential.avatar), size: 64),
        const SizedBox(height: 12),
        Text(nickname ?? _platformName(siteId, context.t), style: theme.text.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Text(
          credential.userId == null
              ? _platformName(siteId, context.t)
              : context.t.account.userId(id: credential.userId!),
          style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
        ),
        const SizedBox(height: 16),
        PureButton(
          label: context.t.account.signOut,
          variant: ButtonVariant.danger,
          icon: Icons.logout_rounded,
          onPressed: () => unawaited(_confirmSignOut(context, ref)),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showPureDialog<bool>(
      context: context,
      title: context.t.account.signOutConfirm(site: _platformName(siteId, context.t)),
      child: Text(context.t.account.signOutHint),
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
    if (confirmed ?? false) {
      await ref.read(accountProvider(siteId).notifier).signOut();
    }
  }

  ImageProvider? _avatarOf(String? avatar) =>
      avatar == null || avatar.isEmpty ? null : CachedNetworkImageProvider(avatar);
}
