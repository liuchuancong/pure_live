import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;
import 'package:webview_all/webview_all.dart';

/// The station's 素材库 and 直播, opened as the site ships them, rendered
/// **inside** the module rather than as a pushed route.
///
/// Neither is an anonymously readable listing — the material library is a
/// sign-in app and 直播 is the live portal — so the module does not fake a
/// native grid over them; it opens the station's own page in the in-app web
/// view, the way the site's header link does. Unlike the live search page it
/// has no route to pop, so it carries no back/close button: the shell's own
/// navigation is the way out.
final class HuyaMaterialPage extends StatelessWidget {
  /// The material library.
  const HuyaMaterialPage({super.key});

  @override
  Widget build(BuildContext context) =>
      _HuyaWebView(uri: Uri.https('www.huya.com', '/material'), title: context.t.huya.material);
}

/// The station's 直播 portal: the live site behind the header's 直播 link.
final class HuyaLivePage extends StatelessWidget {
  /// The live portal.
  const HuyaLivePage({super.key});

  @override
  Widget build(BuildContext context) =>
      _HuyaWebView(uri: Uri.https('www.huya.com', '/'), title: context.t.huya.liveTab);
}

/// The desktop user agent: the station serves its full page to a desktop
/// browser, and WebView2 on Windows already reports one but the mobile hosts
/// do not.
const String _desktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/140.0.0.0 Safari/537.36';

/// One in-place web page: the picture, a reload and the way to the system
/// browser — no route pop, because the page lives in the shell.
final class _HuyaWebView extends StatefulWidget {
  const _HuyaWebView({required this.uri, required this.title});

  final Uri uri;
  final String title;

  @override
  State<_HuyaWebView> createState() => _HuyaWebViewState();
}

final class _HuyaWebViewState extends State<_HuyaWebView> {
  WebViewController? _controller;
  bool _loading = true;
  int _progress = 0;
  String? _error;

  bool get _supported => WebViewPlatform.instance != null;

  @override
  void initState() {
    super.initState();
    if (!_supported) {
      _loading = false;
      return;
    }
    final controller = WebViewController();
    unawaited(controller.setUserAgent(_desktopUserAgent));
    unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    unawaited(
      controller.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
                _error = null;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() {
                _loading = false;
                _progress = 100;
              });
            }
          },
          onWebResourceError: (error) {
            if (!mounted || !(error.isForMainFrame ?? true)) return;
            setState(() {
              _loading = false;
              _error = error.description;
            });
          },
        ),
      ),
    );
    unawaited(controller.loadRequest(widget.uri));
    _controller = controller;
  }

  Future<void> _reload() async {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _error = null);
    await controller.reload();
  }

  Future<void> _openExternal() async {
    await launchUrl(widget.uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return ColoredBox(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s8, DsSpace.s16, DsSpace.s8),
            child: Row(
              spacing: DsSpace.s8,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.title.copyWith(color: colors.text),
                  ),
                ),
                if (_controller != null && !_loading)
                  DsButton.icon(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    semanticLabel: t.common.retry,
                    onPressed: () => unawaited(_reload()),
                    icon: const DsIcon(DsIcons.refreshCw, size: 16),
                  ),
                DsButton.icon(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  semanticLabel: t.search.webSearchOpenExternal,
                  onPressed: () => unawaited(_openExternal()),
                  icon: const DsIcon(DsIcons.externalLink, size: 16),
                ),
              ],
            ),
          ),
          if (_loading) DsProgressBar(value: _progress / 100, semanticLabel: widget.title),
          Expanded(
            child: switch ((_supported, _controller)) {
              (false, _) => Center(
                child: DsEmptyState(
                  icon: const DsIcon(DsIcons.globe),
                  title: Text(t.search.webSearchUnavailable),
                  actions: [
                    DsButton(
                      variant: DsButtonVariant.secondary,
                      onPressed: () => unawaited(_openExternal()),
                      leading: const DsIcon(DsIcons.externalLink, size: 16),
                      child: Text(t.search.webSearchOpenExternal),
                    ),
                  ],
                ),
              ),
              (true, final controller?) => Stack(
                fit: StackFit.expand,
                children: [
                  WebViewWidget(controller: controller),
                  if (_error != null)
                    Center(
                      child: DsAlert(
                        status: DsStatus.danger,
                        title: Text(t.huya.errorTitle),
                        description: Text(_error!),
                        action: DsButton(
                          variant: DsButtonVariant.secondary,
                          onPressed: () => unawaited(_reload()),
                          child: Text(t.common.retry),
                        ),
                      ),
                    ),
                ],
              ),
              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }
}
