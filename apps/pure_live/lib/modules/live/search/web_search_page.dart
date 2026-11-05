import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart' show SiteFacts;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/toolbox/toolbox.dart';
import 'package:pure_live/shared/shared.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;
import 'package:webview_all/webview_all.dart';

/// The search pages are the platforms' desktop sites: the reference opens
/// every in-app web search with `desktopSite: true`, because the mobile
/// pages hide most rooms behind an app hand-off. WebView2 on Windows already
/// reports this, but Android and iOS need it spelled out.
const String _desktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/140.0.0.0 Safari/537.36';

/// What to open in the in-app web view: the platform's search page, the
/// platform id and the words searched.
final class WebSearchRequest {
  /// Describes [uri] on [platform], searching [keyword]; [title] replaces the
  /// page's generic "web search" heading when it opens a live directory.
  const WebSearchRequest({required this.uri, required this.platform, this.keyword = '', this.title});

  /// The search page to open.
  final Uri uri;

  /// The platform id.
  final String platform;

  /// The words searched (the page's subtitle); may be empty.
  final String keyword;

  /// The heading this request shows, when it is not a search.
  final String? title;
}

/// The platform's own search page inside the app, rendered by
/// `webview_all`.
///
/// A target the package has no implementation for registers no platform, and
/// on such a host the page says so and offers the system browser instead of
/// presenting an empty frame.
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

  /// The page the WebView is on now, for the "open the room it shows" bar
  /// and the external-browser fallback.
  String? _currentUrl;

  /// The room the current page names, resolved through the platform
  /// resolvers once the page settles; null when the page is not a room.
  ({String platform, String roomId, Uri url})? _found;

  /// Rooms whose bar the viewer closed; the same room is not offered again,
  /// as the reference's dismiss remembers.
  final Set<String> _dismissedRooms = <String>{};

  /// Rises with every page; a resolution that arrives after a newer page
  /// must not put its room over that page.
  int _detect = 0;

  bool get _supported => WebViewPlatform.instance != null;

  @override
  void initState() {
    super.initState();
    final request = widget.request;
    if (request == null) return;
    // No in-app WebView on this host (Linux, or a Windows without WebView2):
    // the reference sends the search to the system browser at once instead
    // of showing an empty frame.
    if (!_supported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openExternal());
      });
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
              _detect++;
              setState(() {
                _loading = true;
                _error = null;
                _found = null;
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
              unawaited(_detectRoom(url));
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

  Future<void> _openExternal([Uri? target]) async {
    final current = _currentUrl;
    final uri = target ?? (current == null ? null : Uri.tryParse(current)) ?? widget.request?.uri;
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
    final found = _found;
    final foundSite = found == null ? null : ref.read(sitesProvider).getById(found.platform);
    final foundName = foundSite == null ? (found?.platform ?? '') : localizedSiteName(foundSite);
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
                          request?.title ?? t.search.webSearchTitle,
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
            if (found != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
                child: DsAlert(
                  title: Text(t.search.linkDetected),
                  description: Text('$foundName · ${found.roomId}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  action: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: DsSpace.s4,
                    children: [
                      DsButton(
                        variant: DsButtonVariant.secondary,
                        size: DsSize.sm,
                        onPressed: () => unawaited(_openRecognizedRoom(found)),
                        child: Text(t.search.linkOpen),
                      ),
                      DsButton.icon(
                        variant: DsButtonVariant.ghost,
                        size: DsSize.sm,
                        semanticLabel: t.common.close,
                        onPressed: _dismissRoomLink,
                        icon: const DsIcon(DsIcons.x, size: 16),
                      ),
                    ],
                  ),
                ),
              ),
            if (_loading) DsProgressBar(value: _progress / 100, semanticLabel: t.search.webSearchTitle),
            Expanded(
              child: switch (request) {
                null => Center(
                  child: DsEmptyState(icon: const DsIcon(DsIcons.globe), title: Text(t.search.webSearchUnavailable)),
                ),
                _ when !_supported => _unsupported(context, t),
                _ => Stack(
                  fit: StackFit.expand,
                  children: [
                    WebViewWidget(controller: _controller!),
                    if (_error != null) _failure(context, t),
                  ],
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Resolves the settled page through the platform resolvers and offers its
  /// room when one parses; a non-room page (a result list, an article) gets
  /// no bar. The reference parses locally; our resolvers answer room URLs
  /// without a request and only follow a short link when one is present.
  Future<void> _detectRoom(String url) async {
    final initial = widget.request?.uri.toString();
    if (url == initial || !url.startsWith('http')) return;
    final generation = ++_detect;
    await ref.read(linkToolProvider.notifier).resolve(url);
    if (!mounted || generation != _detect || _currentUrl != url) return;
    final room = ref.read(linkToolProvider).resolved;
    if (room == null || _dismissedRooms.contains('${room.platform}/${room.roomId}')) return;
    // A host with no native TLS channel cannot open this platform's room
    // natively; the web page itself is where the viewer watches it.
    if (SiteFacts.requiresNativeTls.contains(room.platform) &&
        !ref.read(nativeTlsPlatformsProvider).contains(room.platform)) {
      return;
    }
    setState(() => _found = room);
  }

  void _dismissRoomLink() {
    final room = _found;
    if (room == null) return;
    setState(() {
      _dismissedRooms.add('${room.platform}/${room.roomId}');
      _found = null;
    });
  }

  Future<void> _openRecognizedRoom(({String platform, String roomId, Uri url}) room) async {
    if (!mounted) return;
    await openRoom(context, platform: room.platform, roomId: room.roomId);
  }

  Widget _unsupported(BuildContext context, Translations t) {
    return Center(
      child: DsEmptyState(
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
      ),
    );
  }

  Widget _failure(BuildContext context, Translations t) {
    final error = _error;
    return Center(
      child: DsEmptyState(
        icon: const DsIcon(DsIcons.cloudOff),
        title: Text(t.search.webSearchFailed),
        description: error == null ? null : Text(error, textAlign: TextAlign.center),
        actions: [
          DsButton(
            onPressed: () => unawaited(_reload()),
            leading: const DsIcon(DsIcons.refreshCw),
            child: Text(t.common.retry),
          ),
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: () => unawaited(_openExternal()),
            leading: const DsIcon(DsIcons.externalLink),
            child: Text(t.search.webSearchOpenExternal),
          ),
        ],
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
    final theme = DsTheme.of(context);
    return ChromeIconButton(
      icon: icon,
      semanticLabel: label,
      tooltip: label,
      onPressed: onPressed,
      size: theme.sizes.sm,
      iconSize: theme.sizes.iconSm,
    );
  }
}
