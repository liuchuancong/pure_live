import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveLinkResolver;

import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/in_app_web.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:url_launcher/url_launcher.dart';

/// A room the web page landed on: its platform and room id.
typedef WebSearchRoomLink = ({String platform, String roomId});

/// A web search to open (3.x `WebSearchLaunchRequest`).
final class WebSearchRequest {
  /// Creates the request.
  const new({required this.uri, required this.platform, this.keyword = ''});

  /// The search address.
  final Uri uri;

  /// The platform id.
  final String platform;

  /// The words searched (the title's second line); may be empty.
  final String keyword;

  /// Builds the request from a route's query parameters (`url`, `platform`,
  /// `keyword`), or null when they are not a plain http(s) address without
  /// user information and a platform (3.x `parseWebSearchLaunchRequest`).
  static WebSearchRequest? fromQuery(Map<String, String?> query) {
    final rawUrl = query['url'];
    final rawPlatform = query['platform'];
    if (rawUrl is! String || rawPlatform is! String) {
      return null;
    }
    final uri = Uri.tryParse(rawUrl.trim());
    final platform = rawPlatform.trim().toLowerCase();
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.trim().isEmpty ||
        uri.userInfo.isNotEmpty ||
        platform.isEmpty) {
      return null;
    }
    final keyword = query['keyword'];
    return WebSearchRequest(uri: uri, platform: platform, keyword: keyword is String ? keyword.trim() : '');
  }
}

/// The web search page (docs/A09.8): the platform's search page in the app
/// ([InAppWeb], webview_flutter). When a page settles on a room, a bar at
/// the bottom names the platform and the room and opens it (c4); the room
/// opens OVER this page, so Back returns here (c5).
///
/// The app bar: Back goes back in the page first and closes on the first
/// page; the title says the platform and the words (c2); "use the system
/// browser" (c3) and ✕, which closes at once.
///
/// Without an in-app WebView — Windows and Linux, where webview_flutter has
/// no plugin — the page sends the search to the system browser and says how
/// to come back: copy the room's link and paste it into the search field
/// (c7, the reference's own Linux branch).
final class WebSearchView extends ConsumerStatefulWidget {
  /// The page for a parsed [request] (null answers the invalid state).
  const new({required this.request, this.openExternal, this.inApp, this.openRoom, super.key});

  /// The search to open.
  final WebSearchRequest? request;

  /// Opens a web address outside the app; null uses `url_launcher` directly.
  final Future<bool> Function(Uri uri)? openExternal;

  /// Whether the page opens in the app; null reads [InAppWeb.available].
  final bool? inApp;

  /// Opens a room; null pushes a [RoomRoute].
  final Future<void> Function(String platform, String roomId)? openRoom;

  @override
  ConsumerState<WebSearchView> createState() => _WebSearchViewState();
}

final class _WebSearchViewState extends ConsumerState<WebSearchView> {
  final GlobalKey<InAppWebPageState> _page = GlobalKey<InAppWebPageState>();
  Uri? _current;
  bool _opening = false;
  WebSearchRoomLink? _found;
  final Set<WebSearchRoomLink> _dismissed = {};
  int _generation = 0;

  bool get _inApp => widget.inApp ?? InAppWeb.available;

  @override
  void initState() {
    super.initState();
    final request = widget.request;
    _current = request?.uri;
    // No WebView here: the search goes to the system browser at once (3.x
    // opened it straight from the search page on Linux).
    if (request != null && !_inApp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_openExternal(request.uri));
        }
      });
    }
  }

  /// A page was shown: the bar names its room, unless the user closed the
  /// bar for that room (c1: a dismissed room is not offered again).
  ///
  /// The reference intercepted every navigation with flutter_inappwebview;
  /// webview_flutter answers this only with the address a load STOPPED at,
  /// and the room check is the toolbox's own resolver walk.
  Future<void> _pageShown(Uri uri) async {
    _current = uri;
    final generation = ++_generation;
    final link = await _parseRoomLink(uri);
    if (!mounted || generation != _generation) {
      return;
    }
    setState(() => _found = link == null || _dismissed.contains(link) ? null : link);
  }

  Future<WebSearchRoomLink?> _parseRoomLink(Uri uri) async {
    final resolvers = ref
        .read(sitesProvider)
        .registry
        .all
        .where((site) => site.capability<LiveLinkResolver>() != null)
        .toList();
    // Sequential on purpose — the same rule as the toolbox: a resolver
    // follows short links, and a fan-out would fire the same follow at
    // every host.
    for (final site in resolvers) {
      final resolver = site.capability<LiveLinkResolver>()!;
      final Uri? canonical;
      try {
        canonical = (await resolver.resolve(uri)).fold((failure) => null, (canonical) => canonical);
      } on Object {
        continue;
      }
      if (canonical == null) {
        continue;
      }
      final roomId = canonical.pathSegments.where((segment) => segment.isNotEmpty).lastOrNull;
      if (roomId == null || roomId.isEmpty) {
        continue;
      }
      return (platform: site.manifest.id, roomId: roomId);
    }
    return null;
  }

  Future<void> _enter(WebSearchRoomLink link) async {
    final open = widget.openRoom;
    // Over this page: Back from the room comes back here (c5).
    await (open != null
        ? open(link.platform, link.roomId)
        : RoomRoute(siteId: link.platform, roomId: link.roomId).push<void>(context));
  }

  void _dismiss(WebSearchRoomLink link) => setState(() {
    _dismissed.add(link);
    _found = null;
  });

  Future<void> _openExternal(Uri uri) async {
    if (_opening) {
      return;
    }
    final t = context.t;
    setState(() => _opening = true);
    final open = widget.openExternal ?? (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
    var opened = false;
    try {
      opened = await open(uri);
    } on Object {
      opened = false;
    }
    if (!mounted) {
      return;
    }
    setState(() => _opening = false);
    if (!opened) {
      PureToast.show(context, t.search.externalBrowserNotOpened);
    }
  }

  String get _subtitle {
    final request = widget.request;
    if (request == null) {
      return '';
    }
    final name = _platformName(request.platform);
    return request.keyword.isEmpty ? name : '$name · ${request.keyword}';
  }

  String _platformName(String platform) {
    final site = ref.read(sitesProvider).registry.getById(platform);
    if (site == null) {
      return platform;
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    return site.manifest.localizedName(locale, 'zh-CN');
  }

  /// Back leaves the WEB page first, then this route (c1).
  Future<void> _handleBack() async {
    if (await _page.currentState?.navigateBack() ?? false) {
      return;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final request = widget.request;
    final inApp = request != null && _inApp;
    final title = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.search.webSearch, style: PureTheme.of(context).text.title),
        if (request != null)
          Text(
            _subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PureTheme.of(context).text.bodySmall.copyWith(color: PureTheme.of(context).colors.textSecondary),
          ),
      ],
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_handleBack());
        }
      },
      child: PureScaffold(
        appBar: PureAppBar(
          title: request == null ? t.search.webSearch : '${t.search.webSearch} · $_subtitle',
          // The reference's PageTitle pair: what the page is, and of whom.
          titleWidget: request == null ? null : title,
          centerTitle: false,
          actions: [
            if (inApp)
              PureIconButton(
                key: const ValueKey('web-search-external'),
                tooltip: t.search.openInSystemBrowser,
                icon: Icons.open_in_new,
                onPressed: () => unawaited(_openExternal(_current ?? request.uri)),
              ),
            PureIconButton(
              key: const ValueKey('web-search-close'),
              tooltip: t.common.close,
              icon: Icons.close,
              // Pop past the page's own back steps (3.x's ✕).
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: request == null
            ? _StateBody(
                key: const ValueKey('web-search-invalid'),
                icon: Icons.wifi_off,
                error: true,
                title: t.search.webSearchUnavailableTitle,
                text: t.search.webSearchInvalidAddress,
                actions: [
                  PureButton(
                    label: t.common.close,
                    variant: ButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              )
            : inApp
            ? LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Positioned.fill(
                      child: InAppWebPage(
                        key: _page,
                        initial: request.uri,
                        progressHeight: 4,
                        onPage: (uri) => unawaited(_pageShown(uri)),
                        failureBuilder: (context, retry) => _StateBody(
                          key: const ValueKey('web-search-failed'),
                          icon: Icons.wifi_off,
                          error: true,
                          title: t.search.webSearchUnavailableTitle,
                          text: t.search.webSearchLoadFailed,
                          actions: [
                            PureButton(
                              key: const ValueKey('web-search-retry'),
                              label: t.common.retry,
                              icon: Icons.refresh,
                              onPressed: retry,
                            ),
                            PureButton(
                              key: const ValueKey('web-search-failed-external'),
                              label: t.search.openInSystemBrowser,
                              variant: ButtonVariant.ghost,
                              onPressed: () => unawaited(_openExternal(_current ?? request.uri)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_found case final link?)
                      WebSearchRoomBar.place(
                        width: constraints.maxWidth,
                        bar: WebSearchRoomBar(
                          platform: _platformName(link.platform),
                          roomId: link.roomId,
                          onEnter: () => unawaited(_enter(link)),
                          onDismiss: () => _dismiss(link),
                        ),
                      ),
                  ],
                ),
              )
            : _StateBody(
                key: const ValueKey('web-search-system-browser'),
                icon: Icons.language,
                text: t.search.webExternalTip,
                detail: request.uri.host,
                actions: [
                  PureButton(
                    key: const ValueKey('web-search-open-external'),
                    label: t.search.openInSystemBrowser,
                    icon: Icons.open_in_new,
                    loading: _opening,
                    onPressed: _opening ? null : () => unawaited(_openExternal(request.uri)),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The bar of a room the web page shows (U.5b c4; 3.x asked in a dialog
/// every time): "这是一个直播间", the platform and the room id, "进入" and ✕
/// (this room is not offered again).
final class WebSearchRoomBar extends StatelessWidget {
  /// Creates the bar.
  const new({required this.platform, required this.roomId, required this.onEnter, required this.onDismiss, super.key});

  /// The room's platform, named.
  final String platform;

  /// The room id.
  final String roomId;

  /// Opens the room.
  final VoidCallback onEnter;

  /// Hides the bar for this room.
  final VoidCallback onDismiss;

  /// The width from which the bar keeps its own column instead of spanning the
  /// page: the shell's medium class, the same bound the navigation changes at.
  static const double _spanningMaxWidth = AdaptiveBreakpoints.medium;

  /// The width at which the bar gets the wide-window insets and a wider column.
  /// Deliberately between the `expanded` (1024) and `large` (1440) class bounds:
  /// the bar is meant to sit beside a two-column page, which is what the desktop
  /// shell looks like from here, and neither class bound is that width.
  static const double _wideMinWidth = 1200;

  /// Places [bar] over a page [width] wide: the full width on phones held
  /// upright, on the right 420 wide on sideways phones and 440 on wide
  /// windows.
  static Widget place({required double width, required Widget bar}) {
    if (width < _spanningMaxWidth) {
      return Positioned(left: 12, right: 12, bottom: 16, child: SafeArea(top: false, child: bar));
    }
    final wide = width >= _wideMinWidth;
    return Positioned(
      right: wide ? 24 : 12,
      bottom: wide ? 24 : 16,
      width: wide ? 440 : 420,
      child: SafeArea(top: false, left: false, child: bar),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    return PureCard(
      key: const ValueKey('web-search-room-bar'),
      child: Row(
        children: [
          Icon(Icons.live_tv, size: 24, color: theme.colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.search.webSearchRoomBanner, style: theme.text.body.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  '$platform · ${t.search.roomIdLabel(roomId: roomId)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PureButton(key: const ValueKey('web-search-room-enter'), label: t.search.roomEnter, onPressed: onEnter),
          PureIconButton(
            key: const ValueKey('web-search-room-dismiss'),
            tooltip: t.search.webSearchRoomDismiss,
            icon: Icons.close,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// A centred state of the page: a 48-point icon (error colour for
/// failures), a title, a sentence, a quiet detail and the buttons below.
final class _StateBody extends StatelessWidget {
  const new({
    required this.icon,
    required this.text,
    required this.actions,
    this.title,
    this.detail,
    this.error = false,
    super.key,
  });

  final IconData icon;
  final String? title;
  final String text;
  final String? detail;
  final bool error;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity)),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: error ? theme.colors.error : theme.colors.primary),
                  if (title case final title?) ...[
                    const SizedBox(height: 20),
                    Text(title, textAlign: TextAlign.center, style: theme.text.title),
                    const SizedBox(height: 8),
                    Text(text, textAlign: TextAlign.center, style: theme.text.bodySmall),
                  ] else ...[
                    const SizedBox(height: 16),
                    Text(text, textAlign: TextAlign.center, style: theme.text.body),
                  ],
                  if (detail case final detail?) ...[
                    const SizedBox(height: 8),
                    Text(detail, style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary)),
                  ],
                  const SizedBox(height: 20),
                  for (final (index, action) in actions.indexed) ...[if (index > 0) const SizedBox(height: 8), action],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
