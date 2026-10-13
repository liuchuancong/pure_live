import 'package:live_sites/src/capabilities/live_site_capability.dart';

/// A description of a native web-search page to open.
///
/// The application opens and displays this in its own WebView; `live_sites`
/// only describes the page and never depends on a WebView widget. The [uri]
/// MUST use an allowed, validated scheme (HTTPS preferred) and host.
class LiveWebSearchDescriptor {
  /// Describes a web-search page at [uri], titled [title].
  const new({required this.uri, this.title});

  /// The search page to open.
  final Uri uri;

  /// A title to show for the page, when known.
  final String? title;
}

/// A site whose search is only practical by opening its own web-search page.
///
/// Pure data: it describes the page, it does not fetch or render it, so there
/// is no failure to represent and no `Either` is needed.
abstract interface class LiveWebSearchProvider implements LiveSiteCapability {
  /// Describes the web-search page for [query].
  LiveWebSearchDescriptor createSearch(String query);
}
