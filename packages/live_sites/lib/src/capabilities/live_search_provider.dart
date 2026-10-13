import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/live_page/live_page.dart';
import 'package:live_sites/src/models/live_search_result/live_search_request.dart';
import 'package:live_sites/src/models/live_search_result/live_search_result.dart';
import 'package:live_sites/src/models/live_search_result/live_search_target.dart';

/// API search a site may support, for one or more content types.
abstract interface class LiveSearchProvider implements LiveSiteCapability {
  /// The targets this site actually searches; a request for another must fail
  /// with a [LiveSiteUnsupported] left, never an empty page.
  Set<LiveSearchTarget> get supportedTargets;

  /// Runs [request] and returns a page of typed results.
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request);
}
