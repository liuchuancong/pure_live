import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:pure_live/features/login/login_providers.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The bilibili QR login (the reference's login page): the code the bilibili
/// app scans, the poll behind it and the account it lands on.
///
/// The flow itself lives in [loginFlowProvider] — this page only renders its
/// phases. The QR renders as soon as the platform issues it (the first poll
/// waits for that issue), `pending` polls on, `expired` offers a fresh code
/// and `success` greets the account the exchange granted. Without a bilibili
/// auth capability the page degrades to an honest "unsupported" state.
final class LoginPage extends ConsumerWidget {
  /// The login page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return PureScaffold(
      appBar: PureAppBar(title: t.login.title),
      body: ref.watch(bilibiliAuthProvider) == null
          ? Center(
              child: PureEmpty(
                title: t.login.unsupported,
                message: t.errors.unsupported,
                icon: Icons.person_off_outlined,
              ),
            )
          : const Center(child: _FlowCard()),
    );
  }
}

/// The card that renders the flow's current phase over one watched state.
final class _FlowCard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(loginFlowProvider);
    final theme = PureTheme.of(context);
    return PureCard(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 260,
        child: switch (flow.phase) {
          LoginPhase.generating => _phaseColumn(
            context,
            children: [
              const PureSpinner(size: 40),
              const SizedBox(height: 16),
              _status(context, context.t.login.generating),
            ],
          ),
          LoginPhase.scanning => _phaseColumn(
            context,
            children: [
              _qr(context, flow.qrContent),
              const SizedBox(height: 16),
              _status(context, context.t.login.waitingScan),
              const SizedBox(height: 6),
              Text(
                context.t.login.scanHint,
                textAlign: TextAlign.center,
                style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
              ),
            ],
          ),
          LoginPhase.success => _phaseColumn(
            context,
            children: [
              PureAvatar(
                name: flow.account?.nickname,
                src: _avatarOf(flow.account?.avatar),
                size: 64,
              ),
              const SizedBox(height: 12),
              _status(context, context.t.login.success),
              const SizedBox(height: 6),
              Text(
                context.t.login.welcome(name: flow.account?.nickname ?? ''),
                textAlign: TextAlign.center,
                style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
              ),
              const SizedBox(height: 16),
              PureButton(
                label: context.t.login.done,
                expand: true,
                onPressed: () => context.pop<void>(),
              ),
            ],
          ),
          LoginPhase.expired => _phaseColumn(
            context,
            children: [
              _qr(context, flow.qrContent, dimmed: true),
              const SizedBox(height: 16),
              _status(context, context.t.login.expired),
              const SizedBox(height: 16),
              PureButton(
                label: context.t.login.refreshQr,
                icon: Icons.refresh_rounded,
                expand: true,
                onPressed: () => ref.read(loginFlowProvider.notifier).start(),
              ),
            ],
          ),
          LoginPhase.failure => _phaseColumn(
            context,
            children: [
              Icon(Icons.error_outline, size: 40, color: theme.colors.error),
              const SizedBox(height: 16),
              _status(context, context.t.login.failed),
              const SizedBox(height: 16),
              PureButton(
                label: context.t.common.retry,
                icon: Icons.refresh_rounded,
                expand: true,
                onPressed: () => ref.read(loginFlowProvider.notifier).start(),
              ),
            ],
          ),
        },
      ),
    );
  }

  Widget _phaseColumn(BuildContext context, {required List<Widget> children}) =>
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children);

  Widget _status(BuildContext context, String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: PureTheme.of(context).text.title,
  );

  /// The QR code on its white ground (the code has to scan against any
  /// theme), dimmed once the platform has expired it.
  Widget _qr(BuildContext context, String content, {bool dimmed = false}) {
    final ground = SizedBox(
      width: 200,
      height: 200,
      child: content.isEmpty ? const Center(child: PureSpinner(size: 28)) : PrettyQrView.data(data: content),
    );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(8))),
      child: dimmed
          ? ExcludeSemantics(child: Opacity(opacity: 0.35, child: ground))
          : ground,
    );
  }

  ImageProvider? _avatarOf(String? avatar) =>
      avatar == null || avatar.isEmpty ? null : CachedNetworkImageProvider(avatar);
}
