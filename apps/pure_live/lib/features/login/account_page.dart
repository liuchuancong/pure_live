import 'dart:async' show unawaited;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveCredential;
import 'package:pure_live/app/routing/routes/login/login_routes.dart';
import 'package:pure_live/features/login/login_providers.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The account page (`/settings/account`): who the app signs its bilibili
/// requests with.
///
/// Signed out it is one call to action — the QR login. Signed in it shows the
/// account the login granted (avatar, nickname, id) and the sign-out, which
/// detaches the credential from the site and removes the stored secret.
final class AccountPage extends ConsumerWidget {
  /// The account page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    final t = context.t;
    return PureScaffold(
      appBar: PureAppBar(title: t.account.title),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          PureCard(
            padding: const EdgeInsets.all(20),
            child: switch (account) {
              null => _SignedOutCard(onSignIn: () => const LoginRoute().push<void>(context)),
              final LiveCredential credential => _SignedInCard(credential: credential),
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// The signed-out half: what the login is for, and the way into it.
final class _SignedOutCard extends StatelessWidget {
  const new({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return Column(
      children: [
        PureAvatar(name: context.t.account.notSignedIn, size: 64),
        const SizedBox(height: 12),
        Text(context.t.account.notSignedIn, style: theme.text.title),
        const SizedBox(height: 6),
        Text(
          context.t.account.notSignedInHint,
          textAlign: TextAlign.center,
          style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
        ),
        const SizedBox(height: 16),
        PureButton(
          label: context.t.settings.scanToLogin,
          icon: Icons.qr_code_scanner_rounded,
          onPressed: onSignIn,
        ),
      ],
    );
  }
}

/// The signed-in half: the account and the sign-out.
final class _SignedInCard extends ConsumerWidget {
  const new({required this.credential});

  final LiveCredential credential;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = PureTheme.of(context);
    final nickname = credential.nickname;
    return Column(
      children: [
        PureAvatar(name: nickname, src: _avatarOf(credential.avatar), size: 64),
        const SizedBox(height: 12),
        Text(nickname ?? context.t.account.title, style: theme.text.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Text(
          credential.userId == null
              ? context.t.account.platform
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
      title: context.t.account.signOutConfirm,
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
      await ref.read(accountProvider.notifier).signOut();
    }
  }

  ImageProvider? _avatarOf(String? avatar) =>
      avatar == null || avatar.isEmpty ? null : CachedNetworkImageProvider(avatar);
}
