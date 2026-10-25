import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/app/routing/app_router.dart' show RoomRoute;
import 'package:pure_live/features/toolbox/toolbox_controllers.dart' show linkToolProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/platforms/platform_display.dart' show localizedSiteName;
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;
import 'package:webview_flutter/webview_flutter.dart';

/// What to open in the in-app web view: the platform's search page, the
/// platform id and the words searched.
final class WebSearchRequest {
  /// Describes [uri] on [platform], searching [keyword].
  const WebSearchRequest({required this.uri, required this.platform, this.keyword = ''});

  /// The search page to open.
  final Uri uri;

  /// The platform id.
  final String platform;

  /// The words searched (the page's subtitle); may be empty.
  final String keyword;
}

/// The platform's own search page inside the app, rendered by
/// `webview_flutter`.
///
/// The package has no Windows or Linux implementation; on a host without a
/// WebView platform the page says so and offers the system browser instead
/// of presenting an empty frame.
final class WebSearchPage extends ConsumerStatefulWidget {
  /// Opens [request]; a null request (a deep link without its extra) is an
  /// honest empty page.
  const WebSearchPage({required this.request, super.key});

  /// The search page to show.
  final WebSearchRequest? request;

  @override
  ConsumerState<WebSearchPage> createState() => _WebSearchPageState();
}

final class _WebSearchPageState extends ConsumerState<WebSearchPage> {
  WebViewController? _controller;
  int _progress = 0;
  bool _loading = false;
  String? _error;

  /// The page the WebView is on now, for the "open the room it shows" bar.
  /// The initial search page is not a room, so only a later navigation
  /// offers the bar.
  String? _currentUrl;

  bool get _supported => WebViewPlatform.instance != null;

  @override
  void initState() {
    super.initState();
    final request = widget.request;
    if (request == null || !_supported) return;
    final controller = WebViewController();
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
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _loading = false;
                _progress = 100;
                _currentUrl = url;
              });
            }
          },
          onUrlChange: (change) {
            final url = change.url;
            if (mounted && url != null) setState(() => _currentUrl = url);
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
    unawaited(controller.loadRequest(request.uri));
    _controller = controller;
  }

  Future<void> _back() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return;
    }
    if (mounted) context.pop();
  }

  Future<void> _openExternal() async {
    final uri = widget.request?.uri;
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      showDsToast(context: context, title: context.t.search.webSearchExternalFailed, status: DsStatus.danger);
    }
  }

  Future<void> _reload() async {
    final controller = _controller;
    setState(() => _error = null);
    if (controller == null) {
      setState(() => _loading = false);
      return;
    }
    await controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final request = widget.request;
    final site = request == null ? null : ref.read(sitesProvider).getById(request.platform);
    final platformName = site == null ? (request?.platform ?? '') : localizedSiteName(site);
    final subtitle = request == null
        ? ''
        : [if (platformName.isNotEmpty) platformName, if (request.keyword.isNotEmpty) request.keyword].join(' · ');
    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s8, DsSpace.s16, DsSpace.s8),
              child: Row(
                spacing: DsSpace.s8,
                children: [
                  _WebIcon(
                    icon: DsIcons.chevronLeft,
                    label: t.common.back,
                    onPressed: request == null ? null : () => unawaited(_back()),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          t.search.webSearchTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.title.copyWith(color: colors.text),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.caption.copyWith(color: colors.textMuted),
                          ),
                      ],
                    ),
                  ),
                  if (_controller != null)
                    _WebIcon(icon: DsIcons.refreshCw, label: t.common.retry, onPressed: () => unawaited(_reload())),
                  if (request != null)
                    _WebIcon(
                      icon: DsIcons.externalLink,
                      label: t.search.webSearchOpenExternal,
                      onPressed: () => unawaited(_openExternal()),
                    ),
                  _WebIcon(icon: DsIcons.x, label: t.common.close, onPressed: () => context.pop()),
                ],
              ),
            ),
            if (_roomLink != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
                child: DsAlert(
                  title: Text(t.search.linkDetected),
                  description: Text(_roomLink!, maxLines: 1, overflow: TextOverflow.ellipsis),
                  action: DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    loading: ref.watch(linkToolProvider).resolving,
                    onPressed: ref.watch(linkToolProvider).resolving
                        ? null
                        : () => unawaited(_openRecognizedRoom(_roomLink!)),
                    child: Text(t.search.linkOpen),
                  ),
                ),
              ),
            if (_loading) DsProgressBar(value: _progress / 100, semanticLabel: t.search.webSearchTitle),
            Expanded(
              child: switch (request) {
                null => DsEmptyState(icon: const DsIcon(DsIcons.globe), title: Text(t.search.webSearchUnavailable)),
                _ when !_supported => _unsupported(context, t),
                _ => Stack(
                  fit: StackFit.expand,
                  children: [
                    WebViewWidget(controller: _controller!),
                    if (_error != null) _failure(context, t, colors, theme),
                  ],
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  /// A navigated page that is not the search page itself; the resolver
  /// decides whether it really names a room before the page opens one.
  String? get _roomLink {
    final current = _currentUrl;
    final initial = widget.request?.uri.toString();
    if (current == null || current == initial) return null;
    if (!current.startsWith('http://') && !current.startsWith('https://')) return null;
    return current;
  }

  Future<void> _openRecognizedRoom(String url) async {
    await ref.read(linkToolProvider.notifier).resolve(url);
    if (!mounted) return;
    final link = ref.read(linkToolProvider);
    if (link.resolved case final room?) {
      await context.push(RoomRoute(platform: room.platform, roomId: room.roomId).location);
      return;
    }
    showDsToast(context: context, title: context.t.search.linkFailed);
  }

  Widget _unsupported(BuildContext context, Translations t) {
    return DsEmptyState(
      icon: const DsIcon(DsIcons.globe),
      title: Text(t.search.webSearchUnsupportedTitle),
      description: Text(t.search.webSearchUnsupportedDescription),
      actions: [
        DsButton(
          onPressed: () => unawaited(_openExternal()),
          leading: const DsIcon(DsIcons.externalLink),
          child: Text(t.search.webSearchOpenExternal),
        ),
      ],
    );
  }

  Widget _failure(BuildContext context, Translations t, DsColors colors, DsThemeData theme) {
    return ColoredBox(
      color: colors.overlay,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s12,
          children: [
            Text(t.search.webSearchFailed, style: theme.typography.title.copyWith(color: colors.text)),
            if (_error != null)
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            DsButton(onPressed: () => unawaited(_reload()), child: Text(t.common.retry)),
          ],
        ),
      ),
    );
  }
}

/// A compact icon button for the page's own bar.
final class _WebIcon extends StatelessWidget {
  const _WebIcon({required this.icon, required this.label, required this.onPressed});

  final DsIconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DsTooltip(
      message: label,
      child: DsPressable(
        semanticLabel: label,
        onPressed: onPressed,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return Container(
            width: theme.sizes.sm,
            height: theme.sizes.sm,
            decoration: DsBoxDecoration(
              color: hovered && onPressed != null ? colors.hover : null,
              borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
            ),
            child: Center(
              child: DsIcon(
                icon,
                size: theme.sizes.iconSm,
                color: onPressed == null ? colors.textSubtle : colors.textMuted,
              ),
            ),
          );
        },
      ),
    );
  }
}
