import 'package:live_sites/src/capabilities/live_site_capability.dart';

/// Search-as-you-type suggestions of a site's own web client
/// (ARCHITECTURE.md §4.1: an optional capability, null from
/// `LiveSite.capability<T>()` when the site does not support it).
abstract interface class LiveSuggestCapability implements LiveSiteCapability {
  /// The completions the site offers for [query], best first; empty when the
  /// site has none (an empty list is an answer, never "unsupported").
  ///
  /// Never throws for an empty [query] — that answers empty.
  Future<List<String>> suggestions(String query);
}
