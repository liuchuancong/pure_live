import 'dart:async' show unawaited;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:live_sites/live_sites.dart' show LiveSite;
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:pure_live/features/login/login_providers.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The sign-in page: a platform picker over the flows this build ships —
/// the bilibili QR code, the douyu cookie paste and the huya cookie paste.
///
/// The bilibili flow lives in [loginFlowProvider], the two cookie pastes in
/// [cookiePasteProvider]; the page only renders their phases. Without a
/// site's auth capability its mode degrades to an honest "unsupported"
/// state.
final class LoginPage extends ConsumerStatefulWidget {
  /// The login page.
  const new({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

final class _LoginPageState extends ConsumerState<LoginPage> {
  int _mode = 0;

  /// The tabs, QR first then the cookie pastes, in the registry's order.
  ///
  /// The page shows whichever sign-in flows this build's sites actually ship:
  /// a platform that gains an auth adapter grows a tab here without an edit.
  List<LiveSite> _tabs() {
    final sites = ref.watch(authSitesProvider);
    final qr = [
      for (final site in sites)
        if (siteUsesQrLogin(site.manifest.id)) site,
    ];
    final paste = [
      for (final site in sites)
        if (!siteUsesQrLogin(site.manifest.id)) site,
    ];
    return [...qr, ...paste];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final tabs = _tabs();
    if (tabs.isEmpty) {
      return PureScaffold(
        appBar: PureAppBar(title: t.login.title),
        body: Center(child: Text(t.account.noAuthSites)),
      );
    }
    final index = _mode.clamp(0, tabs.length - 1);
    final selected = tabs[index];
    final qrSelected = siteUsesQrLogin(selected.manifest.id);
    return PureScaffold(
      appBar: PureAppBar(title: t.login.title),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: PureSegmented(
              labels: [for (final site in tabs) _siteName(site, context)],
              index: index,
              expand: true,
              onChanged: (value) => setState(() => _mode = value),
            ),
          ),
          Expanded(
            child: Center(
              child: qrSelected
                  // One QR tab per build: the flow is the same session loop, the
                  // site is whichever of the auth sites declares it.
                  ? const _QrBody()
                  : _PasteCard(key: ValueKey(selected.manifest.id), siteId: selected.manifest.id),
            ),
          ),
        ],
      ),
    );
  }

  static String _siteName(LiveSite site, BuildContext context) =>
      site.manifest.localizedName(Localizations.localeOf(context).toLanguageTag(), 'zh-CN');
}

/// The bilibili half of the page: the QR flow, or the honest "unsupported"
/// state when the build ships no bilibili sign-in capability.
final class _QrBody extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authCapabilityProvider(qrLoginSite)) == null) {
      return PureEmpty(
        title: context.t.login.unsupported,
        message: context.t.errors.unsupported,
        icon: Icons.person_off_outlined,
      );
    }
    return const _FlowCard();
  }
}

/// The cookie half of the page: the multiline paste field, the verify button
/// (busy while the site judges the paste) and what the site answered — the
/// granted account, or its refusal verbatim.
final class _PasteCard extends ConsumerStatefulWidget {
  const new({required this.siteId, super.key});

  /// The site the paste signs in (`douyu`, `huya`).
  final String siteId;

  @override
  ConsumerState<_PasteCard> createState() => _PasteCardState();
}

final class _PasteCardState extends ConsumerState<_PasteCard> {
  final TextEditingController _cookie = TextEditingController();

  @override
  void dispose() {
    _cookie.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authCapabilityProvider(widget.siteId));
    if (auth == null) {
      return PureEmpty(
        title: context.t.login.unsupportedSite(site: widget.siteId),
        message: context.t.errors.unsupported,
        icon: Icons.person_off_outlined,
      );
    }
    final paste = ref.watch(cookiePasteProvider(widget.siteId));
    final theme = PureTheme.of(context);
    final t = context.t;
    return PureCard(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 320,
        child: switch (paste.phase) {
          CookiePastePhase.success => _success(context, paste),
          _ => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.siteId == 'douyu' ? t.login.douyuCookieHint : t.login.huyaCookieHint,
                style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
              ),
              const SizedBox(height: 12),
              PureTextField(
                controller: _cookie,
                placeholder: t.login.cookiePlaceholder,
                maxLines: 5,
                keyboardType: TextInputType.text,
                enabled: paste.phase != CookiePastePhase.verifying,
                onChanged: (_) => setState(() {}),
              ),
              if (paste.phase == CookiePastePhase.failure) ...[
                const SizedBox(height: 8),
                Text(paste.message ?? '', style: theme.text.caption.copyWith(color: theme.colors.error)),
              ],
              const SizedBox(height: 16),
              PureButton(
                label: t.login.verify,
                icon: Icons.check_rounded,
                expand: true,
                loading: paste.phase == CookiePastePhase.verifying,
                onPressed: _cookie.text.trim().isEmpty ? null : () => _verify(paste),
              ),
            ],
          ),
        },
      ),
    );
  }

  Widget _success(BuildContext context, CookiePasteState paste) {
    final theme = PureTheme.of(context);
    final account = paste.account;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PureAvatar(name: account?.nickname, src: _avatarOf(account?.avatar), size: 64),
        const SizedBox(height: 12),
        Text(context.t.login.success, textAlign: TextAlign.center, style: theme.text.title),
        const SizedBox(height: 6),
        Text(
          context.t.login.welcome(name: account?.nickname ?? ''),
          textAlign: TextAlign.center,
          style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
        ),
        const SizedBox(height: 16),
        PureButton(
          label: context.t.login.done,
          expand: true,
          onPressed: () {
            context.pop<void>();
          },
        ),
      ],
    );
  }

  void _verify(CookiePasteState paste) {
    if (paste.phase == CookiePastePhase.verifying) {
      return;
    }
    unawaited(ref.read(cookiePasteProvider(widget.siteId).notifier).verify(_cookie.text));
  }

  ImageProvider? _avatarOf(String? avatar) =>
      avatar == null || avatar.isEmpty ? null : CachedNetworkImageProvider(avatar);
}

/// The card that renders the QR flow's current phase over one watched state.
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
              PureAvatar(name: flow.account?.nickname, src: _avatarOf(flow.account?.avatar), size: 64),
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
                onPressed: () {
                  context.pop<void>();
                },
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

  Widget _status(BuildContext context, String text) =>
      Text(text, textAlign: TextAlign.center, style: PureTheme.of(context).text.title);

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
      child: dimmed ? ExcludeSemantics(child: Opacity(opacity: 0.35, child: ground)) : ground,
    );
  }

  ImageProvider? _avatarOf(String? avatar) =>
      avatar == null || avatar.isEmpty ? null : CachedNetworkImageProvider(avatar);
}
