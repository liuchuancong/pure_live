import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';

/// API search a site may support, for one or more content types.
abstract interface class LiveSearchProvider implements LiveSiteCapability {
  /// The targets this site actually searches; a request for another must
  /// fail with a [LiveSiteUnsupported] left, never an empty page.
  Set<LiveSearchTarget> get supportedTargets;

  /// Runs [request] and returns a page of typed results.
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request);
}

/// A search whose transport answers cancellation (see
/// `live_site_cancellation.dart` for the contract the `cancel` token
/// follows).
///
/// Implementing this refines [LiveSearchProvider] with one strengthened
/// method: the optional named parameter satisfies the base member as it is,
/// so a site declares the stronger signature and `capability<T>()` keeps
/// answering for the base type. A site without it is still searchable — the
/// cancellation entry points fall back to the base call and honour the token
/// by checking it before and after instead of interrupting the transport.
abstract interface class LiveCancellableSearch implements LiveSearchProvider {
  /// Runs [request], aborting the transport once [cancel] is set.
  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request, {CancelToken? cancel});
}
